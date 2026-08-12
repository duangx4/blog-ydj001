---
title: "OOS 个人工作台：一台只记真实的本地 Agent 工作台"
date: 2026-08-12T11:00:00+08:00
draft: false
tags: ["开发", "个人项目", "Agent", "状态管理", "OOS"]
categories: ["个人项目"]
---

## 缘起：一份不存在的规格

这个项目的起点很荒诞：我拿到一份自称 `oos-builder` 的 SKILL.md（"Release status: 5.1.0"），说装好它就能拥有一个个人 Agent 工作台。但全盘搜索确认——磁盘上根本不存在它的任何组成文件：没有 `.claude/skills/oos-builder/`，没有 `assets/oos-template/`，没有 `scripts/init_oos.js`，6 份 `references/*.md` 也全部失踪。

**结论：95% 的工作量在写 Runtime 本体，不是"安装"。**

于是那份规格被当成验收契约：schema、操作语义、导航约束、排版下限，全部按它来，但实现从零写起。Claude Code 花了数天迭代，最终交付了一个零依赖、无构建、纯本地的个人工作台——OOS（Out-of-Site，"事实出外"）。

## 核心理念：只记真实，绝不代编

OOS 不是日记本，不是待办清单 App，是一台**由真实证据驱动**的个人 Agent 工作台：Tracks 跟踪项目、Plan 排期、Notes 笔记、Review 复盘、Tools 统筹 AI 工具。

它有一条贯穿所有代码的信念：

> **只记真实，绝不代编。"空状态 = 没有证据"，不是进度为零。**

里程碑、截止日期、进度、工时，每一项都必须来自真实日志、真实操作或用户明说。HUD 的"空状态"是诚实的——没有证据就是没有证据，AI 不得为没有证据的东西编一个进度数字。这条规则被写成了操作员的铁律第一条，也被做进了状态机的风险判定。

## 架构总览

```
写路径：CLI oos-state op / HUD submitOps
        → POST /api/state-ops（expectedVersion + clientMutationId + actor）
        → applyOps（Worker 判定风险 → major 需确认）
        → changes.ndjson + consumers.json 落盘
        → SSE state.changed / 5s 轮询 / focus 轮询
        → HUD 重载 state → __derived → 各视图纯函数渲染

读路径：state.json → __derived（读时挂载）→ 视图
```

三个不变式：

1. `__derived` 只在读时挂载，**绝不落盘**（validateState 会报错）
2. `schedule.complete`（关掉"这一次执行"）≠ `task.complete`（关掉"整个任务及其未执行排期块"）——不可互换
3. server 只是 transport，**不拥有持久化**；Worker 拥有（`data/state.json`）

## 状态运行时：把并发和安全做进地基

这是整个项目最硬核的部分。`server/state-runtime.js` 实现了一个带版本控制的原子状态机：

- **乐观并发控制**：每次变更必须带 `expectedVersion`；版本对不上返回 `state_conflict` 409，客户端拿新版本重试
- **幂等**：同 `clientMutationId` 同载荷，返回原回执；同 id 异载荷，报 `mutation_id_reused`（409）——重试永远不会重复执行
- **风险分级**：删除类操作、跨 7 天移动排期、单批触碰 >5 实体、硬窗口冲突、回填 30 天前的度量……这些 major change 返回 `confirmation_required` 428，走确认流。**风险由 Worker 判定，不由 Agent 自说自话**
- **崩溃安全**：每次变更落盘 `changes.ndjson` + 消费者游标 `consumers.json`；掉线的消费者通过 `resyncRequired` 机制自动重载
- **CLI 实例守卫**：`oos-state` 写前探测端口上的实例是否属于本工作区（instanceId 比对），防止误写他人工作区

## Op 契约：40 种操作，一个信封

所有写操作都是 State Op，走同一个信封：`{ ops: [...], expectedVersion, actor, clientMutationId }`。

| 域 | op |
|---|---|
| 任务 | `task.create/update/complete/reopen/delete` |
| 排期 | `schedule.create/move/update/complete/skip/delete` |
| 笔记 | `note.capture/update/link/delete`（capture 立即落库 + 默认生成一条 `capture.review` 队列项） |
| Track | `track.update` · `milestone.*` · `hardwindow.*` · `checkpoint.*` · `stage.*` |
| 度量 | `metric.define/record/correct` · `effort.log`（工时只记真实投入） |
| Worker | `worker.enqueue/resolve`（resolution: applied/dismissed/deferred） |
| 引导 | `review.record` · `firstflight.step/skip` |
| 工具 | `tools.record/privacy` |

其中值得单独说的设计：

- **note.capture 自动入队**：每记一条速记，自动生成 `capture.review` 队列项，请求操作员判断归属——**不是自动分类**，判断依据必须是用户的明说或明确的真实线索。这就是"AI 不替用户做决定"的落地。
- **First Flight 引导**：三步真实上手（capture / stateOp / hudRefresh），先做真实操作再标记步骤，可跳过、可继续，不是阻塞项。

## Plan 排期工作台：一个连续工作面

Plan 不是一堆排期卡片，是一个**连续工作台**：四周概览 + 选中日精确时间线 + 吸底未排期架。

四种拖放语义，统一落在 `scheduleBlocks`：

- 块 → 时间线（15 分钟对齐）
- 块 → 另一日期（保留原时刻）
- 任务 → 日期（自动找 60 分钟空位）
- 任务 → 时间线（精确落位）

几何上有个被测试锁死的契约：时间线 `.tl-surface` 高 840px（1px/分钟，08:00–22:00）+ `margin-left:44px`（小时刻度），`plan.js` 用**实时元素 rect 测量**做 drop 数学，`grabRatio` 作为不可信输入钳制在 [0,1]。**改高会静默脱同步**——这是踩过坑之后的教训，下面会讲。

## 安全契约：凭据永不过手

OOS 有个工具统筹页，会真实扫描 OpenClaw / CC Switch / Codex 的配置。这里的安全设计是红线级的：

- **凭据值永不过手**：只记 `{present, last4, sha256_8}`；endpoint URL 只留 host（query string 可能带 token）
- **绑定白名单字段**构造，parser 想泄 apiKey 也泄不出去
- `cc-switch.db` 经字段级脱敏，apiKey 值不出函数——有 sentinel 测试证明"从未打开凭据文件"
- `readConfigSafely` **直接拒读**凭据文件名（`*key*`/`*token*`/`*secret*`/`*credential*` 等）
- 工具统筹默认 `privacy: 'private'`；"共享"是持续暴露态，要保持醒目

## 踩坑十记（改代码前先看）

1. **`applyOps(input, root)` 把字符串传进 `opts`** → `opts.root` undefined → 静默回退 `WORKSPACE_ROOT`，**测试写进了真实工作区**。已加 `normalizeOpts` + 回归测试
2. **CLI 零覆盖** → `attention` 读 `d.counts.workerPending`，实际字段是 `healthCounts` / `worker.pending`。补了 11 个 CLI 契约测试
3. **`node --check` 抓不到 ESM 具名导出缺失** → 浏览器才报且只报第一个。加 `frontend-modules.test.js` 静态解析模块图，一次性报全
4. **derive.js 读 `m.title`/`cp.title`，ops 建的却是 `label`** → 录真实里程碑就显示 "undefined"，空工作区看不出来。加带真实数据的 derive 测试
5. **server 的外部写监听把自己的写重报一次 "external"** → `lastSeenVersion` 需由 in-process 写也更新
6. **Windows**：`node --test test/` 会被当模块路径，必须 glob（`node --test "test/**/*.test.js"`）；目录 fsync 抛 EPERM 要容错
7. **用户面向文案一律中文**——健康度消息曾整片英文泄漏
8. **`stripSecrets` 启发式误杀结构字段** → `credentialStores` 数组被抹空、`hasCredential` 布尔被抹成 false（字段名含 credential 词被当成凭据 key）。修复：toolsRecord 对结构字段绕过 stripSecrets 走白名单。教训：**真实端到端才走的路径必须有 ops 层测试**
9. **`schedule.create` 原本没有硬窗口规则** → 拖进窗口静默通过、移动却要确认，不对称。已补齐
10. **皮肤 token 不完整** → 一开始 styles.css 用 `--mono`、皮肤用 `--font-mono`，工具页等宽字体被晾在旧主题上。统一 `--font-mono` + 37 token 完整性测试

## 测试体系：155 全绿

```
npm run check   # node --test "test/**/*.test.js"（Windows 必须 glob）
```

覆盖：schema/seed、state-runtime（幂等/冲突/mutation_id_reused）、CLI 11 契约、derive 边界、健康度信号、硬窗口风险、凭据脱敏 sentinel、HUD 重试状态机、前端模块图静态解析、皮肤 37 token 完整性 + 类型下限。

**测试铁律**：测试必须 `--root`/临时工作区，永不写真实 state；`OOS_ROOT` 环境变量可让 HUD 指向任意工作区。

## 皮肤系统：token 驱动

生成 4 套风格展示页让用户挑，最终保留 3 套（nova 星夜 / amber 暖纸 / mint 薄荷）。切换选择存 localStorage（纯展示偏好，**不写 state**——皮肤只是浏览器显示）。styles.css 重写为 token 驱动，37 个必需 token 有测试断言完整性；meta ≥ 11px、body 12–13px、交互控件 ≥ 40px 等类型下限也进了测试。

## 现状与下一步

当前 state v6（schema v3），三个 Track：电气项目 / Agent 基建 / 学习攻坚。业务数据为空——**空状态，不是零进度**。

- **First Flight**：pending 0/3，等真实数据录入（必须来自用户，不得代编）
- **Phase 5（暂缓）**：`memory/decision` ops、`audit`/`migrate` 工具、提升为可复用 template（`init_oos` / `upgrade` / `package`）

## 交接

项目已完成开发并交接给 OpenClaw 担任专职操作员：日常唤醒节奏（meta → attention → changes → worker-list）、六条铁律、40 种 op 参考全部写进了操作员 SOP。OOS 从此是一台有专职操作员的个人工作台——它只记录真实发生过的事，别的什么都不记。
