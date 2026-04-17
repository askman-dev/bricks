# Background

用户希望移除聊天页顶部的调试 `Chip`（Channel/子区/Session/Mode/Cursor/Seq）行，避免占用对话主视图空间；同时希望在输入框左下角菜单中新增“信息”入口，点击后以模态窗口展示同一批调试信息。

# Goals

1. 从聊天主界面移除顶部调试 context bar。
2. 在 Composer 菜单增加“信息”动作项。
3. 点击“信息”后弹出模态，展示当前 scope 与同步诊断信息。
4. 不区分环境（开发/生产一致可见菜单入口）。

# Implementation Plan (phased)

## Phase 1 - Composer 菜单扩展

- 在 `ComposerMenuAction` 中新增 `info` 枚举值。
- 在菜单项中新增“信息”按钮。
- 为 `ComposerBar` 增加 `onShowInfo` 回调并在点击后触发。

## Phase 2 - ChatScreen 调整

- 移除 `ChatScreen` 中顶部 `_buildContextBar()` 渲染入口。
- 在 `ChatScreen` 增加 `_showDebugInfoDialog()`，将原 context bar 展示的关键字段以弹窗内容呈现。
- 通过 `ComposerBar(onShowInfo: ...)` 连接入口与弹窗。

## Phase 3 - 校验

- 运行 Flutter 测试，确认编译与行为未回归。

# Acceptance Criteria

1. 聊天页不再显示顶部 Channel/子区/Session/Mode/Cursor/Seq 标签行。
2. 输入框左下角菜单出现“信息”项。
3. 点击“信息”会弹出模态窗口，并展示当前 Channel、子区、Session、Mode、Cursor、Seq。
4. 变更后项目测试可通过（至少执行移动端 Flutter tests）。
