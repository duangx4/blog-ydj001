---
title: "FRP 内网穿透矩阵"
date: 2025-08-01
weight: 20
description: "5 个子域名穿透到 0 号机，统一管理后台。"
cover: "img/projects/frp-cover.svg"
tags: ["运维", "FRP"]
categories: ["个人项目"]
links:
  - name: "FRP 管理面板"
    url: "https://frp.ydj001.xyz"
---

把家里的 0 号机（Windows 主机）通过香港 VPS 中转，搭建 5 个公网子域名，统一管理后台、博客、机器人。

**技术栈**：FRP · Nginx · Cloudflare · Windows Server
**亮点**：
- 反向代理 + TLS 终结
- Cloudflare 橙色云代理（隐藏源 IP）
- 自动续签 + 健康检查