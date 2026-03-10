# Issue #11 需求目标分析 / Objectives Analysis

**Issue**: [#11 - Verify Bricks AI request path with Anthropic and Gemini environment configs](https://github.com/askman-dev/bricks/issues/11)
**Analyst**: Claude Code Agent
**Date**: 2026-03-10

---

## 核心目标 / Core Objectives

### 主要目标 / Primary Goal

验证 Bricks 项目能够通过环境变量配置，成功与两个不同的 AI 提供商（Anthropic 和 Gemini）建立请求通路，并接收到有效响应。

**Verify that the Bricks project can successfully establish request paths to two different AI providers (Anthropic and Gemini) through environment variable configuration and receive valid responses.**

### 关键成功标准 / Key Success Criteria

1. ✅ **配置加载能力 / Configuration Loading**
   - 从环境变量中读取 Anthropic 配置（`TEST_ANTHROPIC_BASE_URL` 和 **规范名称** `TEST_ANTHROPIC_API_KEY`；`TEST_ANTHROPIC_AUTH_TOKEN` 仅作为向后兼容的**弃用别名**，行为应在实现与文档中保持一致并标注迁移计划）
   - 从环境变量中读取 Gemini 配置（例如 `TEST_GEMINI_BASE_URL` 和 `TEST_GEMINI_API_KEY`）
   - 配置缺失时提供清晰的错误信息（包括在同时设置 `TEST_ANTHROPIC_API_KEY` 与 `TEST_ANTHROPIC_AUTH_TOKEN` 时的优先级与警告策略）

2. ✅ **请求构建能力 / Request Construction**
   - 为 Anthropic API 构建符合规范的请求负载
   - 为 Gemini API 构建符合规范的请求负载
   - 支持基本的文本提示（prompt）请求

3. ✅ **通信能力 / Communication**
   - 成功向 Anthropic 兼容端点发送 HTTP 请求
   - 成功向 Gemini 端点发送 HTTP 请求
   - 处理 HTTP 响应并解析结果

4. ✅ **响应验证能力 / Response Validation**
   - 接收并解析 Anthropic 返回的输出
   - 接收并解析 Gemini 返回的输出
   - 验证响应内容非空且符合预期格式

5. ✅ **错误处理能力 / Error Handling**
   - 识别并报告网络错误
   - 识别并报告认证错误
   - 提供可读的错误消息，不泄露敏感信息

6. ✅ **CI 集成能力 / CI Integration**
   - 在 CI 环境中自动执行验证测试
   - 使用 GitHub Secrets 安全管理 API 密钥
   - 测试失败时能够明确指示问题所在

---

## 需求定位 / Requirement Positioning

### 这是什么 / What This Is

**请求路径验证（Request Path Verification）**

- 一个**最小化的端到端验证**流程
- 聚焦于**基础通信机制**的正确性
- 为后续的抽象层建设**打下基础**

### 这不是什么 / What This Is NOT

**完整的提供商抽象层（Full Provider Abstraction）**

明确**不包括**以下内容：
- ❌ 统一的 `AiProvider` 抽象接口
- ❌ Agent 运行时逻辑
- ❌ 工具调用（Tool calling）
- ❌ 流式传输（Streaming）
- ❌ 重试机制、降级策略、中间件
- ❌ UI 集成

---

## 价值主张 / Value Proposition

### 为什么需要这个验证 / Why This Verification Matters

1. **风险降低 / Risk Reduction**
   - 在投入构建完整抽象层之前，先验证基础通信可行性
   - 及早发现配置、网络、认证等基础设施问题
   - 避免在错误的假设上构建复杂架构

2. **快速反馈 / Fast Feedback**
   - 提供简单直接的验证工具
   - CI 自动化检查，快速发现回归问题
   - 开发者可以快速验证配置是否正确

3. **渐进式开发 / Incremental Development**
   - 采用小步快跑的方式，逐步建设能力
   - 先验证基础，再构建抽象
   - 每一步都有明确的验收标准

4. **文档化决策 / Documented Decisions**
   - 明确记录两个提供商的 API 差异
   - 为后续抽象层设计提供实际经验
   - 建立测试基准线

---

## 技术范围 / Technical Scope

### 需要实现的组件 / Components to Implement

```
packages/bricks_ai_smoke_test/
├── lib/
│   ├── src/
│   │   ├── provider_env_config.dart       # 环境变量配置读取
│   │   ├── anthropic_smoke_client.dart    # Anthropic 请求客户端
│   │   ├── gemini_smoke_client.dart       # Gemini 请求客户端
│   │   ├── smoke_result.dart              # 结果数据结构
│   │   └── provider_smoke_runner.dart     # 测试运行器
│   └── bricks_ai_smoke_test.dart          # 包导出
├── test/
│   ├── config_loading_test.dart           # 配置加载测试
│   ├── request_verification_test.dart     # 请求验证测试
│   └── failure_handling_test.dart         # 失败处理测试
└── pubspec.yaml
```

### 核心数据结构 / Core Data Structures

#### 配置类型 / Configuration Types

```dart
// Anthropic 配置
class AnthropicEnvConfig {
  final Uri baseUrl;
  final String apiKey;
  final String model;  // 可暂时硬编码默认值
}

// Gemini 配置
class GeminiEnvConfig {
  final Uri baseUrl;
  final String apiKey;
  final String model;  // 可暂时硬编码默认值
}
```

#### 结果类型 / Result Types

```dart
// 验证结果
class ProviderSmokeResult {
  final String provider;        // 提供商名称
  final bool success;            // 是否成功
  final int? statusCode;         // HTTP 状态码
  final String? outputText;      // 返回的文本内容
  final String? errorMessage;    // 错误消息（如果失败）
}
```

### 环境变量规范 / Environment Variables

#### Anthropic 配置
- `TEST_ANTHROPIC_BASE_URL`: API 基础 URL
- `TEST_ANTHROPIC_API_KEY`: API 密钥（敏感信息，部分历史讨论/CI 配置中曾使用旧名 `TEST_ANTHROPIC_AUTH_TOKEN`，推荐统一迁移为本变量名）

#### Gemini 配置
- `TEST_GEMINI_BASE_URL`: API 基础 URL
- `TEST_GEMINI_API_KEY`: API 密钥（敏感信息）

**注意**: 根据评审建议，统一使用 `TEST_` 前缀以表明这是测试/验证用途；Anthropic 凭证的规范变量名为 `TEST_ANTHROPIC_API_KEY`，如现有 CI 中仍保留旧变量 `TEST_ANTHROPIC_AUTH_TOKEN`，应在迁移时予以明确说明或同步更新。

---

## 验证策略 / Verification Strategy

### 测试方法 / Testing Approach

#### 第一组：配置验证 / Configuration Validation
- 验证环境变量能够正确读取
- 验证缺失配置时能够明确报错
- 验证配置格式校验（如 URL 格式）

#### 第二组：请求验证 / Request Validation
- 发送最小化提示词到 Anthropic
- 发送最小化提示词到 Gemini
- 验证返回内容非空
- 验证返回内容符合预期（精确匹配或包含预期文本）

#### 第三组：失败处理 / Failure Handling
- 验证认证失败时的错误消息
- 验证网络错误时的错误消息
- 确保不泄露敏感信息（API 密钥等）

### 验证提示词 / Validation Prompts

**Anthropic 测试提示**:
```
Reply with exactly: anthropic-ok
```

**Gemini 测试提示**:
```
Reply with exactly: gemini-ok
```

这种简单明确的提示词便于验证：
- 模型是否能够理解指令
- 响应是否可以正确解析
- 通信路径是否完整

---

## 实施优先级 / Implementation Priority

### 关键决策（必须解决）/ Critical Decisions (Must Resolve)

1. ✅ **环境变量命名统一**
   - 决定：使用 `TEST_` 前缀
   - 原因：明确表明这是测试/验证用途，与生产配置区分

2. ✅ **包结构确定**
   - 决定：创建独立包 `packages/bricks_ai_smoke_test/`
   - 原因：清晰隔离验证逻辑，可独立运行，符合 monorepo 结构

### 重要补充（应该添加）/ Important Additions (Should Add)

3. ✅ **默认模型指定**
   - Anthropic: `claude-3-haiku-20240307`（快速、便宜、可靠）
   - Gemini: `gemini-1.5-flash`（快速、便宜、可靠）

4. ✅ **HTTP 客户端选择**
   - 使用 `package:http`（Dart 官方维护的常用 HTTP 客户端包）

5. ✅ **响应格式文档**
   - 记录 Anthropic Messages API 的响应结构
   - 记录 Gemini API 的响应结构

6. ✅ **错误分类策略**
   - 网络错误、认证错误、限流错误、服务器错误、格式错误

7. ✅ **超时配置**
   - 请求超时：30 秒
   - 连接超时：10 秒

### 可选改进（锦上添花）/ Optional Improvements (Nice to Have)

8. ⚪ 测试匹配策略细化（精确匹配 vs 包含匹配）
9. ⚪ 详细的日志安全指南
10. ⚪ CI 工作流具体规格
11. ⚪ API 端点文档
12. ⚪ 配置验证测试用例扩展

---

## 成功的定义 / Definition of Success

### 技术验收标准 / Technical Acceptance

✅ **当以下条件全部满足时，该需求即为完成：**

1. 代码能够从环境变量读取 Anthropic 配置
2. 代码能够从环境变量读取 Gemini 配置
3. 能够成功调用 Anthropic 兼容端点
4. 能够成功调用 Gemini 端点
5. 两个路径都能返回可解析的非空输出
6. CI 能够使用注入的环境变量运行这些检查
7. 失败时能够提供可读的错误消息
8. 日志中不打印敏感信息（API 密钥等）

### 业务价值实现 / Business Value Realized

✅ **完成后的价值体现：**

- **基础通信机制已验证**: 可以确信 Bricks 能够与这两个主流 AI 提供商通信
- **风险降低**: 在构建复杂抽象前，验证了基础假设
- **自动化保障**: CI 集成确保配置变更不会破坏通信能力
- **下一步准备**: 为构建统一的 AI 提供商抽象层奠定基础

### 后续路径 / Next Steps After Completion

完成此需求后，项目可以进入下一阶段：

1. **Phase 2**: 引入 `bricks_ai_core` 提供商中立抽象
2. **Phase 3**: 将 Anthropic 路径包装为第一个提供商适配器
3. **Phase 4**: 将 Gemini 路径包装为第二个提供商适配器
4. **Phase 5**: 使用统一的一致性测试替换直接的烟雾测试客户端

---

## 架构对齐 / Architecture Alignment

### 与现有架构的一致性 / Consistency with Existing Architecture

✅ **符合 Monorepo 结构**
- 新包位于 `packages/` 目录下
- 遵循 snake_case 命名约定
- 可独立构建和测试

✅ **保持独立性**
- 不依赖 `agent_core`（因为这是预抽象验证）
- 不引入不必要的依赖
- 简单直接的实现

✅ **为未来抽象做准备**
- 验证结果数据结构可以轻松映射到未来的抽象接口
- 识别两个提供商的差异，为抽象设计提供输入
- 建立测试基准，可转换为一致性测试

### 安全考量 / Security Considerations

🔒 **敏感信息管理**
- API 密钥存储在 GitHub Secrets 中
- 环境变量在运行时注入，不提交到代码库
- 日志中屏蔽敏感信息（密钥只显示 `sk-...xyz` 或 `***`）

🔒 **输入验证**
- 验证 URL 格式
- 验证 API 密钥非空
- 在日志中使用前对所有输入进行清理

---

## 预估工作量 / Estimated Effort

根据评审文档的估算：

| 任务 | 时间估算 |
|------|---------|
| 包设置 | 1-2 小时 |
| 配置加载 | 2-3 小时 |
| Anthropic 客户端 | 3-4 小时 |
| Gemini 客户端 | 3-4 小时 |
| 错误处理 | 2-3 小时 |
| 测试 | 4-6 小时 |
| CI 集成 | 2-3 小时 |
| 文档 | 1-2 小时 |
| **总计** | **18-27 小时** |

这是一个针对请求路径验证的**合理范围**的单一需求。

---

## 关键洞察 / Key Insights

### 为什么采用渐进式方法 / Why Incremental Approach

1. **降低风险**: 先验证基础，再构建抽象
2. **快速反馈**: 尽早发现配置和集成问题
3. **清晰边界**: 每个阶段有明确的目标和验收标准
4. **经验积累**: 实际使用 API 后再设计抽象，避免过度工程

### 与完整抽象的区别 / Difference from Full Abstraction

| 方面 | 当前需求（烟雾测试） | 未来抽象层 |
|------|---------------------|-----------|
| 目标 | 验证通信可行性 | 提供统一接口 |
| 复杂度 | 最小化实现 | 完整的适配器模式 |
| 灵活性 | 硬编码部分参数 | 完全可配置 |
| 测试 | 端到端验证 | 单元测试 + 集成测试 |
| 用途 | CI 验证 | 生产运行时 |

---

## 总结 / Summary

**Issue #11 的核心本质：**

> 在投入构建完整的 AI 提供商抽象层之前，先用最小化的代码验证 Bricks 能够通过环境变量配置成功与 Anthropic 和 Gemini 两个提供商建立通信，接收有效响应。

**成功标志：**

> 两个提供商都能在 CI 环境中通过环境变量配置，接收到"anthropic-ok"和"gemini-ok"的预期响应。

**价值所在：**

> 为后续的架构抽象工作提供坚实的、经过验证的基础，同时建立自动化的回归测试保障。

---

## 参考文档 / References

- [Issue #11 原始需求](https://github.com/askman-dev/bricks/issues/11)
- [Issue #11 评审文档](./ISSUE_11_REVIEW.md)
- [Repository 架构文档](./docs/architecture.md)
- [Monorepo 结构](./README.md)
