---
title: "博客 ydj001.xyz"
date: 2026-07-01
weight: 30
description: "Hugo + Blowfish，香港 VPS + Cloudflare CDN，全站 SSL。"
cover: "img/projects/blog-cover.svg"
tags: ["建站", "Hugo"]
categories: ["个人项目"]
links:
  - name: "在线访问"
    url: "https://ydj001.xyz"
  - name: "源码"
    url: "https://github.com/duangx4/blog-ydj001"
---

本博客本身的搭建过程：Hugo 静态生成 → Blowfish 主题深度改造（partials / templates / 自定义 about·now·projects 三页）→ 字体替换（霞鹜文楷 + 思源黑体）→ 阅读进度条 + 头像交互 → VPS 部署 → Cloudflare CDN。

**技术栈**：Hugo · Blowfish · Nginx · Cloudflare
**亮点**：
- 免备案 + 全站 SSL
- 首屏 LCP < 1s（Cloudflare 边缘缓存）
- 字体自定义、阅读进度条、OG 分享卡