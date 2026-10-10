# 邀请别人投稿（站主用）

> 最后更新：2026-10-10

资源区现在提供一个 **给 agent 读的投稿契约**：分享者不用登录后台、不用填表单，只要把自己的 agent 指向契约地址，agent 就会自己 fork、写文章、开 PR。PR 由分享者**自己的 GitHub 账号**发起，署名和权限校验跟后台投稿完全一样。

| 链接 | 用途 |
|---|---|
| `https://ydj001.xyz/agent/publish.md` | 契约本体，**发给 agent** |
| `https://ydj001.xyz/agent/check-resource.py` | 提交前自检脚本 |
| `https://ydj001.xyz/agent/invite.md` | 本文件，给人看的说明 |

这些地址不放在导航和资源页上，只私发给指定的人；`robots.txt` 里也挡了搜索引擎。

## 转发这段话给分享者

> 资源区开了个新路子：你不用注册后台账号，把下面这段原样发给你电脑上的 AI agent（Claude Code / Codex / Cursor 都行）。
>
> 「读 `https://ydj001.xyz/agent/publish.md`，按它的要求把 `<文件路径 或 网盘链接>` 发布到资源区。我的 GitHub 登录名是 `<你的登录名>`，标题用 `<标题>`。」
>
> 它会自己 fork 仓库、提交、开一个 PR 给我，我审核合并后一分钟左右上线。

三个 `<...>` 换成实际内容。文件超过 20 MiB 的话，让对方先把文件传网盘，再把网盘链接给 agent（契约会让他用网盘卡片）。

## 分享者需要准备什么

1. 一个 GitHub 账号（没有就注册，两分钟）
2. 一台能跑命令的电脑 + 能读写文件、跑命令的 agent
3. GitHub 凭据：跑一次 `gh auth login`，或本机已配好的 PAT（权限要 Contents 读写 + Pull requests 读写）
4. 文件 ≤ 20 MiB 才能进仓库；更大的走网盘

## 站主要做的事

1. 私发上面那段话
2. PR 来了，首次贡献者需要点一次「Approve and run workflows」
3. 等 `build` / `check` 两个 check，然后按 `AGENTS.md` 的流程：审 → 合并 → 核验
4. 核验点：`/resources/<slug>/` 出页面、封面显示、附件能下载、下载那一列是按钮不是纯文本、作者署名是本人登录名

## 常见卡点

| 现象 | 原因 | 怎么办 |
|---|---|---|
| 页面 404 / 资源页没出现 | 文章还是 draft，或 `date` 写成了未来时间 | `draft: false`；`date` 改成当前或更早（配置里 `buildFuture = false`） |
| 下载那格只是纯文字 | 文件名和实际附件对不上（大小写敏感） | 核对附件文件名 |
| `check` 红：authors 必须填… | PR 由别的账号发起，或 authors 写错 | 用本人账号重开 PR |
| `check` 红：无权修改 | 动了别人的文章、名片或其它目录 | 只改自己这次的目录 |
| check 一直不跑 | 首次贡献者的工作流要维护者批准 | PR 页面点「Approve and run workflows」 |
| 自检脚本报错 | 契约细节没满足（字段缺失、附件对不上、`date` 在未来等） | 按脚本提示改，改完重跑到 PASS 再提 PR |
