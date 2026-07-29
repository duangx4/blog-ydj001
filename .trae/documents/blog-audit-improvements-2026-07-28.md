# 博客全面体检与改进计划

**审计日期**：2026-07-28
**审计对象**：ydj001.xyz（Hugo + Blowfish）
**当前状态**：已基本成型（自定义 about / now / projects 布局，字体改造完成，阅读进度条已加），但仍有不少债务。

---

## 现状总览

| 维度 | 评分 | 备注 |
|------|------|------|
| 内容丰富度 | ★★★★☆ | 4 篇博客 + 3 个项目 + about / now / projects 三页 |
| 视觉一致性 | ★★★★☆ | ocean 主题统一，蓝色主调贯穿 |
| 模板自定义 | ★★★★★ | 已重写 about / now / projects 三个 list 模板 |
| 配置整洁度 | ★★☆☆☆ | **有 author 配置重复、缺失文件引用、备份残留** |
| 内容时效性 | ★★★☆☆ | 多处文案仍说"PaperMod"，实际已切 Blowfish |
| 部署安全 | ★★☆☆☆ | **明文密码 + sshpass + git add -A** |
| 无障碍 | ★☆☆☆☆ | `enableA11y = false` |
| 互动能力 | ★☆☆☆☆ | 无评论、无分析 |
| SEO | ★★★☆☆ | 基础有，缺 OG 分享卡、中国平台分享 |

---

## 改进项清单（按优先级 × 实现成本）

### P0 — 必修（错误 / 安全 / 损坏）

#### 1. 部署脚本明文密码
- **文件**：`deploy-blog.ps1:9`
- **问题**：`$password = "z8W!McC~JGK"` 明文存在仓库里
- **修复**：
  1. 改用 SSH 公私钥认证（`~/.ssh/id_ed25519`）
  2. 密码从环境变量或 `secrets.ps1`（加入 .gitignore）读取
  3. 把现有密码从 git 历史中清除（`git filter-repo` 或新建分支重写）
- **成本**：30 分钟

#### 2. 配置文件 author 重复定义
- **文件**：
  - `config/_default/params.toml:28-37`（`[author]` 块，links 是 map 格式）
  - `config/_default/languages.zh-cn.toml:14-23`（`[params.author]` 块，links 是 slice of maps 格式）
- **问题**：Blowfish 新版用顶层 `[author]`，旧版用 `[params.author]`。当前混用，languages 后加载会覆盖 params 的 links，导致 params 的 rss/github/email 配置实际无效
- **修复**：统一为一种：
  - 推荐统一用 `params.toml` 的 `[author]`（新版），把 languages.zh-cn.toml 的 author 整段删掉
  - 链接格式用 slice of maps（让 QR 弹窗逻辑能跑）
- **成本**：15 分钟

#### 3. 缺失的引用文件
- **配置引用但文件不存在**：
  - `params.toml:18` → `defaultBackgroundImage = "/img/background.svg"`（缺失）
  - `params.toml:19` → `defaultFeaturedImage = "/img/featured.svg"`（缺失）
  - `languages.zh-cn.toml:11` → `logo = "img/logo.png"`（缺失）
- **修复**：三选一
  - A. 创建占位 SVG（推荐）—— 用 ocean 主题色简单画一个
  - B. 删掉这些配置项 —— 最干净
- **建议**：先选 A（画占位），后续真要做再替换
- **成本**：20 分钟（画三个 SVG）

#### 4. `author.html` partial 头像缺 `nozoom` 类
- **文件**：`layouts/partials/author.html:24, 40`
- **问题**：文章页底部 / 侧栏的作者头像 `<img>` 仍带 `data-zoom-src`，会被 mediumZoom 缩放（之前主页修过，但这个 partial 漏了）
- **修复**：删除 `data-zoom-src` 属性
- **成本**：5 分钟

---

### P1 — 强烈建议（内容时效性 / UX 短板）

#### 5. 文案"PaperMod"残留（三处）
- **文件**：
  - `content/about/_index.md:28` → "本博客站点 Hugo + PaperMod 搭建"
  - `content/now/_index.md:21` → "Hugo 主题改造（从 PaperMod 切到 Blowfish…）"
  - `content/projects/blog-ydj001/index.md:16, 18` → "Hugo + PaperMod"
- **修复**：统一改为 "Hugo + Blowfish"，并把 now 页的"从 PaperMod 切到 Blowfish"换成下一步计划（多容器编排、SEO、评论等）
- **成本**：10 分钟

#### 6. 备份文件清理
- **文件**：
  - `assets/img/avatar.jpg.bak`
  - `content/about/index.md.bak`
  - `screenshots/2026-07-28/`（之前的截图）
  - `_tools/process_qr.py`（如已无用）
- **修复**：删除
- **成本**：5 分钟

#### 7. 资源重复（同一份资源在两个地方）
- **文件**：
  - `assets/img/avatar.svg` 与 `static/img/avatar.svg`（内容相同）
  - `assets/img/avatar.png` 与 `assets/img/avatar.svg`（三个头像）
  - `assets/img/projects/{blog,frp,mc}-cover.svg` 与 `static/img/projects/{...}-cover.svg`
- **修复**：
  - 决定统一来源（推荐：头像用 `assets/img/avatar.svg`，封面用 `static/img/projects/`，因为封面是装饰资源不需要 Hugo 处理）
  - 删掉 `assets/` 下重复的版本
- **成本**：10 分钟

#### 8. 分享链接缺中国平台
- **文件**：`config/_default/params.toml:83`
- **现状**：`sharingLinks = ["twitter", "reddit", "whatsapp", "telegram", "email"]`（全部境外平台，国内基本用不了）
- **修复**：替换为适合国内用户的组合：
  ```toml
  sharingLinks = ["wechat", "weibo", "qq", "telegram", "email"]
  ```
  （需要确认 Blowfish 是否内置了 wechat/weibo/qq 的分享链接模板，否则需要在 `sharing-links.html` 自行实现）
- **成本**：20 分钟

---

### P2 — 锦上添花（功能 / SEO / 无障碍）

#### 9. 无障碍功能开启
- **文件**：`config/_default/params.toml:6`
- **现状**：`enableA11y = false`
- **修复**：改为 `true`（提供键盘导航、跳转链接、对比度增强等）
- **成本**：1 分钟

#### 10. 启用访问分析
- **可选方案**（按偏好选）：
  - **Umami**（推荐）：自部署或用 cloud 版本，国内可访问
  - **GoatCounter**：极简、隐私友好、有免费 hosted 版
  - **Plausible**：付费，但最干净
- **接入方式**：Blowfish 内置 umami.html partial，配置 `[params.analytics.umami]` 即可
- **成本**：15 分钟（含注册/部署）

#### 11. 接入评论系统
- **推荐方案**：Giscus（基于 GitHub Discussions，国内可访问）
  - 启用 `enableComments = true` + `giscus` 配置
  - 或 Twikoo（自部署 Vercel + MongoDB，国内访问良好）
- **成本**：30 分钟

#### 12. OG 分享卡优化
- **现状**：只配置了 `defaultSocialImage = "img/avatar.png"`，无分享卡专用图
- **建议**：做一张 1200×630 的 SVG/PNG 分享卡，包含：
  - 标题（动态渲染站点名或文章标题）
  - 副标题
  - 头像
  - 域名水印
- **文件**：
  - `static/img/og-default.png`（默认）
  - 可选 `layouts/partials/extend-head.html` 增加自定义 OG meta
- **成本**：1 小时（含设计）

#### 13. 移动端体验打磨
- 检查项：
  - 主页 profile 头像 144px 在小屏是否合适
  - 技能卡 3 列在 tablet 是否降为 2 列
  - 项目卡 3 列在 mobile 是否降为 1 列
  - 阅读进度条是否遮挡 header
- **成本**：30 分钟

#### 14. `sitemap` 提交与验证
- 配置 `robots.txt`（Hugo 已自动生成，但可自定义）
- 在 `params.toml` 的 `[seo]` 段加 `publisher` 信息（Google Search Console 验证）
- **成本**：15 分钟

---

### P3 — 长期优化（工程化 / 性能）

#### 15. 部署脚本工程化
- **当前问题**：
  - `rm -rf` 太暴力
  - `sshpass` 已废弃
  - `git add -A` 风险
  - 无错误回滚
- **建议重构**：
  - 改用 `rsync --delete` 增量同步
  - SSH 密钥认证
  - 部署前 git status 检查
  - 失败时回滚
  - 可选：CI/CD（GitHub Actions 推送到 VPS）
- **成本**：2 小时

#### 16. GitHub Actions 自动化部署
- 用 `.github/workflows/deploy.yml` 监听 `main` 分支 push，自动 build + rsync 到服务器
- 优点：每次 push 自动发布，部署脚本不入仓库
- **成本**：1 小时

#### 17. 内容工作流
- 新增博客的 archetype 模板（含 author、tags、cover 默认）
- `archetypes/blog.md` 已存在 (`default.md`)，可细化：
  - 自动填充 `weight`
  - 提醒加 cover 图
  - 提醒加 description（用于 SEO/分享卡）
- **成本**：15 分钟

#### 18. 项目卡 alt 文本修正
- **文件**：`layouts/projects/list.html:91`
- **问题**：`alt="{{ $.Title }}"`（"项目"），应该是项目自身的标题
- **修复**：`alt="{{ .Title }}"`
- **成本**：1 分钟

#### 19. Now 页日期标签色彩统一
- **文件**：`layouts/now/list.html:23`
- **现状**：写死 `color: rgb(14, 165, 233)`，其他位置用 `text-primary-*` Tailwind 类
- **修复**：改用 Tailwind 类
- **成本**：5 分钟

#### 20. QR 弹窗暗色/亮色适配
- **文件**：`layouts/partials/author-links.html:44`
- **现状**：`background: rgba(var(--color-neutral-800), 0.95)`（在亮色模式下可能显得太深）
- **修复**：用 `@media (prefers-color-scheme: light)` 适配
- **成本**：10 分钟

---

### P4 — 内容扩展（按需）

#### 21. `/uses` 页（工具/装备）
- 推荐页：编辑器、键盘、主机、耳机等
- Hugo 生态常见做法
- **成本**：1 小时（含照片）

#### 22. `/bookmarks` 或 `/links` 友链页
- 收集常逛的博客/工具
- 简单 list 布局
- **成本**：30 分钟

#### 23. RSS 全文输出
- 当前 `outputs.home = ["HTML", "RSS", "JSON"]`，RSS 已有
- 增强：每篇文章用 `<description>` + 全文
- **成本**：15 分钟

#### 24. 404 页美化
- Blowfish 自带 404，可重写为带搜索框 + 回到首页的版本
- **成本**：20 分钟

#### 25. 文章页脚"下一篇"卡片化
- 当前 `invertPagination = false`，可改 `true` 让翻页变成"上一条 / 下一条"卡片
- **成本**：5 分钟（仅改配置）

---

## 推荐执行顺序

| 阶段 | 项 | 预计耗时 |
|------|----|----------|
| **第一波**（30 分钟） | 4, 5, 6, 7, 9, 18 | 30 分钟 |
| **第二波**（2 小时） | 1, 2, 3, 8, 19, 20 | 2 小时 |
| **第三波**（3 小时） | 10, 11, 12, 13, 14, 15 | 3 小时 |
| **长期** | 16, 17, 21, 22, 23, 24, 25 | 5+ 小时 |

---

## 验证清单

每完成一批，跑以下检查：

```bash
# 本地构建
hugo --minify

# 检查 404 / 死链
hugo --gc --minify

# Lighthouse 评分（部署后跑）
# - Performance > 90
# - Accessibility > 95
# - Best Practices > 95
# - SEO > 95
```

---

## 假设与决策

1. **不重写框架**：当前 Hugo + Blowfish 选型合理，不建议换 Astro
2. **不删除 blowfish theme 目录**：那是 Hugo module 管理的，不能删
3. **优先 P0/P1**：P2/P3/P4 都是锦上添花，看精力推进
4. **保留 custom.css 的字体改造**：上一轮做的字体改动是有价值的
5. **关于页已经改过**：本计划不再动 about / now / projects 的视觉
