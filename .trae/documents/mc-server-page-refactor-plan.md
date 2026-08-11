# MC 服务器页面重构计划

## 1. Summary

参考 `https://www.iecraft.com/board/teal/`（碧色模板）的视觉语言，重构用户现有的 MC 服务器页面
[mc/index.html](file:///c:/Users/21972/Desktop/blog-ydj001/static/mc/index.html)。

- 保留：实时状态条 + 在线玩家列表（沿用 `https://mc.ydj001.xyz/status` 接口，每 30s 轮询）。
- 重构：青绿色主题（`#0a3a3a / #0d4949 / #2EE5AC`）、Hero 全屏背景、3 列特性卡、统计数字、6 格特色栅格、3 段图文模块、服务器画廊、加入方式 + IP 复制。
- 不做：赞助套餐、合作伙伴模块（用户已确认剔除）。
- 形态：保持 `static/mc/index.html` 独立 HTML 形态，仅替换文件内容；嵌入方式（`mc-server-card.html` iframe）不变。
- 图片：使用 `C:\Users\21972\OneDrive\Desktop\web\新建文件夹 (2)\` 下的 9 张 MC 截图。

## 2. Current State Analysis

### 现有结构（待替换）

[mc/index.html](file:///c:/Users/21972/Desktop/blog-ydj001/static/mc/index.html#L1-L276) — 单文件 276 行：

- 设计：深紫蓝渐变背景 (`#0f0c29 → #302b63 → #24243e`)，橙金强调色 (`#ffd200 / #f7971e`)，玻璃拟态卡片。
- 内容模块：Header（标题+状态条+玩家徽章）→ 服务器信息 2×2 卡片 → 硬件配置栅格 → 服务器特色 6 项 → 模组列表 4 大类 + 弹窗 → 复制 IP CTA → 页脚。
- 状态逻辑：L237-273 `fetchStatus()` 调用 `https://mc.ydj001.xyz/status`，返回 `{online, players_online, max_players, player_list[]}`，30s 轮询。
- 模组列表：4 大类共 33 个 mod，已是「模组清单」数据（与本次新文案"玩法模组"重叠，将精简到只展示轻量级方案亮点）。

### 嵌入方式

[mc-server-card.html](file:///c:/Users/21972/Desktop/blog-ydj001/layouts/shortcodes/mc-server-card.html#L13-L22) 通过 `<iframe src="https://mc.ydj001.xyz">` 嵌入独立 HTML。重构不影响此短代码。

### 参考站设计要点（IEcraft 碧色）

- 配色：深青绿底（`#0a3a3a` 系），亮翠绿强调（`#2EE5AC`），白字主文，灰白副文。
- 字体：粗体大号无衬线（中文 PingFang / 思源黑体粗体）。
- Hero：全屏背景图 + 半透明深色遮罩 + 居中粗体标题（品牌名用青绿色高亮） + 3 按钮（橙/青/青）。
- 三大特性：图标 + 短标题 + 段落 + 链接按钮，3 列布局。
- 数字统计：4 个并列数字 + 小标签，下方 [实时更新] 徽章。
- 6 格特色：图标 + 标题 + 段落，2×3 网格。
- 3 段图文：左右交替（图片+文字），3 个区块。
- 团队卡片：圆形头像 + 角色标签 + 名字 + 入职日期 + 简介。
- 画廊：6 图网格（每图下方小标题），可带 Tab 过滤。
- 页脚：极简 © Powered by。

### 图片素材

`C:\Users\21972\OneDrive\Desktop\web\新建文件夹 (2)\` 共 9 张 PNG（已通过 Read 工具确认全部为 MC 服务器实景截图，含樱花林、麦田、村庄、日式屋等）：

| 文件 | 适合用途 |
|---|---|
| `2026-07-31_02.59.28.png` | Hero 主背景（樱花林与灯笼前景） |
| `2026-07-31_03.00.09.png` | 三大特性区 1（玩家樱花麦田） |
| `2026-07-31_03.01.35.png` | 三大特性区 2（水中灯笼） |
| `2026-07-31_03.02.23.png` | 三大特性区 3（樱花村庄全景） |
| `2026-07-31_06.21.09.png` | 图库：玩家合影 |
| `2026-07-31_06.21.12.png` | 图库：麦田远景 |
| `2026-07-31_06.21.34.png` | 图库：樱花坡 |
| `2026-07-31_06.21.49.png` | 图库：村庄全景 |
| `2026-07-31_06.22.02.png` | 图库：村庄侧景 |

## 3. Proposed Changes

### 改动 1：复制 9 张图片到 `static/mc/img/`

- 路径：`c:\Users\21972\Desktop\blog-ydj001\static\mc\img\`
- 命名：使用语义化英文名（保持 URL 简洁且与现有 `mc-cover.svg` 风格统一）：
  - `hero.jpg` ← `2026-07-31_02.59.28.png`
  - `feature-1.jpg` ← `2026-07-31_03.00.09.png`
  - `feature-2.jpg` ← `2026-07-31_03.01.35.png`
  - `feature-3.jpg` ← `2026-07-31_03.02.23.png`
  - `gallery-1.jpg` ← `2026-07-31_06.21.09.png`
  - `gallery-2.jpg` ← `2026-07-31_06.21.12.png`
  - `gallery-3.jpg` ← `2026-07-31_06.21.34.png`
  - `gallery-4.jpg` ← `2026-07-31_06.21.49.png`
  - `gallery-5.jpg` ← `2026-07-31_06.22.02.png`
- 工具：用 PowerShell 复制 + 重命名（脚本一次性执行）。

### 改动 2：完全重写 `static/mc/index.html`

[mc/index.html](file:///c:/Users/21972/Desktop/blog-ydj001/static/mc/index.html) — 整体替换为新设计，单文件，结构如下：

```
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta>, <title>
  <style>   <!-- 全部内联 CSS，无外部依赖（保持 standalone 特性） -->
</head>
<body>
  <nav class="topbar">          <!-- 顶部透明导航：Logo + 3 个锚点链接 -->
  <section class="hero">        <!-- Hero：全屏 hero.jpg 背景 + 遮罩 + 标题 + 3 按钮 + 状态条 + 玩家徽章 -->
  <section class="features3">   <!-- 三大特性：玩法模组 / 社群文化 / QQ机器人（图+标题+文+按钮） -->
  <section class="stats">       <!-- 4 个统计数字（动态填充在线人数）+ [实时更新] 标签 -->
  <section class="features6">   <!-- 6 格特色：优化体验 / 便捷工具 / 趣味玩法 / 活跃社群 / 互帮互助 / 定期活动 -->
  <section class="showcase">    <!-- 3 段图文：左右交替（玩家玩法/社区氛围/QQ机器人联动） -->
  <section class="gallery">     <!-- 5 图服务器画廊：麦田/樱花/村庄等 -->
  <section class="join">        <!-- 加入我们：地址 + 版本 + QQ群 + IP 复制 -->
  <section class="admin">       <!-- 管理后台：MCSManager 入口 -->
  <footer>                      <!-- © Powered by 实力人老大 -->
  <script>                      <!-- 状态轮询 + IP 复制 + 平滑滚动 -->
</body>
</html>
```

#### 样式系统（迁移到青绿主题）

| 元素 | 现有值 | 新值 |
|---|---|---|
| 背景 | 紫蓝渐变 `#0f0c29 → #24243e` | 深青绿 `#0a3a3a → #0d4f4f` |
| 主强调 | 橙金 `#ffd200 / #f7971e` | 亮翠绿 `#2EE5AC` |
| 次强调 | 同上 | 深翠绿 `#1aaa7d` |
| 文字主色 | `#e0e0e0` | `#e8f5f3` |
| 文字副色 | `#888` | `#88b0ac` |
| 卡片底 | `rgba(255,255,255,.05)` + blur | `rgba(255,255,255,.04)` + blur（保留玻璃拟态） |
| 在线绿 | `#4caf50` | 保持 `#2EE5AC`（与主题统一） |
| 离线红 | `#f44336` | 保持 `#ef5350` |
| 字体栈 | PingFang 系 | 复用 `assets/css/custom.css` 的 Noto Sans SC + LXGW WenKai（通过 CDN `@import` 引入，与站点统一） |

#### 内容映射（用户文案 → 新版块）

| 用户文案 | 落入版块 |
|---|---|
| `# 🎮 YDJ Minecraft 服务器 / 一个属于玩家的创意生存社区` | Hero 标题 + 副标题 |
| `### 🔧 玩法模组` 3 点 | 「三大特性」第 1 卡 + 「6 格特色」前 3 格 |
| `### 👥 社群文化` 3 点 | 「三大特性」第 2 卡 + 「6 格特色」后 3 格 |
| `### 🤖 QQ机器人` 3 点 | 「三大特性」第 3 卡 + 「3 段图文」第 3 段 |
| `## 加入我们` 表格 | 「加入我们」版块 |
| `## 管理后台` 表格 | 「管理后台」版块 |
| `**欢迎来到 YDJ MC 服务器...**` | Hero 副标题 + 页脚 |

#### 状态条与玩家显示（核心保留功能）

- 位置：紧贴 Hero 标题下方，居中。
- 视觉：圆形脉冲点 + 文本（`服务器运行中 · X/Y 人在线`），宽度受容器限制。
- 玩家徽章：原本 `player-badge` 横向排列保留；增加最大高度 + 横向滚动（避免长名单撑破 Hero）。
- 失败回退：保持「状态服务暂不可用，请稍后刷新」文案。
- 轮询：30s 不变。

#### IP 复制按钮

- 沿用现有 `navigator.clipboard.writeText('mc.ydj001.xyz')` 逻辑。
- 按钮样式：青绿底 + 深色文字，hover 提升 + active 缩放（参考现有 `.copy-btn` 动效）。
- 位置：Hero 右下角浮动 + 「加入我们」版块各放一个。

#### 响应式

- 桌面（≥1024px）：3 列、2×3 网格、3 段图文左右交替。
- 平板（768-1023px）：2 列、3 段图文上下堆叠。
- 移动（<768px）：单列、Hero 标题字号从 4.5rem 降至 2.2rem、统计数字 4 列变 2×2。

#### 可访问性

- Hero 背景图加 `aria-hidden="true"`。
- 状态点 `<span>` 配 `role="status" aria-live="polite"` 让屏幕阅读器在状态变化时朗读。
- IP 复制按钮加 `aria-label="复制服务器地址 mc.ydj001.xyz"`。
- 所有图片加 `alt`（中文场景描述）。

### 改动 3：资源优化

- 图片上传到 `static/mc/img/` 后会被 Hugo 视为静态资源直接服务，URL 为 `/mc/img/hero.jpg` 等。
- 不在 Hugo 中处理（无需要 `resources.Get`），保持 standalone 形态。

## 4. Assumptions & Decisions

| 假设 | 说明 |
|---|---|
| `https://mc.ydj001.xyz/status` 接口契约不变 | 返回 `{online, players_online, max_players, player_list[]}` |
| Hero 背景用 `hero.jpg` | 9 张图中最具代表性的"樱花林前景"那张 |
| 不嵌入完整模组清单 | 33 个 mod 列表属于"具体模组列表详见服务器公告"指向，移除弹窗以避免臃肿；保留 3 个轻量级模组亮点即可 |
| 不做暗/亮模式切换 | 整页深色，与 IEcraft 模板风格一致 |
| 不做 SSR | 继续纯静态 HTML，所有交互靠原生 JS |
| iframe 嵌入方式保留 | 项目页 [mc-server-card.html](file:///c:/Users/21972/Desktop/blog-ydj001/layouts/shortcodes/mc-server-card.html) 不动 |
| 9 张图全部利用 | 1 张 Hero + 3 张三大特性 + 5 张画廊（5 而不是 6，IEcraft 用 6 但用户有 5 张可作为"图库"的素材，第 6 格用文字统计卡替代或留空）—— 决定用 5 张图 + 1 个"更多图片敬请期待"占位卡 |

## 5. Verification

1. **本地预览**：
   - `cd c:\Users\21972\Desktop\blog-ydj001 && hugo server -D`
   - 访问 `http://localhost:1313/mc/`
   - 访问 `http://localhost:1313/projects/mc-server/`（验证 iframe 嵌入正常）

2. **状态接口**：
   - 打开浏览器 DevTools → Network，观察 `https://mc.ydj001.xyz/status` 请求每 30s 触发。
   - 模拟离线：在 DevTools 中 block 该请求，验证降级文案「状态服务暂不可用，请稍后刷新」出现。

3. **交互**：
   - 点击「复制服务器地址」→ toast/按钮文案切换为「✅ 已复制！」。
   - 点击顶部导航锚点 → 平滑滚动到对应版块。

4. **响应式**：
   - Chrome DevTools 切换至 iPhone 12 / iPad / 桌面 1440px 三档，截图比对布局无破版。

5. **跨域**：
   - 确认 `fetch('https://mc.ydj001.xyz/status')` 仍能正常返回（服务器 CORS 应已放开）。

6. **视觉对比**：
   - 截图新页面与 IEcraft 原站，并排比对配色、版块顺序、按钮风格一致性。

7. **构建**：
   - `hugo` 静态构建无报错，生成的 `public/mc/index.html` 包含所有新模块。
