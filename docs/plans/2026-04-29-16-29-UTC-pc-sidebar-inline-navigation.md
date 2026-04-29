# Background
当前 `ChatScreen` 在 PC/宽屏下点击左上角 navigation 按钮会打开 `Drawer` 浮层。需求是仅修改 PC 行为：打开后显示为常驻左侧边栏，并与右侧对话区并存；折叠后恢复隐藏。移动端行为保持不变。

# Goals
- 仅在宽屏（非 compact）下把 navigation 改为“内联侧边栏 + 右侧聊天区”的并存布局。
- 保持移动端 `Drawer` 交互不变。
- 保持原有 `ChatNavigationPage` 功能与主题样式一致。

# Implementation Plan (phased)
1. 在 `ChatScreen` 新增桌面侧边栏展开状态（默认折叠）。
2. 提取侧边导航内容构建函数，避免 `Drawer` 与桌面内联侧边栏重复实现。
3. 构建响应式布局：
   - mobile/compact：继续使用 `Scaffold.drawer` + `openDrawer()`。
   - desktop/non-compact：`Scaffold.body` 使用 `Row`，左侧按状态显示固定宽度导航，右侧 `Expanded` 承载聊天区域。
4. 更新代码地图中 chat_session 的 smoke check/关键词，补充“宽屏侧边栏内联并存”行为。

# Acceptance Criteria
- 在宽屏下点击导航按钮后，左侧导航以内联侧边栏形式出现，聊天区被挤到右侧并继续可用。
- 在宽屏下再次点击导航按钮后，左侧导航隐藏。
- 在移动端下导航仍通过抽屉浮层打开，不受本次改动影响。

# Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
