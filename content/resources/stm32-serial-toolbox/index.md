---
title: "STM32 串口日志清理小工具（serial-tidy）"
authors:
  - duangx4
date: 2026-10-10T13:15:00+08:00
lastmod: 2026-10-10T13:15:00+08:00
draft: false
weight: 10
description: "只用 Python 标准库的命令行小工具：把 STM32 串口日志按时间戳分段、过滤噪声行，导出成干净文本。"
tags: ["STM32", "串口", "日志", "Python"]
categories: ["资源分享"]
cover: cover.png
attachments: []
showComments: false
---

## 这是什么

串口调试抓下来的日志往往又长又乱：心跳、`WARN`/`DEBUG` 之类的噪声行混在真正的业务输出里，一次会话从开机到复位的内容全堆在同一个文件里，贴到 issue 或周报前总要手动清理。这个小工具 `serial-tidy.py` 只用 Python 标准库，就能把日志**按时间戳分段**、**丢掉噪声行**，输出成若干份干净的文本文件。适合做 STM32 / 嵌入式串口调试、需要整理日志的人。来源为分享者自制的命令行脚本，版本 v1.0。

## 内容清单

- `stm32-serial-toolbox-v1.0.zip` / 1.0 / 1.1 KB（内含 `README.md` 与 `serial-tidy.py`）

## 下载

{{< download-table caption="解压后得到 serial-tidy.py 与 README.md，无需安装。" hash="SHA256" col1="文件" >}}
stm32-serial-toolbox-v1.0.zip | 1.0 | 1.1 KB | 10b0be1d1f92cb9aa82f460fa9e2c3565de14ab6a597a2b766e52def7af0d7bc | stm32-serial-toolbox-v1.0.zip
{{< /download-table >}}

## 更新日志

- 2026-10-10：首发 v1.0

## 使用教程

### 准备

1. 需要 Python 3.9+，脚本只用标准库，无需 `pip` 安装任何依赖
2. 解压 `stm32-serial-toolbox-v1.0.zip`，得到 `serial-tidy.py` 和 `README.md`

### 运行

```bash
python3 serial-tidy.py <串口日志.txt> --drop-noise --split 30s
```

- `<串口日志.txt>`：要清理的原始日志文件
- `--drop-noise`：丢弃形如 `WARN` / `DEBUG` / `heartbeat` / `tick` 的噪声行；不加则全部保留
- `--split 30s`：相邻两行时间戳间隔超过 30 秒就切成新文件

### 输出

- 在当前目录生成 `clean-000.txt`、`clean-001.txt`…… 每个文件是一段连续会话
- 终端会打印一共输出了几个分段文件

## 常见问题

**Q：日志行没有时间戳，还能用吗？**
A：脚本按行首形如 `[HH:MM:SS.mmm]` 的时间戳分段；没有可识别时间戳时不会切分，但仍会照常过滤噪声并整篇输出。

**Q：被杀毒软件 / SmartScreen 拦截？**
A：这是纯 Python 标准库脚本，不含二进制、不发起网络请求，可直接打开 `serial-tidy.py` 审阅；介意的话按需 `chmod +x` 后自行运行。

**Q：下载链接失效？**
A：在[留言板]({{< ref "message" >}})反馈，我会补链。
