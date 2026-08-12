---
title: "MC 服务器大迁移：从 NAT 机到 VM 的 72 小时"
date: 2026-08-12T00:00:00+08:00
draft: false
tags: ["运维", "MC", "服务器迁移", "MCSM", "FRP", "Docker"]
categories: ["个人项目"]
---

## 背景

我的 MC 服务器（1.20.1 Fabric，机械动力全家桶）一直跑在山东枣庄的 NAT 机上：4 核 15G，但它是 NAT 内网，所有公网访问全靠 frp 隧道转发，而且这台机器即将废弃。

8 月 10 日到 12 日，我把它整体迁移到了一台 VMware 虚拟机（Debian 13，4 核 / 12G 内存 / 75G SSD），顺带把管理面板、QQ 机器人、监控体系全部重建了一遍。

这篇记录一下迁移过程中踩的坑和最终架构。

## 时间线

| 时间 | 事件 |
|------|------|
| 8/10 | 0号机 MC 服开机排障（MCSM v10 API 大坑） |
| 8/11 白天 | 镜像迁移 + 数据打包到 VM 机，MCSM 迁入 |
| 8/11 晚 | 面板打通、LLBot/EasyBot 恢复、假人权限开放 |
| 8/11 深夜 | Dynmap 头像修复 + SSL 证书 + spark 监控 |
| 8/12 | 硬重启后全服务自愈体系（systemd） |

## 架构最终形态

```
玩家 ──→ hkmc.ydj001.xyz (SRV → hk.ydj001.xyz:25565) ──→ 香港 frps ──→ 2号机 VM ──→ MC 服 (Docker)
玩家 ──→ hj.wwszxc.tax:31552 (frp 直连，无 SRV) ──→ 2号机 VM（备用入口）

浏览器 ──→ map.ydj001.xyz ──→ 香港 nginx ──→ frp ──→ Dynmap 8123
浏览器 ──→ mcsm.ydj001.xyz ──→ 香港 nginx ──→ frp ──→ MCSM 面板
```

> 注：上面链路图里的 SRV/入口信息已按 2026-08-12 实际 DNS 查询修正——SRV 记录只有 `hkmc.ydj001.xyz` 有（指向 `hk.ydj001.xyz:25565`），`mc.ydj001.xyz` 只是 Cloudflare 代理域名，玩家直连不了。

实际入口架构（DNS + 连通性实测）：

{{< figure src="srv-arch.png" alt="MC 服务器玩家入口架构图" caption="MC 服务器玩家入口架构（2026-08-12 实测）" >}}

迁移后 2 号机（VM）上跑的东西：

| 服务 | 容器/进程 | 端口 |
|------|-----------|------|
| MC 服 | mcsmanager-daemon（MCDR + Fabric） | 25565 |
| MCSM 面板 | mcsmanager-web + daemon | 23333 / 24444 |
| EasyBot | easybot 容器 | 5000 |
| LLBot | llbot 容器 | 3081 / 3010 |
| Dynmap | 内嵌 MC 服 | 8123 |
| frp 客户端 | systemd ×2（浙江/香港） | — |
| mihomo 代理 | systemd | 7890 |

## 踩过的坑（按杀伤力排序）

### 1. MCSM v10 不是 v9，API 完全不一样

网上搜到的 MCSM 教程全是 v9 的，v10 的路由、鉴权方式全变了：

- API key 的 header 是 `x-request-api-key`（不是 `x-api-key`）
- 发命令走 `/api/protected_instance/command`（不是 `/api/instance/command`，那是 404）
- 批量启停用 `/api/instance/multi_open` / `multi_stop`
- daemon 端口 24444 只有 WebSocket，HTTP 全是 404

**最坑的是误导性报错**：面板报"令牌验证失败/权限不足"，实际根因是香港机 nginx 反代端口写错（7344 vs 7244），web 连不上 daemon。排查方向差点被带偏。

### 2. Dynmap 头像永远加载不出来

排查发现 `skin-url` 配置指向 `http://skins.minecraft.net/...`——Mojang 多年前就关闭了这个服务。

修复：改成 `https://minotar.net/skin/%player%`（按玩家名查皮肤）。注意 Dynmap **没有 reload 命令**，改配置必须重启服务器。

### 3. LLBot 硬重启后掉登录

QQ 协议端的通病：VM 硬重启 = 进程被强杀，腾讯服务端判定 session 异常下线 → 强制重新扫码。NapCat / Lagrange / LLBot 全都这样，**无解**，只能靠优雅停止容器 + 自愈脚本检测报警。

### 4. MCSM 停止后不能立刻启动

`multi_stop` 返回后立刻 `multi_open` 会报「实例未处于关闭状态」——必须等进程完全退出（status 变成 0/1）再启动。

### 5. easybot 是"裸容器"

自愈测试时发现 easybot 容器没有 compose 标签，`docker compose up` 报容器名冲突——它不在 compose 管理内，真挂了 compose 拉不起来。修复：补全 compose 的 volumes（实际容器有 5 个挂载点，compose 只定义了 2 个，直接重建会丢数据库）→ 删容器 → compose 重建。

## 自动化：硬重启后全自动恢复

这次迁移最有价值的产出是一个 **systemd 自愈服务**（`mc-selfheal.service`）：

```bash
# /usr/local/bin/mc-selfheal.sh（开机自动执行）
# 1. 等 Docker 就绪
# 2. docker compose up -d 拉起 3 个栈（bot / mcsmanager / openclaw）
# 3. 确认 4 个关键容器 Up
# 4. 等 MCSM API 就绪
# 5. 确保 MC 实例运行（没跑就 API 拉起）
# 6. 验证 5 个端口（5000/3081/23333/24444/25565）
# 7. 检查 LLBot 登录态（milky API OK = 正常）
```

日志在 `/var/log/mc-selfheal.log`。实测 3 次运行全绿，输出：

```
compose 拉起: /opt/bot
容器 OK: llbot / easybot / mcsmanager-daemon-1 / mcsmanager-web-1
MC 实例运行中 (status=3)
端口 OK: 5000/3081/23333/24444/25565
LLBot 登录态正常 (milky API OK)
```

这样 VM 再怎么硬重启，MC 服 + 面板 + 机器人 5 分钟内自动全恢复，不用半夜爬起来手动开服。

## 监控体系

- **spark**：MC 服性能监测（TPS / 内存 / 卡顿定位），崩服前就能看到趋势
- **crash-reports/**：Fabric 自动生成的崩溃报告，历史 7 份崩溃 = 5 次实体区块迭代 bug（假人触发）+ 2 次 tick 卡死（迁移期 IO）
- **Dynmap**：网页实时地图 map.ydj001.xyz，Let's Encrypt 正式证书，玩家头像已修复

## 经验总结

1. **迁移的核心不是"搬数据"，是"重建可维护性"**——数据 tar 一下就能搬，但 API 鉴权、compose 归属、自愈脚本这些才是长期价值
2. **误导性报错要先怀疑链路**——面板说"令牌失败"，先查 nginx 端口、frp 隧道，别一头扎进鉴权代码
3. **删容器前先核对 compose 与实际配置**——volumes、网络、env 差一个都可能丢数据
4. **QQ 协议端要接受"硬重启掉登录"**——能优雅停就优雅停，不能就做好检测报警

服务器迁移至此告一段落。MC 服、面板、机器人、监控、自愈，全部就位。
