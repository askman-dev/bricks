# Background
用户反馈侧边栏展开后，导航内容在竖直方向看起来偏中间，不符合“顶部对齐”的预期。当前 `ChatNavigationPage` 使用 `DrawerHeader`，其默认高度与底部对齐文本会造成顶部留白。

# Goals
- 让侧边栏展开后可见内容从顶部开始布局。
- 保持现有导航项与交互行为不变。
- 通过现有 Flutter 测试验证无回归。

# Implementation Plan (phased)
1. Inspect
   - 检查 `ChatNavigationPage` 的布局结构，定位导致顶部大留白的组件。
2. Implement
   - 将默认高度较大的 `DrawerHeader` 替换为更紧凑的顶部标题容器（或调整其布局），确保列表内容从顶部开始。
3. Validate
   - 运行仓库初始化脚本。
   - 在移动端包目录运行相关 Flutter 测试，确认导航项文本与交互测试通过。

# Acceptance Criteria
- 打开 Drawer 后，顶部不会出现不必要的大面积空白，导航内容视觉上从顶部开始。
- `Current Chat`、`Sessions`、`Manage Agents`、`Settings` 仍然可见并保持原有行为。
- 相关 Flutter 测试通过（例如 `chat_navigation_page_test.dart`）。
