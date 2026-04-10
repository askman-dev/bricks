# Background
用户反馈上一版“移动端对齐”实现不满意，并要求“启用 main worktree，从代码为线索分析功能差异”。当前仓库仅有 `work` 分支，需要先构造可对照的 main 工作树，再进行功能级比对。

# Goals
1. 启用一个可独立检视的 `main` worktree（以变更前基线提交为参照）。
2. 基于代码结构、路由、文案、交互与样式，产出“main vs 当前分支”的功能差异分析。
3. 将分析结果落地为文档，便于后续按项修复。
4. 同步更新代码地图索引，记录新增分析文档入口。

# Implementation Plan (phased)
## Phase 1: 建立对照环境
- 使用 `git worktree add` 创建 `../bricks-main` 对照目录。
- 以当前分支前一提交作为基线（模拟 main），保证差异聚焦于本次 UI 改动。

## Phase 2: 代码线索比对
- 对 `App.tsx`、`ChatPage.tsx`、`SettingsPage.tsx`、`styles.css`、测试文件进行逐项比对。
- 抽取用户可见差异（入口变化、交互行为、视觉参数级别变化）。

## Phase 3: 输出与索引维护
- 新建差异分析文档并给出修复优先级建议。
- 更新 code map 文档索引，纳入本次分析记录。

# Acceptance Criteria
1. 仓库中存在可访问的 `main` worktree 路径记录与基线提交说明。
2. 差异分析文档至少包含：路由壳层、聊天页、设置页、样式策略、测试覆盖五个维度。
3. 分析文档包含可执行的修复优先级建议（P0/P1/P2）。
