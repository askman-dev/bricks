# Background
用户反馈亮色模式仍存在灰蓝倾向，且与目标视觉不一致。需要依据设计手册（`docs/kb/color-theme-architecture.md`）将亮色模式关键区域调整为中性白/黑体系：页面背景、用户消息气泡、以及“定位到最底部”圆形按钮。

# Goals
1. 亮色模式页面背景去蓝化，改为中性白系。
2. 亮色模式用户气泡改为黑底白字，提升对比度并符合视觉要求。
3. 亮色模式“定位到最新”圆形按钮改为白色系；暗色模式蓝色按钮保持不变。
4. 不引入业务组件内硬编码色值，优先通过 design system token/主题层实现。

# Implementation Plan (phased)
## Phase 1: 主题与语义色调整
- 在 `ChatColors.light` 中调整 `messageUserBackground` 与 `onMessageUser`，实现亮色模式黑底白字气泡。
- 在 `BricksTheme.light()` 明确设置亮色 `scaffoldBackgroundColor` 与 `appBarTheme`，去除由 `colorSchemeSeed` 带来的灰蓝背景倾向。

## Phase 2: 定位按钮亮暗模式分流
- 在消息列表中按 `Theme.brightness` 区分 jump-to-latest 按钮样式：
  - Light: 白色系按钮（白底、深色箭头）。
  - Dark: 保持现有蓝色主色填充按钮。

## Phase 3: 校验
- 运行格式化和 Flutter 分析命令，确保代码风格与静态检查通过。

# Acceptance Criteria
1. 亮色模式聊天页面背景为中性白系，不再呈现灰蓝底感。
2. 亮色模式右侧用户消息气泡呈现黑底白字，时间与状态图标在气泡上清晰可读。
3. 亮色模式 jump-to-latest 按钮呈白色系；暗色模式该按钮继续为蓝色。
4. `cd apps/mobile_chat_app && flutter analyze` 无错误。
