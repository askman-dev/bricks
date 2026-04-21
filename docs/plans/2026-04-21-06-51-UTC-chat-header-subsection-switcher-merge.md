# Chat header subsection switcher merge plan

## Background
- 当前聊天页面将子区切换器放在右上角 actions，标题区域独立显示频道名与 router 小字。
- 需求要求把子区切换与标题合并：标题后可下拉切换子区，切换后标题区域即时更新。
- 同时移除标题区域中的 router 第二行小字，并在右侧保留子区控制菜单（改名/存档暂不实现）。

## Goals
1. 将子区切换入口移动到左侧标题区域，与频道标题形成同一组件。
2. 标题区域不再显示 router 信息小字。
3. 在右上角提供子区控制下拉菜单，包含“分区改名（未实现）”“分区存档（未实现）”。
4. 保持现有主区/子区切换与历史加载行为不回退。

## Implementation Plan (phased)
### Phase 1: Header structure refactor
- 重构 `AppBar.title`，将频道标题与子区下拉按钮组合为一行组件。
- 下拉菜单保留“回到主区”“新建子区”与动态子区列表，用于直接切换。
- 抽取切换逻辑为独立方法，避免与 actions 中逻辑重复。

### Phase 2: Right-side subsection controls
- 将原右上角切换菜单改为“子区管理”菜单。
- 菜单包含“分区改名（未实现）”“分区存档（未实现）”，并以禁用态呈现。

### Phase 3: Cleanup and validation
- 删除未再使用的 router summary 文本逻辑。
- 运行 Flutter 测试/检查验证聊天页构建与交互不报错。
- 根据变更同步检查并更新代码地图文件。

## Acceptance Criteria
- 用户在标题右侧下拉可切换主区/子区；切换后标题中的子区文案变化正确。
- 标题区域不再出现 `Router: ...` 小字。
- 右上角存在子区控制菜单，显示“分区改名（未实现）”“分区存档（未实现）”。
- 现有聊天页面测试在当前仓库环境可通过（如 `cd apps/mobile_chat_app && flutter test test/app_test.dart`）。
