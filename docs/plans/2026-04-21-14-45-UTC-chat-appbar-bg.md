# Background
用户希望将对话页面顶部 AppBar 的背景色改为与内容区一致，消除顶部与主体区域的视觉色差。

# Goals
- 让聊天页 AppBar 背景与内容区（Scaffold 背景）保持一致。
- 不改变聊天页现有交互行为与布局结构。

# Implementation Plan (phased)
1. 定位 `chat_screen.dart` 中聊天页 `AppBar` 的定义位置。
2. 为 `AppBar` 显式设置与内容区一致的背景色（基于主题的 `scaffoldBackgroundColor`）。
3. 运行格式化与最小化测试/检查，确认无回归。

# Acceptance Criteria
- 打开聊天页时，顶部 AppBar 背景色与内容区背景色一致。
- 聊天页现有菜单、切换子区、发送消息等功能不受影响。
- `flutter test`（在 `apps/mobile_chat_app` 目录下执行）通过。
