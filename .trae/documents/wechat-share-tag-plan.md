# 微信分享标签（QR 弹窗）实现方案

## 现状分析

**目标**：点击文章底部分享栏的"微信"图标时，弹出微信二维码弹窗（"分享标签"），而不是跳转到一个外部 QR 生成页面。

**当前状态**：

| 区域 | 微信行为 | 实现方式 |
|------|----------|----------|
| 侧栏/关于页头像旁 | ✅ QR 弹窗（hover 显示 `/img/wechat-qr.jpg`） | `author-links.html` 自实现 |
| 文章底部分享栏 | ❌ 跳转到 `api.qrserver.com` 生成文章 URL 的 QR | Blowfish 主题的 `sharing-links.html` |

**根因**：主题自带的 `sharing-links.html`（`themes/blowfish/layouts/partials/sharing-links.html`）对所有分享链接统一 render 为 `<a>` 标签 + URL，没有为 WeChat/QQ 做特殊处理。

**已有资源**：
- `/static/img/wechat-qr.jpg` — 微信二维码图片
- `/static/img/qq-qr.jpg` — QQ 二维码图片
- `author-links.html` 已有成熟的 QR 弹窗 CSS/JS 实现

## 方案

### 核心思路

重写 `layouts/partials/sharing-links.html` 覆盖主题版本，对 `wechat` 和 `qq` 特殊处理为 QR 弹窗，其余平台保持原链接行为。

### 改动文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `layouts/partials/sharing-links.html` | **新增** | 重写分享链接 partial |
| `data/sharing.json` | 不改 | wechat 的 url 保留作为 fallback |
| `i18n/zh-cn.yaml` | 不改 | 已有共享链接翻译 |

### 具体方案

**1. 新增 `layouts/partials/sharing-links.html`**
- 复制 Blowfish 主题原版的逻辑，但增加对 `wechat` 和 `qq` 的特判
- wechat/qq 渲染为一个带 QR 弹窗的容器（div），而非 `<a>` 链接
- QR 弹窗使用 `data-qr="{{ . }}-qr.jpg"` 指向静态图片
- 其他平台（weibo、telegram、email 等）保持和原版完全一样的 `<a>` + URL 行为

**2. QR 弹窗交互逻辑**（复用 author-links.html 的方案）
- CSS：`.qr-wrapper` 容器 + `.qr-popup` 弹窗（绝对定位、hover 显隐、模糊背景）
- JS：mouseenter/mouseleave 控制显隐，桥接层防止边缘闪烁
- 点击不跳转（`href="#" + preventDefault`）

**3. 样式适配**
- 分享栏位于文章底部，QR 弹窗方向向上弹出（`bottom: calc(100% + 12px)`）
- 使用与侧栏一致的视觉风格（圆角、阴影、模糊背板、三角箭头）

### 效果预览

```
[微信图标]  hover →  ╭─────────────╮
                     │  ┌───────┐  │
                     │  │  QR   │  │
                     │  │ 图片  │  │
                     │  └───────┘  │
                     │ 微信扫码联系 │
                     ╰─────────────╯
                         ▲ 三角箭头
```

### 验证步骤

```powershell
hugo --minify
# 启动本地预览后检查：
# 1. 任意文章页底部分享栏 → 微信图标 hover → 弹出 QR
# 2. QQ 图标 hover → 弹出 QQ QR
# 3. 微博/Telegram/Email 点击 → 跳转正常（非弹窗）
# 4. 侧栏 author-links 的 QR 弹窗不受影响
# 5. 鼠标从图标移入弹窗 → 弹窗不消失（桥接层生效）
```

## 假设与决策

1. **微信 QR 图片**：使用现成的 `/static/img/wechat-qr.jpg`，不额外生成
2. **QQ 也做相同处理**：既然结构相同，一并改掉
3. **不修改主题目录**：所有改动在 `layouts/` 项目目录下完成
4. **不依赖外部 CDN**：QR 图片本地托管，无需网络
