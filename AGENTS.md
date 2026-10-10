# AGENTS.md — 博客仓库协作规范

本仓库由两个 agent 协同维护，站主是 `duangx4`。两边读的都是这一份文件（Claude Code 经 `CLAUDE.md` 引用）。

| 角色 | 运行位置 | 负责 |
|---|---|---|
| **Claude Code** | 站主笔记本（会关机） | 主题 / 布局 / shortcode、workflow、CMS 配置、较大的重构；本地预览验证后开 PR |
| **Hermes** | VM `doge`（常驻，QQ 可达） | 站主 QQ 里交代的小改动；**所有 agent PR 的审查与合并**；上线后核验；香港机上 nginx / `oauth.ydj001.xyz` |

## 站点结构

- Hugo **0.164.0 extended**，配置在 `config/_default/`，主题 `themes/ink/`（直接入库，不是子模块）
- `layouts/` 覆盖主题同名文件；改主题行为优先放 `layouts/`
- 内容：`content/blog/`、`content/projects/`、`content/resources/<slug>/index.md`、`content/contributors/<GitHub 登录名>.md`
- 后台：Sveltia CMS，`static/admin/config.yml`；登录走 `oauth.ydj001.xyz`（香港机 nginx 反代到 node 进程 4099 端口；该进程监听 0.0.0.0，靠 ufw 挡住外网）
- `public/` 是构建产物，不入库
- 资源投稿契约：`static/agent/` 下是给 **agent** 读的投稿通道——`publish.md`（契约，线上 `https://ydj001.xyz/agent/publish.md`）、`invite.md`（人看的邀请/转发说明）、`check-resource.py`（自检脚本，投稿者在本地跑，见下方 issue #20）。站主私发链接给指定分享者，不做站内公开入口；`layouts/robots.txt` 里 `Disallow: /agent/`。

## 工作流

1. **不直接推 master。** 从最新 master 开分支：Hermes 用 `hermes/<主题>`，Claude 用 `claude/<主题>`，外部分享者用 `submit/<slug>`。
2. 提交前本地跑 `hugo --gc --minify`，0 错误。
3. 开 PR，描述里写清：改了什么、为什么、怎么验证的、需要上线后看哪个 URL。
4. **审查 + 合并统一由 Hermes 做**，见下一节。
5. 发布只走 `deploy.yml`（master 有推送即触发）。**不要用 `deploy-blog.ps1`**：它用 scp 绕过 git，只覆盖不删除，会让线上和仓库不一致。只在 CI 整体不可用时由站主手动使用。

## 审查与自动合并（Hermes）

适用于 `hermes/*`、`claude/*`，以及外部分享者用自己账号从 agent 提交的 `submit/*` PR（同一套标准，契约见 `static/agent/publish.md`）。

> Hermes 环境：仓库副本 `/opt/data/repos/blog-ydj001`；GitHub 操作一律用 `ghx`（读 `/opt/data/.env` 里的 token 再调 `gh`，用法与 `gh` 相同；裸 `gh` 未登录）。PR 作者和 token 都是 `duangx4`，所以 `--approve` 会被 GitHub 拒绝，审查结论用 `--comment`。

1. 等 `ghx pr checks <号>` 出结果，看两个作业：`build`（构建）、`check`（`resource-ownership` 的归属校验），两个都是必过项。改了资源文章的 PR 两个都会跑，改别的（主题、配置、文档）只有 `build`。资源契约的自检（`static/agent/check-resource.py`）目前只在投稿者本地跑；CI 侧的同一个作业在 issue #20（要改动 `.github/workflows/`，得有 `Workflows` 写权限的 token）。
2. **审查必须在一个新会话里做**，只看 `ghx pr diff <号>` 和本文件，不带写这个 PR 时的上下文——自己审自己时尤其如此。
3. 审查清单：
   - 改动和 PR 描述一致，没有夹带无关文件
   - 没有密钥、口令、内网地址、私人信息进入仓库
   - 遵守下面「必须成对」「不要做」两节
   - 模板改动：涉及的页面类型都考虑到了（列表页 / 单页 / 404 / 移动端）
4. 结论写成 PR 评论（`ghx pr review <号> --comment`），列出看过的点和发现。
5. 没问题：`ghx pr merge <号> --squash --delete-branch`。有问题：评论说明，不合并；是对方的 PR 就加标签 `agent:claude` 交回去。
6. 合并后：确认 `deploy` 运行成功，并访问 PR 描述里给的 URL（加 `?v=<时间戳>` 绕缓存）确认已生效，结果回帖到 PR。PR 声明「无页面变化」时，以 deploy 成功 + 首页 `https://ydj001.xyz/` 返回 200 为准。

贡献者从后台提交的 PR（`cms/*` 分支）：Hermes 审查并评论，**合并留给站主**。

## 交接

- 一方做不完或需要对方处理 → 开 **issue**，加标签 `agent:hermes` 或 `agent:claude`。不要往仓库里写交接文档，它们会过时。
- Claude 可以直接问 Hermes：`ssh -p 9022 root@doge.hesitate-p.tech 'docker exec -i -u 10000 hermes hermes chat --query-file - -Q'`，问题从 stdin 传入。Hermes 联系不到笔记本，只能留 issue。
- 改了服务器（nginx、oauth 代理等不在仓库里的东西）→ 开 issue 加标签 `server`，写明改了什么、备份在哪、怎么回滚。

## 提交风格

`类型: 中文描述`，类型用 `feat` / `fix` / `refactor` / `ci` / `chore` / `docs` / `post`，可带范围如 `fix(cms):`。正文用中文说明原因。

## 必须成对

- `static/admin/config.yml` 与 `.github/workflows/resource-ownership.yml`：CMS 的按钮开关和 CI 的归属校验是一套，改一个就检查另一个，放在同一个 PR。
- `static/agent/publish.md`（契约）↔ `static/agent/check-resource.py`（自检脚本）：同一套规则，改契约必须同步改脚本。脚本一份两用（投稿者本地 + 将来的 CI 作业），别另写一份逻辑。
- 契约里给分享者看的字段/示例变了，顺手更新 `static/agent/invite.md` 里那段可转发的话和 `docs/cms-handover.md` 的「投稿通道」一节。

## 不要做

- 不要 force push master，不要改写已推送的历史
- 不要改别人的 `content/contributors/*.md` 卡片和别人署名的资源文章（站主要求的除外）
- 不要给 `deploy.yml` 的 rsync 加 `--delete`：服务器上有仓库外的文件（如 `sync-mc.ps1` 推送的 `mc/`）
- 不要把任何凭据写进仓库、PR 描述、评论或 issue
