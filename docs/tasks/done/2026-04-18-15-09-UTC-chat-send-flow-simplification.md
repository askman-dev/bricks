# Background
- 上一版修复通过 messageId 解决了异步回包写错行的问题，但 `_sendMessage` 内重复定位/更新代码较多，可读性一般。
- 需求强调“更优雅、可减少代码量”，希望在保证正确性的前提下进一步简化逻辑。

# Goals
- 保持“按 messageId 定位更新”这一正确性保障不变。
- 精简 `_sendMessage` 的分支重复逻辑，减少样板代码。
- 让 user/assistant messageId 来源更直接，避免通过“append 后再取 index”读取。

# Implementation Plan (phased)
1. 抽象公共更新逻辑
   - 增加按 messageId 更新消息的统一 helper，封装 index 查找与 setState 写回。
2. 简化发送路径
   - 在 append 之前直接生成 user/assistant messageId 并写入消息对象。
   - `respond`、缺 token、失败路径统一调用 helper，减少重复代码。
3. 验证
   - 运行 `./tools/init_dev_env.sh`。
   - 运行 `cd apps/mobile_chat_app && flutter test`。
   - 检查代码地图是否需更新；若无需更新，在最终说明给出理由。

# Acceptance Criteria
- 与上一版一致：不会因 sync/sort 导致 AI 回包写入错误消息。
- `_sendMessage` 中消息更新逻辑比上一版更集中、更少重复。
- 测试可通过，且无新的回归行为。
