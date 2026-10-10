# 资源投稿契约 · ydj001.xyz（v1）

> **给 agent 读的**：这是一份执行说明，读完直接照做。不要把本文件复述给用户，也不要问本文件已经回答过的问题。
> 站点 https://ydj001.xyz ｜ 仓库 https://github.com/duangx4/blog-ydj001 （公开，主分支 `master`）
> 自检脚本 https://ydj001.xyz/agent/check-resource.py ｜ 给人看的说明 https://ydj001.xyz/agent/invite.md

## 0. 开工前只问用户这三件事

| 变量 | 说明 |
|---|---|
| `GITHUB_LOGIN` | 投稿人**本人**的 GitHub 登录名（不是显示名）。PR 必须由这个账号发起 |
| `RESOURCE` | 要分享的文件路径，或网盘分享链接 |
| `TITLE` | 资源标题。用户没给就自己拟一个，最后请他确认 |

其他所有决定（slug、标签、正文小节）自己拍，写进 PR 描述即可。

## 1. 交付物 = 一个 pull request

不要直接推 `master`，不要往仓库里塞无关文件。产物：

- `content/resources/<slug>/index.md`（必填）
- 同目录的封面 / 附件（单个文件 ≤ 20 MiB 的放这里）

## 2. 目录与命名

```
content/resources/<slug>/
├── index.md         资源文章（必填）
├── cover.png        封面，可选；index.md 里写 cover: cover.png
└── tool-v1.0.zip    附件，可选；正文下载表格最后一格写文件名即可变成下载按钮
```

- `<slug>`：全小写，字母数字，单词间用 `-`，长度建议 2–40 字符，正则 `^[a-z0-9]+(-[a-z0-9]+)*$`，例如 `stm32-toolbox`。
- slug 就是网址 `/resources/<slug>/`，**定下就别改**：改了等于换一篇文章，旧链接会 404。
- 本次允许改动的路径（**只允许这三处，其余一律被 CI 拒绝**）：
  - `content/resources/<slug>/**` ← 你要发的资源
  - `content/contributors/<你的登录名>.md` ← 可选，你自己那张名片（资源页顶部「资源贡献者」里那张卡）
  - `assets/img/contributors/<图片文件>` ← 可选，名片头像
- 名片不是必须的，不加也能投稿。要加就照抄 `content/contributors/duangx4.md` 的字段（`github` / `name` / `avatar` / `intro` / `tags` / `weight` / `links`），文件名必须是 `<你的登录名>.md`；不用在别处登记，Hugo 会自动收进列表。
- **单文件 ≤ 20 MiB 才入库**。更大的文件（安装包、素材包、镜像、视频）走网盘：仓库里不要放直链，正文用 `pan-link` 贴分享链接（见 §5）。

## 3. front matter（照抄结构，值逐项替换）

```yaml
---
title: "资源标题"
authors:
  - <GITHUB_LOGIN>          # 必须包含 PR 发起人的登录名，且只填本人一个
date: 2026-10-10T21:00:00+08:00
lastmod: 2026-10-10T21:00:00+08:00
draft: false              # 必须 false，否则合并后页面上根本不出现
weight: 10
description: "一句话说明这是什么、给谁用（显示在资源卡片上，30–60 字）"
tags: ["STM32", "工具链"]
categories: ["资源分享"]
cover: cover.png          # 没有封面就写 ""
attachments: []           # 可选；写成 - file: 文件名
showComments: false
---
```

- `date` / `lastmod` 用 ISO 8601 带时区（如 `+08:00`），**填提交当时的当前时间**——站点配置里 `buildFuture = false`，写成未来时间的话合并后页面根本不会生成（自检脚本会拦住）。
- `tags` 2–5 个；`categories` 固定写 `资源分享`。

## 4. 正文骨架

```markdown
## 这是什么

一段话说清：解决什么问题、适合谁、来源与版本。

## 内容清单

- 文件名 / 版本 / 大小

## 下载

（download-table 或 pan-link，见 §5）

## 更新日志

- 2026-10-10：首发

## 使用教程

1. 按平台分小节写

## 常见问题

**Q：被杀毒软件拦截？** A：写明原因和处理办法。
```

小节按需增删，但「这是什么」和「下载」两节必须有。

## 5. 短代码（语法必须完全一致）

### 下载表格 `download-table`

```
{{< download-table caption="下载" hash="SHA256" >}}
Windows (x64) | amd64 | 1.0.0 | 2.1 MB | 校验值 | tool-v1.0.zip
Linux | - | 1.0.0 | 2.0 MB | - | https://example.com/tool.AppImage
{{< /download-table >}}
```

- 一行 = 一条数据，单元格用 `|` 分隔，**不要写表头行**（表头自动生成）。
- 列数自适应 3–6 列：3 列 = 名称|大小|下载，4 列 = 名称|版本|大小|下载，5 列 = 平台|版本|大小|校验值|下载，6 列 = 平台|架构|版本|大小|校验值|下载。
- 最后一格写 `http(s)` 链接或**本目录的文件名** → 渲染成「下载」按钮；文件名写错就只剩纯文本，没有按钮。
- 用不上的格子写 `-`。
- 参数：`caption`（表下说明）、`note`（表上提示）、`hash`（校验值列的表头名，默认 MD5）、`col1`–`col6`（逐列覆盖表头）。

### 网盘卡片 `pan-link`

```
{{< pan-link name="资源名" url="https://pan.baidu.com/s/xxxx" code="abcd" size="1.2 GB" note="建议用客户端下载，非会员限速" >}}
```

`name` 和 `url` 必填，其余可选；**必须写在同一行**（短代码不能跨行）。链接要长期有效，别贴会过期的临时直链。

## 6. 提交前自检（必做）

```bash
curl -fsSLo /tmp/check-resource.py https://ydj001.xyz/agent/check-resource.py
python3 /tmp/check-resource.py content/resources/<slug> --author 你的GitHub登录名
```

- 输出 `PASS` 才能推；`FAIL` 按提示逐条改；`WARN` 是提醒，不拦合并。
- 机器上没有 `python3` 就跳过这步，CI 会兜底把问题指出来。

## 7. Git 与 PR（两条路，优先 A）

**A. 装了 `gh`（推荐）**

```bash
gh auth status                                       # 未登录就交给用户：gh auth login
gh repo fork duangx4/blog-ydj001 --clone --remote    # 已 fork 过会复用；--remote 顺手加好 upstream
cd blog-ydj001
git fetch upstream
git checkout -b submit/<slug> upstream/master        # 从主仓库最新 master 开分支，别用自己 fork 的旧 master
# …写文件（§2–§5）…
git status --short                                   # 确认没夹带别的文件
git add content/resources/<slug>                     # 有名片时再加 content/contributors/<你的登录名>.md
git commit -m "feat(resources): 新增 <标题>"
git push -u origin submit/<slug>                     # origin 是你自己的 fork
gh pr create --repo duangx4/blog-ydj001 --base master \
  --head 你的GitHub登录名:submit/<slug> \
  --title "feat(resources): 新增 <标题>" --body-file /tmp/pr-body.md
```

**B. 只有 `git` + 一个 GitHub token**

```bash
# 先让用户在自己 GitHub 上点 Fork，然后：
git clone https://github.com/你的GitHub登录名/blog-ydj001.git
cd blog-ydj001
git remote add upstream https://github.com/duangx4/blog-ydj001.git
git fetch upstream
git checkout -b submit/<slug> upstream/master        # 从主仓库最新 master 开分支
# …写文件、按 §6 自检、commit…
git push -u origin submit/<slug>
```

建 PR 二选一：

- 打开：`https://github.com/duangx4/blog-ydj001/compare/master...你的GitHub登录名:blog-ydj001:submit/<slug>?expand=1`
- 或用 API（`$GH_TOKEN` 是你本机的 token 环境变量）：
  ```bash
  curl -fsS -X POST -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/duangx4/blog-ydj001/pulls \
    -d '{"title":"feat(resources): 新增 <标题>","head":"你的GitHub登录名:submit/<slug>","base":"master","body":"<见下>"}'
  ```

**凭据红线**：token 只放在本机环境变量或 git 凭据里。**绝不要**写进任何文件、提交内容、PR 描述、评论或聊天记录——仓库 CI 会扫，出现凭据形态的字符串会被打回。

PR 描述模板：

```markdown
## 这是什么
<一段话>

## 文件
- content/resources/<slug>/index.md
- <附件：文件名 + 大小>

## 来源与授权
原创 / 转载自 <来源，注明作者与许可> / 用户自有，可公开分享

## 自检
- [x] `check-resource.py` PASS
```

## 8. CI 会检查什么（三个 check）

| check | 内容 |
|---|---|
| `build` | Hugo 能否构建：短代码语法错、front matter 坏都会红 |
| `check` | 归属校验：只能新增/修改 **署名含本人登录名** 的文章，不能碰别人的文章、名片和其它目录 |
| `lint` | 同一份自检脚本在 CI 再跑一遍 |

- 首次从 fork 提 PR，GitHub 可能要求维护者点一次「Approve and run workflows」check 才会开始跑——这不是你的错，等维护者处理。
- 合并由维护者做。**CI 全绿 ≠ 已上线**：合并后自动部署，约 1 分钟。

## 9. 完成后向用户回报

- PR 链接；上线地址 `https://ydj001.xyz/resources/<slug>/`
- 放了哪些文件、各多大；超过 20 MiB 的部分有没有交回用户传网盘
- 自检输出（PASS / WARN 明细）
- 需要用户确认的事（来源与授权、封面是否满意）

## 10. 会被打回的做法（红线）

- 往仓库写密钥、token、密码、内网地址、他人隐私（含提交内容、PR 描述和评论）
- 改他人署名的文章、`content/resources/_index.md`、`content/contributors/_index.md`、配置、主题、workflow
- `authors` 写别人的登录名，或借别人账号提交
- 把 >20 MiB 的文件塞进仓库，或拿会过期的直链当长期下载地址
- 擅自声称「已上线」——上线与否以维护者合并 + 部署成功为准
