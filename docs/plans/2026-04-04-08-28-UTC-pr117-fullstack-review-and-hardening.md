# Background
用户要求基于 PR #117 的需求做一次从需求到实现的全栈审查（后端、架构、数据库、客户端），并把不合理实现做实质修正。

# Goals
1. 形成一份可执行的全栈审查结论（需求、后端、架构、数据库、客户端）。
2. 修复本轮实现中的关键技术债：仲裁打分逻辑不能依赖伪随机/字符串哈希。
3. 保持当前代码可运行并通过现有测试。

# Implementation Plan (phased)
## Phase 1: 评审产物
- 新增全栈审查文档，按层次列出现状、风险、已修复项、待办项。

## Phase 2: 代码硬化
- 将 `ChatArbitrationEngine` 从“botId 派生分数”改为“参与者概率权重”打分。
- 更新 ChatScreen 调用契约与测试用例。

## Phase 3: 验证
- 执行格式化与 `flutter test`，确保修改不会破坏现有行为。

# Acceptance Criteria
- 审查文档覆盖需求、后端、架构、数据库、客户端五个维度。
- 仲裁引擎不再使用 botId 推导分数。
- `flutter test` 全量通过。
