# Channel rename persistence plan

## Background
用户反馈：在频道列表中将频道改名后，刷新页面会恢复为旧名字。当前前端仅在内存中更新频道名，未将改名结果持久化到后端数据库，因此重新加载后无法恢复用户自定义名称。

## Goals
- 让频道改名结果在刷新后保持不变。
- 将频道自定义名称写入数据库并可按用户读取。
- 保持现有频道路由与消息存储行为不变，避免影响聊天主链路。

## Implementation Plan (phased)
1. **Backend schema & service**
   - 新增数据库迁移，创建 `chat_channel_names` 表（按 `user_id + channel_id` 唯一）。
   - 新增后端服务用于查询、写入、删除频道名映射。
2. **Backend API**
   - 在 `/api/chat` 下新增读取/写入频道名接口（`GET /channel-names`、`PUT /channel-names`）。
   - 写入接口支持覆盖更新与删除（传空名或 null 删除）。
3. **Flutter client integration**
   - 在 `ChatHistoryApiService` 增加加载与保存频道名 API 调用。
   - 启动加载时将数据库中的频道名覆盖到已恢复的频道列表。
   - 频道改名时调用保存接口；归档频道时删除该频道名映射。
4. **Tests**
   - 增加/更新 Node backend route tests（新接口行为）。
   - 增加/更新 Flutter service tests（新接口解析与请求体）。
5. **Code map sync**
   - 根据本次行为变更同步更新 `docs/code_maps/feature_map.yaml` 和 `docs/code_maps/logic_map.yaml`。

## Acceptance Criteria
- 用户将非默认频道改名后，刷新页面仍显示新名字。
- 后端数据库存在该用户的频道名映射记录，且重复改名会更新同一条记录。
- 删除/归档频道时可清理对应频道名映射，不影响其他频道。
- `apps/node_backend/src/routes/chat.test.ts` 与 `apps/mobile_chat_app/test/chat_history_api_service_test.dart` 相关测试通过。
