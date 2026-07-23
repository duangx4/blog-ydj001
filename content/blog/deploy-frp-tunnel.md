---
title: "用 FRP 隧道打通 0 号机的 Web 管理面板"
date: 2026-07-23
draft: false
tags: ["frp", "运维", "内网穿透"]
categories: ["个人项目"]
---

## 背景

我有一台 0 号服务器（山东枣庄，NAT 内网），跑着 MC 服务器、QQ 机器人和几个 Docker 管理面板。但 NAT 模式下端口受限，管理后台没法在外面直接访问。

之前靠 Cloudflare Tunnel 解决，但延迟偏高，而且每个服务都得配隧道。

## 方案：FRP 双机隧道

用 1 号机（香港，有公网 IP）做 FRP 服务端，0 号机跑 FRP 客户端，建立内网穿透隧道。

## 部署

### 1号机（服务端）

```bash
# 下载安装
wget https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz
tar xzf frp_0.61.2_linux_amd64.tar.gz
cp frp_0.61.2_linux_amd64/frps /usr/local/bin/frps

# 配置 /etc/frp/frps.toml
bindPort = 7000
auth.token = "your-token"
webServer.port = 7500

# systemd 服务
systemctl enable --now frps
```

### 0号机（客户端）

```bash
# 配置 /etc/frp/frpc.toml
serverAddr = "1号机IP"
serverPort = 7000
auth.token = "your-token"

[[proxies]]
name = "mcsm"
type = "tcp"
localIP = "127.0.0.1"
localPort = 23333
remotePort = 7233
```

### Nginx 反代到子域名

在 1 号机的 Nginx 上，把 `mcsm.ydj001.xyz` 反代到 `127.0.0.1:7233`，把 `easybot.ydj001.xyz` 反代到 `127.0.0.1:7050`，等等。

## 效果

所有管理后台统一走 `*.ydj001.xyz` 子域名访问，不用记端口号，不用开运营商端口，4 条隧道内存占用不到 3MB。
