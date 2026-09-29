---
title: "资源页模板示范"
date: 2026-09-28
lastmod: 2026-09-28
draft: false
weight: 999
tags: ["模板", "示范"]
categories: ["资源分享"]
description: "一篇照着就能写的资源页范例：下载表格、网盘卡片、分平台教程怎么用。新建资源页请看这篇的结构，不要照抄内容。"
cover: ""
showComments: false
---

> 这是**写作模板示范**，不是真实资源。新建资源页用 `hugo new resources/<名字>/index.md`，
> 生成的结构与本页一致，把示例内容换成你自己的即可。想从列表页隐藏就删掉本页。

## 这是什么

一段话讲清：解决什么问题、适合谁。例如「一套自用的 STM32 工程模板，帮你跳过重复的时钟树配置」。

## 内容清单

- `demo-template-v1.0.0.zip` / 1.0.0 / 2.1 MB
- `使用说明.pdf` / 0.3 MB

## 下载

下面这张表是 **6 列**（平台 / 架构 / 版本 / 大小 / 校验值 / 下载），每行只写数据、用 `|` 分隔，不适用的格写 `-`。
列数自适应：少写几列也能渲染（3 列 = 名称/大小/下载）；`hash="SHA256"` 可把校验值列的表头改名。

{{< download-table caption="不确定架构就选 x64；旧版本保留以便回退。" hash="MD5" >}}
Windows (x64) | amd64 | 1.0.0 | 2.1 MB | d41d8cd98f00b204e9800998ecf8427e | https://example.com/demo-x64.zip
Windows (ARM64) | arm64 | 1.0.0 | 2.0 MB | - | https://example.com/demo-arm64.zip
macOS (Apple Silicon) | arm64 | 1.0.0 | 2.3 MB | 0cc175b9c0f1b6a831c399e269772661 | https://example.com/demo-arm64.dmg
Linux | - | 1.0.0 | 2.0 MB | 92eb5ffee6ae2fec3ad71c777531578f | https://example.com/demo.AppImage
旧版本 v0.9.9 | amd64 | 0.9.9 | 1.9 MB | 4a8a08f09d37b73795649038408b5f33 | -
{{< /download-table >}}

只有 3 列时是这样（自动收窄表头）：

{{< download-table caption="简化写法：名称 | 大小 | 下载" >}}
示例工具包.zip | 12 MB | https://example.com/pack.zip
{{< /download-table >}}

大文件走网盘时，用网盘卡片代替表格里的直链行：

{{< pan-link name="示例大文件包" url="https://pan.baidu.com/s/example" code="abcd" size="1.2 GB" note="建议用客户端下载，非会员限速" >}}

## 更新日志

- 2026-09-28：首发
- 2026-09-20：修正 Windows ARM64 版本号写错

## 使用教程

### Windows

1. 下载对应架构的压缩包（不确定就选 x64）
2. 核对校验值：`certutil -hashfile 文件名 MD5`
3. 解压即用，无需安装

### 手机 / 其他设备

1. 用不到的平台小节直接删掉，别留空壳
2. 需要额外软件打开时，写清楚软件名和版本要求

## 常见问题

**Q：下载链接失效了？**
A：在[留言板]({{< ref "message" >}})反馈，我会尽快补链。

**Q：报毒 / 被拦截？**
A：自编译的未签名程序常被 SmartScreen 拦，点「更多信息 → 仍要运行」即可；介意的话可以自行编译。
