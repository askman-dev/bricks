# Background
用户希望在对话输入框左下角的路由切换菜单中加入“模型分组”，展示已配置模型列表；选择模型后应作为默认路由下的模型指定。同时，输入框右侧配置菜单中需要移除“模型”项，并将“信息”入口迁移到右上角更多菜单（与分区相关操作同处）。

# Goals
- 在路由菜单中新增模型分组，并展示当前已配置模型列表。
- 选择模型后更新当前会话模型（等价于默认路由指定模型）。
- 移除 Composer 配置菜单中的“模型”与“信息”项。
- 将“信息”入口放入右上角菜单。
- 保持现有路由设置行为不变，并补充/更新相关测试。

# Implementation Plan (phased)
1. 梳理 `ChatScreen` 中路由菜单与模型状态变量，新增“可选模型条目”构建与选择处理逻辑。
2. 在路由弹出菜单中追加“模型”分组和条目，并以勾选态显示当前选中模型。
3. 调整右上角菜单项，加入“信息”并复用现有 `_showDebugInfoDialog`。
4. 调整 `ComposerBar` 菜单枚举和 UI，删除“模型”“信息”项及其回调。
5. 更新 `composer_bar_test.dart` 对应断言；执行 Flutter 测试验证。
6. 检查并按需更新 `docs/code_maps/feature_map.yaml` 与 `docs/code_maps/logic_map.yaml`。

# Acceptance Criteria
- 路由菜单可看到“模型”分组，且列出来自已加载配置的模型名。
- 在路由菜单选择某个模型后，聊天会话切换到该模型并出现成功提示。
- Composer 菜单不再出现“模型”“信息”。
- 右上角菜单出现“信息”，点击后可打开信息对话框。
- 相关测试通过：`cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart`。
