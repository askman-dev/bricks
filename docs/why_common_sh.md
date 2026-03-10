# 为什么需要单独的 common.sh 文件？

## 问题背景

在 Bricks 项目中，我们有多个 shell 脚本：
- `build.sh` - 构建脚本
- `tools/init_dev_env.sh` - 开发环境初始化脚本

这两个脚本都需要执行相似的任务，比如：
- 检查必需工具是否已安装（Flutter、Dart、Melos）
- 显示彩色的输出信息（成功、错误、警告）
- 验证命令是否存在

## 没有 common.sh 的问题

### 问题 1：代码重复（Code Duplication）

如果没有 `common.sh`，每个脚本都需要重复相同的代码：

```bash
# 在 build.sh 中
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
check_prerequisites() {
    # ... 80+ 行代码
}

# 在 init_dev_env.sh 中
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
check_prerequisites() {
    # ... 相同的 80+ 行代码
}
```

**影响**：
- 代码冗余，难以维护
- 两个文件总共 ~160 行重复代码
- 违反 DRY（Don't Repeat Yourself）原则

### 问题 2：维护困难

当需要修改验证逻辑时（比如添加新的检查或修复 bug）：

**没有 common.sh**：
```
需要修改的文件：
1. build.sh (修改检查逻辑)
2. init_dev_env.sh (修改相同的检查逻辑)
3. 未来的 script3.sh (也要修改)
4. 未来的 script4.sh (也要修改)
```

**有 common.sh**：
```
需要修改的文件：
1. tools/common.sh (一次修改)
✓ 所有使用它的脚本自动获得更新
```

**实际案例**：
最近我们修复了一个 bug，build.sh 在 dart 不可用时仍然尝试安装 melos。如果没有 common.sh，我们需要在每个脚本中都修复这个问题。

### 问题 3：不一致性

不同脚本可能会有不同的实现：

```bash
# build.sh 中可能是这样
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# init_dev_env.sh 中可能不小心写成这样
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"  # 不同的符号！
}
```

**结果**：
- 用户体验不一致
- 输出格式混乱
- 难以识别哪些是错误，哪些是成功

### 问题 4：测试困难

没有共享库：
- 需要为每个脚本单独测试相同的功能
- 测试用例重复
- 如果一个脚本的验证逻辑有 bug，其他脚本可能也有

有共享库：
- 只需测试 common.sh 一次
- 所有使用它的脚本都受益
- 确保一致的行为

## 使用 common.sh 的优势

### 优势 1：代码复用（Code Reuse）

**重构前**：
```bash
build.sh:           318 行（包含 ~80 行重复代码）
init_dev_env.sh:    172 行（包含 ~80 行重复代码）
总计：              490 行
```

**重构后**：
```bash
tools/common.sh:    85 行（共享代码）
build.sh:           238 行（减少了 80 行）
init_dev_env.sh:    172 行（重用 common.sh）
总计：              495 行

净效果：代码更清晰，易于维护，未来添加新脚本时节省更多
```

### 优势 2：单一真相来源（Single Source of Truth）

```bash
# 所有脚本都使用相同的验证逻辑
source "${SCRIPT_DIR}/tools/common.sh"

# 使用共享函数
check_prerequisites  # 保证行为一致
print_success "Done!"  # 保证输出格式一致
```

### 优势 3：更容易扩展

添加新脚本时：

**没有 common.sh**：
```bash
#!/usr/bin/env bash
# 新脚本 deploy.sh

# 需要复制粘贴所有助手函数
print_step() { ... }
print_success() { ... }
print_error() { ... }
command_exists() { ... }
check_prerequisites() { ... }
# ... 复制 80+ 行代码

# 然后才能开始写实际逻辑
deploy_app() {
    # 实际的部署逻辑
}
```

**有 common.sh**：
```bash
#!/usr/bin/env bash
# 新脚本 deploy.sh

source "${SCRIPT_DIR}/tools/common.sh"

# 直接开始写实际逻辑！
deploy_app() {
    print_step "Deploying application..."

    if ! check_prerequisites; then
        print_error "Prerequisites not met"
        exit 1
    fi

    # 部署逻辑...
    print_success "Deployment complete!"
}
```

### 优势 4：更好的质量保证

| 方面 | 没有 common.sh | 有 common.sh |
|------|----------------|--------------|
| Bug 修复 | 需要在多处修复 | 修复一次，全部生效 |
| 测试 | 需要重复测试 | 集中测试，覆盖所有用例 |
| 代码审查 | 需要审查重复代码 | 只需审查一次 |
| 一致性 | 难以保证 | 自动保证 |

## 实际使用示例

### 在 build.sh 中

```bash
#!/usr/bin/env bash
set -e

# 1. 引入共享库
source "${SCRIPT_DIR}/tools/common.sh"

# 2. 使用共享函数
_check_prerequisites_build() {
    if ! check_prerequisites; then  # ← 来自 common.sh
        exit 1
    fi
}

clean_build() {
    print_step "Cleaning previous builds..."  # ← 来自 common.sh

    if command_exists melos; then  # ← 来自 common.sh
        melos clean || true
    fi

    print_success "Clean completed"  # ← 来自 common.sh
}
```

### 在 init_dev_env.sh 中

```bash
#!/usr/bin/env bash
set -e

# 1. 引入共享库
source "${SCRIPT_DIR}/common.sh"

# 2. 使用相同的共享函数
setup_flutter_environment() {
    print_step "Setting up Flutter environment..."  # ← 来自 common.sh

    if command_exists flutter; then  # ← 来自 common.sh
        flutter config --enable-web
        print_success "Flutter configured"  # ← 来自 common.sh
    else
        print_error "Flutter is not installed"  # ← 来自 common.sh
        return 1
    fi
}
```

## 设计模式类比

这种模式在软件开发中很常见：

### 类似的概念

1. **共享库（Shared Libraries）**
   - C/C++: `.so` / `.dll` 文件
   - Python: 可重用的模块
   - JavaScript: npm 包

2. **DRY 原则**（Don't Repeat Yourself）
   - 每一个知识点都应该有一个单一、明确、权威的表示

3. **关注点分离**（Separation of Concerns）
   - `common.sh`: 验证和助手函数
   - `build.sh`: 构建相关逻辑
   - `init_dev_env.sh`: 环境设置逻辑

## 未来扩展性

随着项目增长，我们可能需要更多脚本：

```bash
tools/
├── common.sh           # 共享函数库
├── init_dev_env.sh     # 使用 common.sh
├── deploy.sh           # 将使用 common.sh
├── backup.sh           # 将使用 common.sh
└── migrate.sh          # 将使用 common.sh

build.sh                # 使用 common.sh
```

每个新脚本都可以：
- ✓ 立即使用经过测试的验证逻辑
- ✓ 保持一致的用户体验
- ✓ 专注于自己的核心功能
- ✓ 受益于对 common.sh 的任何改进

## 总结

### 为什么需要 common.sh？

1. **避免代码重复** - 将 ~80 行重复代码提取到一个地方
2. **确保一致性** - 所有脚本使用相同的验证和输出逻辑
3. **简化维护** - Bug 修复和改进只需要在一个地方进行
4. **提高可扩展性** - 新脚本可以立即重用所有功能
5. **改善测试** - 集中测试共享功能
6. **更好的用户体验** - 一致的输出格式和行为

### 核心原则

> "每一个知识点都应该有一个单一、明确、权威的表示"
>
> — DRY 原则（The Pragmatic Programmer）

`tools/common.sh` 是我们的"单一、明确、权威"的验证逻辑来源。

### 实际收益

- ✅ 减少维护负担
- ✅ 提高代码质量
- ✅ 加快开发速度
- ✅ 降低 bug 风险
- ✅ 改善用户体验
