# Model Settings 修复与扩展 Plan

## 背景
针对模型配置功能，本轮需要在已有实现基础上补充执行计划（Plan），并明确可验证的验收标准，确保后续迭代可追踪、可回归。

## 目标
1. Google AI Studio 默认模型使用 `gemini-flash-latest`。
2. 保存后刷新不再出现 `Failed to load model settings`。
3. 模型设置页支持 `Config 1 / Config 2 / ...` 的槽位视图。
4. 槽位按钮显示模型名（动态），存储使用稳定唯一 ID（与展示名解耦）。
5. 数据结构可扩展到多槽位。

## 实施计划

### 阶段 1：默认模型与配置读写稳定性
- 将 Google AI Studio 默认模型统一为 `gemini-flash-latest`（前后端一致）。
- `save` 返回服务端持久化对象，前端使用返回结果更新当前状态。
- 强化配置解析（`Map<dynamic, dynamic>` → `Map<String, dynamic>`），避免刷新后因动态类型导致加载失败。

### 阶段 2：槽位化数据模型
- 在配置结构中引入 `slot_id`，作为稳定主键；展示名不参与主键语义。
- 前端 `LlmConfig` 增加 `slotId` 字段，保存时回传 `slot_id`。
- 保留默认配置选择逻辑（`is_default`），确保兼容旧数据。

### 阶段 3：模型设置页交互改造
- 在 Provider 上方新增 `Configs` 行。
- 使用动态按钮文案：优先显示该槽位默认模型名，缺省回退 `Config N`。
- 保留 API key 交互语义：
  - 新建配置必须填写。
  - 已有配置可留空表示保持原 key。

### 阶段 4：回归验证
- Flutter 静态检查通过。
- Node backend 类型检查通过。
- 手工回归：保存后刷新再次进入设置页，配置可正常回显。

## 验收标准（Acceptance Criteria）
1. 当 Provider=Google AI Studio 且为新建配置时，默认模型显示 `gemini-flash-latest`。
2. 用户填写 API key + 模型 ID 后点击保存，提示成功；刷新页面后再次进入设置页，不出现 `Failed to load model settings`。
3. 设置页 Provider 上方可见 Config 行；至少显示一个槽位，文案与该槽位模型名一致（无模型名则显示 `Config 1`）。
4. 存储数据中包含稳定唯一的 `slot_id`，且与按钮展示文案解耦。
5. 当前实现在代码结构上支持多个槽位（列表状态与按槽位切换逻辑），不依赖单一配置对象。
6. 前后端检查通过：
   - `flutter analyze` 无报错。
   - `npm run type-check` 无报错。
