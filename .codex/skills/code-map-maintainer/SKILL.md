---
name: code-map-maintainer
description: Maintain repository code maps (feature_map.yaml and logic_map.yaml) after code changes so testers and AI agents can quickly assess entry paths, logic index, and regression risks.
---

# Code Map Maintainer

## 1) 何时触发
在以下场景优先使用本 skill：
1. 修改了用户可见功能入口（页面、路由、菜单、按钮）。
2. 修改了关键业务逻辑文件或配置索引。
3. 新增/删除了测试或文档，影响功能追踪。
4. 发现 AI 变更可能引入遗留代码或关联功能失效。

## 2) 维护目标文件
- `docs/code_maps/feature_map.yaml`
- `docs/code_maps/logic_map.yaml`

以上统称“代码地图（Code Maps）”。后续新增地图文件时，沿用相同维护流程。

## 3) 维护步骤
1. 从本次 diff 中抽取：
   - 新增/变更的功能入口路径
   - 受影响的核心代码文件
   - 受影响的测试文件与文档
2. 更新 `feature_map.yaml`：
   - 功能名、入口路径、最小 smoke checks
3. 更新 `logic_map.yaml`：
   - `feature_id` 映射
   - `code_index` / `doc_index` / `test_index`
   - `keywords` 与 `change_risks`
4. 做一致性检查：
   - 两个地图中的 `feature_id` 一一对应
   - 索引路径必须存在于仓库中

## 4) 输出要求（提交前）
在最终说明里简要汇报：
1. 哪些 feature_id 被新增/修改/删除。
2. 为什么这些改动会影响回归测试。
3. 推荐测试员优先验证的 smoke checks。

## 5) 推荐校验命令

**Node.js（使用 npx，项目已有 Node.js 环境，无需额外安装）：**
```bash
npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null && echo "code maps yaml ok"
```

**Python（需要 PyYAML）：**
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('docs/code_maps/feature_map.yaml')); yaml.safe_load(open('docs/code_maps/logic_map.yaml')); print('code maps yaml ok')"
```

如环境无法运行上述命令，可直接目视检查缩进与冒号格式，或在说明中标注限制。
