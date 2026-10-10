# 资源发布后台（CMS）上线交接文档

> 最后更新：2026-09-29

## 概述

为「资源分享」区（`/resources/`）搭建了一个浏览器可访问的管理后台，让外部贡献者无需本地环境即可发布和编辑资源文章。

| 项目 | 说明 |
|------|------|
| 技术方案 | Sveltia CMS（Decap CMS 的现代分支，纯静态单页） |
| 后台地址 | `https://ydj001.xyz/admin/` |
| 登录方式 | GitHub 账号（OAuth）或 Personal Access Token |
| 发布流程 | 编辑 → 保存 → 自动 push/PR → CI 构建部署 |
| 权限控制 | 分支保护 + GitHub Actions 归属校验 |

---

## 已完成

### 1. CMS 后台页面

| 文件 | 说明 |
|------|------|
| `static/admin/index.html` | Sveltia CMS 入口，含 `pan-link` 和 `download-table` 自定义编辑组件 |
| `static/admin/config.yml` | 集合定义、字段 schema、媒体上传配置 |

**资源文章字段设计**：
- `title`、`description`、`date`、`lastmod`、`draft`、`weight`
- `authors`：贡献者 GitHub 用户名（用于归属校验）
- `tags`、`categories`
- `cover`：封面图（上传到文章目录）
- `attachments`：附件列表（上传到文章目录）
- `showComments`
- `body`：正文（支持 Markdown + 短代码组件）

**贡献者卡片字段设计**（集合「我的贡献者卡片」，每人一份 `content/contributors/<GitHub 登录名>.md`）：
- `github`：GitHub 登录名（归属校验锚点，须与文件名一致）
- `name`：卡片显示名
- `avatar`：头像（存到 `assets/img/contributors/`，模板裁成 256×256）
- `intro`：一句话简介
- `tags`：方向标签
- `weight`：排序权重
- `links`：链接按钮列表（最多 4 个，含 `label` / `url`）

### 2. 模板适配

| 文件 | 修改内容 |
|------|----------|
| `layouts/resources/list.html` | 封面图路径解析：优先检查 bundle 内资源，兼容 CMS 上传的相对文件名 |
| `layouts/resources/list.html` | 贡献者卡片改为读取 `content/contributors/` 下的页面（旧的内联 `contributors` 写法仍兼容） |
| `layouts/shortcodes/download-table.html` | 下载按钮支持 bundle 内附件文件名（除了 http/https URL） |

### 3. 贡献者卡片的数据来源

卡片从 `content/resources/_index.md` 的 front matter 里**挪了出来**，改为独立目录：

```
content/contributors/
├── _index.md      # 目录索引，cascade 里的 build.render/list: never（不对外出页面）
└── duangx4.md     # 一张卡片 = 一个文件，文件名必须是 GitHub 登录名
```

头像不放在 `content/` 下，而是由 CMS 上传到 `assets/img/contributors/`，front matter 里记
`/img/contributors/<文件名>`。原因：`content/contributors/` 是 **branch bundle**（目录里有
`_index.md`），卡片自身取不到 bundle 内资源，`.Resources.GetMatch` 永远不命中；放进
`assets/` 就能用 `resources.Get` 拿到并裁成 256×256。已用一张真实上传图验证过。

这样做的原因：所有贡献者挤在 `_index.md` 一个文件里，多人同时改必然 PR 冲突；
拆开后每人只碰自己的文件，**PR 之间零冲突**，归属校验也能精确到「这个人只能改自己那张卡」。

排序按 `weight`（越小越靠前），同权重时按文件名。

### 3. CI/CD 流水线

| 文件 | 说明 |
|------|------|
| `.github/workflows/deploy.yml` | push 到 master 触发：Hugo 构建 → rsync 部署到 VPS |
| `.github/workflows/resource-ownership.yml` | PR 归属校验：贡献者只能新增/修改署名是自己的文章 |

### 4. 本地预览配置

| 文件 | 说明 |
|------|------|
| `.claude/launch.json` | Hugo 开发服务器配置，端口 13131 |

---

## 待完成（需要你操作）

### ⚠️ 阻塞项：主题未入库

`themes/ink` 目前不在 git 跟踪范围内，GitHub Actions checkout 后无法构建。

**解决方法**：

```bash
# 1. 检查 .gitignore 是否排除了 themes/，如有则删除该行
# 2. 把主题纳入跟踪
git add themes/ink
git commit -m "chore: add themes/ink to repo for CI build"
git push origin master
```

（可选）删除废弃的 blowfish gitlink：
```bash
git rm themes/blowfish
git commit -m "chore: remove unused blowfish theme submodule"
```

---

### 1. 配置 GitHub Secrets

进入 GitHub 仓库 → Settings → Secrets and variables → Actions，添加：

| Secret 名称 | 值 |
|-------------|-----|
| `SSH_PRIVATE_KEY` | CI 专用 ed25519 私钥（**新生成，不要复用本地密钥**） |
| `SSH_KNOWN_HOSTS` | `ssh-keyscan -p 22 38.76.201.242` 的输出 |
| `DEPLOY_HOST` | `38.76.201.242` |
| `DEPLOY_USER` | `root` |
| `DEPLOY_PORT` | `22` |
| `DEPLOY_PATH` | `/var/www/ydj001.xyz` |

**生成 CI 专用密钥**：
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/ci_deploy_key -N ""
# 公钥追加到服务器
cat ~/.ssh/ci_deploy_key.pub | ssh root@38.76.201.242 "cat >> ~/.ssh/authorized_keys"
# 私钥内容填入 SSH_PRIVATE_KEY
cat ~/.ssh/ci_deploy_key
```

---

### 2. 开启分支保护（强制 PR 审核）

GitHub 仓库 → Settings → Branches → Add branch ruleset：

- **Branch name pattern**: `master`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass → 添加 `resource-ownership`
- ✅ Do not allow bypassing the above settings

这样贡献者点「发布」会创建 PR，需要你审核合并后才上线。

---

### 3. 部署 OAuth 中转服务（可选但推荐）

目前后台只能用「Sign In with Token」（PAT）登录，体验不佳。配置 OAuth 后可用 GitHub 账号一键登录。

**方案 A：Cloudflare Worker（推荐）**

使用 [sveltia-cms-auth](https://github.com/sveltia/sveltia-cms-auth) 官方模板：

1. Fork 到你的 GitHub
2. 在 Cloudflare Dashboard 创建 Worker，绑定域名 `oauth.ydj001.xyz`
3. 在 GitHub 创建 OAuth App：
   - Homepage URL: `https://ydj001.xyz`
   - Authorization callback URL: `https://oauth.ydj001.xyz/callback`
4. 把 Client ID 和 Client Secret 配置到 Worker 环境变量
5. 修改 `static/admin/config.yml`，取消注释 `base_url`:
   ```yaml
   backend:
     name: github
     repo: duangx4/blog-ydj001
     branch: master
     base_url: https://oauth.ydj001.xyz
   ```

**方案 B：继续用 Token 登录**

让贡献者自己生成 PAT（Settings → Developer settings → Personal access tokens），权限勾选 `repo`，登录时选「Sign In with Token」填入。

---

### 4. 确认 rsync --delete 范围

当前 `deploy.yml` 里 rsync **没有** `--delete`，不会删除服务器上的孤儿文件。

确认服务器 `/var/www/ydj001.xyz/` 下没有仓库外的重要文件后，可以开启：

```yaml
# deploy.yml 第 58 行
rsync -rlptz --delete --exclude='mc/' \
```

`--exclude='mc/'` 保护 Minecraft 服务器相关文件。

---

## 使用指南

### 站主发布资源

1. 访问 `https://ydj001.xyz/admin/`
2. 点击「使用 GitHub 登录」或「Sign In with Token」
3. 左侧选择「资源分享」→ 右上角「新建」
4. 填写表单，上传封面和附件
5. 点击「发布」

### 贡献者发布资源

1. 先把贡献者添加为仓库 Collaborator（Write 权限）
2. 贡献者访问后台登录
3. 新建资源，**authors 必须填自己的 GitHub 用户名**
4. 发布后会创建 PR
5. 站主在 GitHub 审核合并，CI 自动部署上线

### 贡献者编辑自己的个人卡片

资源页顶部那张名片，贡献者可以自己维护：

1. 后台左侧选「我的贡献者卡片」
2. **第一次用要先新建**，文件名填自己的 GitHub 登录名（如 `duangx4`），
   `GitHub 登录名` 字段也填同一个值——两处必须一致，CI 会校验
3. 填显示名、头像、简介、标签、链接按钮，点「发布」
4. 站主合并 PR 后上线

> 已经建过卡片的，直接点开改就行，不要再新建（会和现有文件撞名）。

### 站主管理贡献者卡片

- 卡片文件在 `content/contributors/<GitHub 登录名>.md`，也可以在本地直接编辑
- 想删除某张卡片：后台点开卡片，右上角「删除」→ 保存，会开一个删除 PR
  （只有卡片 `github` 字段是你自己的才删得掉，别人删会被 CI 打回）
- 注意删卡片**不会**连带删掉 `assets/img/contributors/` 下的头像文件，想清干净要另外删图片
- 想调整顺序：改各自的 `weight`，越小越靠前

### 正文短代码

后台编辑器工具栏「+」里有两个组件：

**下载表格**（download-table）：
```
{{< download-table caption="下载" >}}
文件名 | 版本 | 大小 | 下载链接或附件文件名
{{< /download-table >}}
```

**网盘卡片**（pan-link）：
```
{{< pan-link name="百度网盘" url="https://pan.baidu.com/..." code="xxxx" size="1.2 GB" >}}
```
`name` 和 `url` 必填（写 `title=` 页面不会渲染标题），整行写完，不能换行。

### 用 agent 投稿（2026-10-10 新增）

分享者不想登录后台、只想让自己的 AI agent 干活时走这条：给 agent 一个契约地址，它自己 fork / 写文章 / 开 PR，PR 由**分享者本人的 GitHub 账号**发起，所以归属校验和 CMS 路径完全一样，一行没改。

| 文件 | 用途 |
|---|---|
| `static/agent/publish.md` | 给 agent 读的投稿契约（线上 `https://ydj001.xyz/agent/publish.md`） |
| `static/agent/invite.md` | 人看的说明 + 可直接转发给分享者的那段话 |
| `static/agent/check-resource.py` | 提交前自检脚本，投稿者在本地跑（CI 侧同名作业待接入，见 issue #20） |
| `layouts/robots.txt` | 覆盖 Hugo 内置模板，含 `Disallow: /agent/`（入口不公开，只私发） |

- 分享者侧：`gh auth login` 一次 → agent 输出一个 PR（分支名 `submit/<slug>`）
- 站主侧：首次贡献者要点一次 PR 页面的「Approve and run workflows」；两个作业 `build` / `check`，都要过
- 不走 Collaborator：fork 路线不需要给分享者 Write 权限（CMS 路线才需要）
- 超过 20 MiB 的文件不进仓库，走网盘 + `pan-link`
- 自检脚本目前只在投稿者本地跑。想在 CI 里也跑一遍，得先给 token 加 `Workflows` 写权限（改动 `.github/workflows/` 下任何文件的硬要求），job 内容见 issue #20

---

## 文件清单

```
static/admin/
├── index.html          # CMS 入口
└── config.yml          # CMS 配置

static/agent/           # agent 投稿通道（2026-10 新增，入口不公开）
├── publish.md          # 给 agent 读的投稿契约
├── invite.md           # 人看的说明（可转发给分享者）
└── check-resource.py   # 提交前自检脚本（投稿者本地跑）

layouts/
├── resources/list.html # 资源列表（已修改封面路径解析）
├── robots.txt          # 覆盖 Hugo 内置模板（Disallow: /agent/）
└── shortcodes/
    └── download-table.html # 下载表格（已修改附件路径解析）

.github/workflows/
├── deploy.yml              # 自动部署
└── resource-ownership.yml  # PR 归属校验

.claude/
└── launch.json         # 本地开发服务器配置
```

---

## 常见问题

### Q: 后台发布了但前台看不见？

1. **用的「使用本地仓库」模式**：需要在 Chrome/Edge 里打开，选择博客目录并授权写入
2. **开了 editorial_workflow**：文章变成了 PR，需要在 GitHub 合并后才上线
3. **本地没同步**：执行 `git pull origin master`

### Q: 贡献者发布报错「归属校验失败」？

`authors` 字段必须填贡献者自己的 **GitHub 登录名**（不是昵称），且 PR 必须由该账号发起。

编辑贡献者卡片时报错，则是这两处有一处不对：

1. 文件名不是自己的登录名（`content/contributors/<你的用户名>.md`）
2. `GitHub 登录名` 字段（front matter 里的 `github`）和登录名对不上

另外，贡献者只能改**自己的**那张卡片，改别人的会被拒绝。

### Q: 贡献者卡片改完不显示？

先确认 PR 已合并（`editorial_workflow` 下「发布」只是开 PR）。合并后如果还没显示，
检查 `content/contributors/_index.md` 是否被误改——那个文件的 `cascade: build` 是让 Hugo
把它当数据目录、不出页面的，改坏了整个贡献者区都会消失（注意 Hugo 0.145 起键名是
`build`，旧的 `_build` 已失效）。

### Q: 资源页顶部的贡献者卡片不显示了？

新方案依赖 `content/contributors/` 目录。如果这个目录不存在或为空，模板会**回退**去读
`content/resources/_index.md` 的 `contributors` 字段（旧写法）。两者都在就不会有问题。

### Q: CI 构建失败？

1. 检查 `themes/ink` 是否已提交到仓库
2. 检查 GitHub Secrets 是否都配置正确
3. 查看 Actions 日志定位具体错误

### Q: 如何让某人绕过归属校验？

在 `.github/workflows/resource-ownership.yml` 第 18 行的 `MAINTAINERS` 里添加其 GitHub 用户名：

```yaml
MAINTAINERS: "duangx4 another-maintainer"
```

---

## 后续优化建议

1. **Pagefind 搜索**：当前搜索功能 404，可在 CI 里加 `npx pagefind --site public`
2. **评论通知**：贡献者文章有评论时通知到其 GitHub
3. **多语言**：CMS 配置可扩展 i18n 集合
4. **草稿预览**：配置 Netlify/Vercel 预览 PR 分支
