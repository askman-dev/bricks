# Background
用户要求我继续执行：
1) 实际拿到按时间排序的最后 10 条 Vercel 日志；
2) 总结一套可复用的方法，用于后续前端报错时快速通过日志补充上下文；
3) 将方法沉淀为一个可触发的 skill。

# Goals
1. 使用 `VERCEL_TOKEN` + API 获取 `askman-dev/bricks` 最新部署日志，并按时间倒序提取最后 10 条。
2. 把可复用步骤脚本化，降低重复操作成本。
3. 新增 skill，明确触发条件、标准流程和输出格式，支持后续排障。

# Implementation Plan (phased)
## Phase 1: 拉取最后 10 条日志
- 查询 teamId / projectId / 最新 deployment uid。
- 调用 `GET /v3/deployments/{uid}/events`。
- 用 `jq` 进行 `sort_by(.created) | reverse | .[:10]` 输出。

## Phase 2: 沉淀脚本
- 新增 `tools/vercel/fetch_latest_deployment_logs.sh`，支持参数化 team/project/limit。
- 默认输出最近 10 条，时间字段转成 UTC 字符串。

## Phase 3: 沉淀 skill
- 新增 `.codex/skills/vercel-api-log-context/SKILL.md`。
- 写明前端报错场景下的日志排查流程、关键命令、上下文提取规范。
- 运行 skill 校验工具检查 frontmatter 合法性。

# Acceptance Criteria
- 命令能返回 `askman-dev/bricks` 最新 deployment 的最后 10 条日志（按时间倒序）。
- 新脚本可独立执行并输出结构化 JSON。
- 新 skill 能描述触发条件、操作步骤、产出模板，且通过基础校验。
