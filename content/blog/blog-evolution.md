---
title: "博客进化论：从零评论区到 Twikoo 留言板"
slug: "blog-evolution"
date: 2026-07-29
description: "一天之内，一个个人博客从裸奔到拥有 Umami 统计 + 免登录评论系统，中间踩了哪些坑。"
tags: ["博客", "运维", "Hugo", "Giscus", "Twikoo", "Umami"]
categories: ["技术向"]
weight: 1
---

距离上次发文过去了一周，这周没写新东西，**全在折腾博客本身**。也算是每个建站人的必经之路——站点搭好了，就开始琢磨怎么让它更完整。

这篇就当是今天的折腾实录，顺便当个索引。

---

## 一、早晨的 P0 轮改进

早上 8 点开始，对着博客修了一圈基础问题：

### 1. SSH 密钥代替密码登录

deploy-blog.ps1 之前用的是 sshpass 明文密码，改为 SSH 密钥认证：

```bash
ssh-keygen -t ed25519 -C 'blog-deploy'
```

然后把公钥扔到 1 号机的 `~/.ssh/authorized_keys`。

**但！一开始死活连不上。** 查了半天发现 `/etc/ssh/sshd_config` 里写的是 `PubkeyAuthentication no`——Ubuntu 默认镜像装的，不知道啥时候被改成关了。改成 `yes` 重启 sshd 就好了：

```bash
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

### 2. author 配置统一

作者信息之前散布在 `params.toml` 和 `languages.zh-cn.toml` 两处，统一归到 `[author]` 块，`languages.zh-cn.toml` 只保留纯语言文本。

### 3. QR 弹窗修复

文章页分享按钮里，微信/QQ 的 QR 弹窗调用了缺失的 `qrcode.js`，补上了。

### 4. SVG 资源 + 头像缩放

创建了 `background.svg` / `featured.svg` 用于默认背景和封面；修复了头像在文章页被放太大的 CSS 问题。

### 5. deploy-blog.ps1 修 bug

脚本里 `# 跳过精细清理` 后面的注释里因为带 `<>()` 导致 PowerShell 语法错误，修复后正常工作了。

---

## 二、给博客插上统计——Umami

统计系统选了 **Umami**——自托管、轻量、无广告、隐私友好。最终方案是 **Docker + PostgreSQL**。

部署在 1 号机（香港 VPS），`--network host` 模式跑在 3000 端口，Nginx 反代到 `umami.ydj001.xyz`，Certbot 自动申请 SSL。

**踩的一个坑**：Umami 后台的添加站点界面有个 UI bug，点不了。最后用 Python 脚本调 API 创建的站点，拿到 Website ID 后写进 `params.toml`：

```toml
[umamiAnalytics]
  domain = "umami.ydj001.xyz"
  websiteid = "75aa75e3-a861-4492-91bb-a74666bd0f3c"
```

现在每篇文章的访问数据都有统计了。

---

## 三、评论系统的两轮折腾

### 第一轮：Giscus（已弃用）

Giscus 基于 GitHub Discussions，访客必须有 GitHub 账号才能评论。

部署过程极其曲折——**GitHub 的复选框勾不上**。浏览器点了 30 多次无效，CDP WebSocket 操作被 403 拒绝，Playwright 模块未装。最后的解法是直接 PATCH 请求提交表单：

```javascript
// 用 fetch 直接提交表单
fetch('/settings/update', {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: `authenticity_token=${token}&discussions_enabled=true`
});
```

然而装好之后发现——**GitHub 仓库根本没开 Discussions 功能**，勾了才有的 😅

Giscus 最终跑起来了，但被提醒了一句：评论必须 GitHub 登录，对于个人博客来说门槛不低。想了下，决定换。

### 第二轮：Twikoo（目前方案）

Twikoo 是免登录的，填个昵称就能写评论，更适合个人博客。

**服务端部署**：

```bash
# Docker 一行启动
docker run -d --name twikoo \
  -e TWIKOO_THROTTLE=1000 \
  -p 127.0.0.1:8181:8080 \
  -v /opt/twikoo/data:/app/data \
  --restart unless-stopped \
  imaegoo/twikoo:latest
```

Docker Hub 直连超时（香港 VPS 特色），换成 DaoCloud 镜像 `docker.m.daocloud.io/imaegoo/twikoo` 拉下来了。

Nginx 反代到 `twikoo.ydj001.xyz`，HTTPS 证书一步到位：

```bash
certbot --nginx -d twikoo.ydj001.xyz
```

**前端嵌入**：

在 `layouts/partials/comments.html` 里加上：

```html
<div id="twikoo"></div>
<script src="https://cdn.jsdelivr.net/npm/twikoo@1.7.15/dist/twikoo.all.min.js"></script>
<script>
twikoo.init({
  envId: "https://twikoo.ydj001.xyz",
  el: "#twikoo",
});
</script>
```

> **小插曲**：我一开始用了 `cdn.staticfile.org` 的 CDN，结果是 404——那个源根本没有 1.7.15 版本。换成 `cdn.jsdelivr.net` 就正常了。

同时删掉了 Giscus 的全部配置和模板，现在干净了：

```toml
# 现在的 params.toml 评论配置
[comments]
  enable = true
```

### 留言板独立页面

除了文章评论区，还单独建了一个 `/message/` 页面作为留言板，同样嵌入 Twikoo，放到导航栏里。想聊点跟单篇文章无关的，直接在留言板说。

---

## 四、现在博客的架构

```text
ydj001.xyz（Cloudflare 橙色云 → 香港 VPS）
├── Nginx（反代所有子域名）
│   ├── ydj001.xyz → Hugo 静态文件
│   ├── umami.ydj001.xyz → Umami (Docker :3000)
│   └── twikoo.ydj001.xyz → Twikoo (Docker :8181)
├── SSH 密钥认证（deploy-blog.ps1）
├── Let's Encrypt SSL（Certbot 自动续期）
└── GitHub → 博客源码仓库
```

## 五、学到了什么

1. **GitHub Settings 页面的复选框是 React 控制的**——鼠标点击触发不了真正的提交，得直接调 API。这是一个大坑，以后任何 GitHub 设置页面的操作都优先想 API 方案。
2. **香港 VPS 连 Docker Hub 经常超时**——备一个国内镜像源（如 `docker.m.daocloud.io`）是必要的。
3. **CDN 资源不要想当然用 staticfile.org**——先 verify 一下该版本是否存在。jsDelivr 和 unpkg 更靠谱。
4. **`PubkeyAuthentication no`**——如果你的 SSH 密钥死活不生效，先怀疑这个。
5. **免登录 > 需登录，对个人博客来说**——用户少一个步骤就多一分留下评论的可能。

---

以上就是今天的"基建"成果。下一篇回到技术分享本身——可能写写 Twikoo 部署细节，或者前段时间的优班答辩 PPT 自动化。
