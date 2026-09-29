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

**字段设计**：
- `title`、`description`、`date`、`lastmod`、`draft`、`weight`
- `authors`：贡献者 GitHub 用户名（用于归属校验）
- `tags`、`categories`
- `cover`：封面图（上传到文章目录）
- `attachments`：附件列表（上传到文章目录）
- `showComments`
- `body`：正文（支持 Markdown + 短代码组件）

### 2. 模板适配

| 文件 | 修改内容 |
|------|----------|
| `layouts/resources/list.html` | 封面图路径解析：优先检查 bundle 内资源，兼容 CMS 上传的相对文件名 |
| `layouts/shortcodes/download-table.html` | 下载按钮支持 bundle 内附件文件名（除了 http/https URL） |

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
{{< pan-link title="百度网盘" url="https://pan.baidu.com/..." code="xxxx" >}}
```

---

## 文件清单

```
static/admin/
├── index.html          # CMS 入口
└── config.yml          # CMS 配置

layouts/
├── resources/list.html # 资源列表（已修改封面路径解析）
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
