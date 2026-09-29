---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
lastmod: {{ .Date }}
draft: true
weight: 10
tags: []
categories: ["资源分享"]
description: "一句话说明这是什么、给谁用"
cover: ""
# 需要评论区答疑就打开（全站默认关，逐页开）：
# showComments: true
---

## 这是什么

一段话讲清：解决什么问题、适合谁。

## 内容清单

- 文件名 / 版本 / 大小

## 下载

> 小文件（< 5MB）走直链，大文件走网盘。**每行只写数据，用 `|` 分隔，不适用的格写 `-`。**
> 列数自适应：3–6 列均可，6 列时顺序为「平台 | 架构 | 版本 | 大小 | 校验值 | 下载」。

{{</* download-table caption="下载说明" hash="SHA256" */>}}
Windows (x64) | amd64 | 1.0.0 | 2.1 MB | 在这里填校验值 | https://example.com/file.zip
Windows (ARM64) | arm64 | 1.0.0 | 2.0 MB | - | https://example.com/file-arm64.zip
macOS (Apple Silicon) | arm64 | 1.0.0 | 2.3 MB | - | https://example.com/file.dmg
Linux | - | 1.0.0 | 2.0 MB | - | https://example.com/file.AppImage
旧版本 v0.9.9 | amd64 | 0.9.9 | 1.9 MB | - | https://example.com/file-old.zip
{{</* /download-table */>}}

大文件走网盘时改用：

{{</* pan-link name="资源名" url="https://pan.baidu.com/s/xxxx" code="abcd" size="1.2 GB" note="建议用客户端下载，非会员限速" */>}}

## 更新日志

- {{ .Date | time.Format "2006-01-02" }}：首发

## 使用教程

### Windows

1. 下载对应架构的压缩包（不确定就选 x64）
2. 校验文件（见上方校验值）
3. 解压即用，无需安装

### 手机 / 其他设备

1. 按需分节写；用不到就删掉本小节

## 常见问题

**Q：下载链接失效了？**
A：在[留言板]({{</* ref "message" */>}})反馈，我会尽快补链。

**Q：报毒 / 拦截？**
A：写明原因与解决办法（例如未签名的自编译程序会被 SmartScreen 拦截，选择「仍要运行」）。
