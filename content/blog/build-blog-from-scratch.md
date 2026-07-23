---
title: "从零搭个人博客：Hugo + 香港 VPS + Cloudflare + GitHub"
date: 2026-07-23
draft: false
tags: ["hugo", "运维", "建站"]
categories: ["个人项目"]
---

## 为什么整这个

大一想找工作，发现 HR 要的不只是成绩单，还得有点拿得出手的东西。

GitHub 上一堆代码不行——面试官没时间翻。一个干净的技术博客，把竞赛、证书、项目经历串起来，比简历上写"熟悉 Linux"有说服力得多。

恰好手上有台香港 VPS（1 号机，2C2G，之前买来折腾的），闲着也是闲着，拿来跑博客正合适。

---

## 方案选型

| 方案 | 选不选 | 理由 |
|------|--------|------|
| Halo / WordPress | ❌ | 2G 内存跑动态站浪费，还要操心数据库、更新、安全 |
| Hexo | ❌ | 依赖 Node.js，不想多装一套生态 |
| **Hugo** | **✅** | 一个二进制，构建 100ms，纯静态 = 零维护 |

核心决策：**纯静态，零维护，考试周服务器半年不开机都不会挂。**

---

## 架构

```
本地 PC (Windows)
Hugo 写文 + 构建
├─ git push → GitHub（源码备份）
└─ scp → 香港 VPS（web 服务）

VPS: Nginx 1.24 + Certbot SSL → Cloudflare（代理）→ ydj001.xyz
```

不走 GitHub Pages / CF Pages 的原因：VPS 在我手里，以后加评论区、统计、友链，改个 nginx.conf 就行，不用看平台脸色。

---

## 部署过程

### 1. VPS 基础

```bash
apt install nginx ufw certbot git unzip -y
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
```

> 第一次装 UFW 时忘了先开 22，SSH 直接断连。血的教训：**防火墙规则先加再开。**

### 2. DNS + SSL

域名 `ydj001.xyz` 已经托管在 Cloudflare，加 A 记录指向香港 VPS 公网 IP，开橙色云。

```bash
certbot --nginx -d ydj001.xyz -d www.ydj001.xyz
```

自动续期，零维护。

### 3. Hugo 建站

```powershell
winget install Hugo.Hugo.Extended
```

选 PaperMod 主题。跑 `hugo --minify`，112ms 生成 20 个页面，静态站的快乐就在这。

### 4. 自动化部署

```powershell
# deploy-blog.ps1 — 一行命令搞定
hugo --minify
sshpass scp -r public/* root@154.12.85.12:/var/www/ydj001.xyz/
git add -A && git commit -m "deploy" && git push
```

写文章 → 跑脚本，完工。

---

## 顺手牵了条 FRP 隧道

1 号机有公网 IP，0 号机（MC 服务器 / QQ 机器人）在内网。在 1 号机装 frps，0 号机装 frpc，把管理面板全部穿透出来：

```
bot.ydj001.xyz     → LLBot 管理面板
easybot.ydj001.xyz → EasyBot 管理面板
mcsm.ydj001.xyz    → MC 服务器面板
```

4 条隧道加起来不到 3MB 内存。详见上一篇《FRP 隧道》文章。

---

## 写作流程

```
在 Obsidian 写 Markdown
  → powershell -File deploy-blog.ps1
  → 上线 + GitHub 同步 一次搞定
  → 面试官：这人从大一就开始写技术博客
```

---

## 优缺点

**优点：** 零运行维护 | VPS 完全可控 | GitHub commit 记录=持续学习证据 | 零额外成本（VPS 本来就有的）

**缺点：** 不能在后台写文章（必须本地编辑）| 没手机端 | 需要一点 Linux 基础

不过这些"缺点"对我根本不叫缺点——电气 + CAAC 无人机证 + Linux 运维，这组合在同届已经有区分度了。博客本身就是能力证明，不是额外负担。
