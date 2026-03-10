# 代码对比：有无 common.sh 的区别

## 场景：添加一个新的部署脚本

### ❌ 没有 common.sh - 需要复制粘贴大量代码

```bash
#!/usr/bin/env bash
# tools/deploy.sh

set -e

# ========================================
# 需要复制所有这些代码！
# ========================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    local missing_tools=()

    if ! command_exists flutter; then
        missing_tools+=("flutter")
    else
        print_success "Flutter installed: $(flutter --version | head -n1)"
    fi

    if ! command_exists dart; then
        missing_tools+=("dart")
    else
        print_success "Dart installed: $(dart --version 2>&1 | head -n1)"
    fi

    if ! command_exists melos; then
        if command_exists dart; then
            print_warning "Melos not installed. Installing..."
            dart pub global activate melos
            print_success "Melos installed"
        else
            print_warning "Melos not installed (requires Dart to install)"
        fi
    else
        print_success "Melos installed: $(melos --version 2>&1 || echo 'unknown version')"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                flutter)
                    echo "  - Flutter: https://docs.flutter.dev/get-started/install"
                    ;;
                dart)
                    echo "  - Dart: https://dart.dev/get-dart"
                    ;;
            esac
        done
        return 1
    fi

    echo ""
    return 0
}

# ========================================
# 终于可以开始写实际的部署逻辑了！
# （已经写了 85+ 行重复代码）
# ========================================

deploy_app() {
    print_step "Starting deployment..."

    if ! check_prerequisites; then
        print_error "Prerequisites not met"
        exit 1
    fi

    # 构建应用
    print_step "Building application..."
    ./build.sh --target web
    print_success "Build complete"

    # 部署到服务器
    print_step "Deploying to server..."
    # ... 部署逻辑
    print_success "Deployment complete!"
}

deploy_app "$@"
```

**问题**：
- 📏 100+ 行代码，其中 85+ 行是重复的
- 🔄 如果修复 bug，需要在多个文件中修复
- 🐛 容易出现复制粘贴错误
- ⏰ 浪费时间复制代码而不是写实际功能

---

### ✅ 有 common.sh - 简洁清晰

```bash
#!/usr/bin/env bash
# tools/deploy.sh

set -e

# 引入共享库（1 行代码解决所有验证逻辑！）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 直接开始写实际的部署逻辑
deploy_app() {
    print_step "Starting deployment..."

    # 使用共享的验证函数
    if ! check_prerequisites; then
        print_error "Prerequisites not met"
        exit 1
    fi

    # 构建应用
    print_step "Building application..."
    ./build.sh --target web
    print_success "Build complete"

    # 部署到服务器
    print_step "Deploying to server..."
    # ... 部署逻辑
    print_success "Deployment complete!"
}

deploy_app "$@"
```

**优势**：
- 📏 仅 ~30 行代码（减少 70+ 行）
- ✨ 代码清晰，专注于核心功能
- 🎯 立即可以使用所有验证函数
- 🔧 bug 修复自动应用到所有脚本

---

## 场景：修复一个 Bug

假设我们发现 `check_prerequisites` 函数有个 bug，需要添加对 git 的检查。

### ❌ 没有 common.sh - 需要修改多个文件

```bash
# 需要修改的文件列表：

1. build.sh (修改 check_prerequisites 函数)
2. init_dev_env.sh (修改 check_prerequisites 函数)
3. deploy.sh (修改 check_prerequisites 函数)
4. 还有其他所有脚本...

# 每个文件都需要添加：
if ! command_exists git; then
    missing_tools+=("git")
else
    print_success "Git installed: $(git --version)"
fi
```

**风险**：
- ❌ 可能忘记更新某个脚本
- ❌ 不同文件可能实现不一致
- ❌ 需要多次提交和测试
- ❌ 代码审查需要检查多个文件

### ✅ 有 common.sh - 只需修改一个文件

```bash
# 只需要修改一个文件：tools/common.sh

# 在 check_prerequisites() 函数中添加：
if ! command_exists git; then
    missing_tools+=("git")
else
    print_success "Git installed: $(git --version)"
fi

# 完成！所有使用 common.sh 的脚本自动更新
```

**优势**：
- ✅ 只修改一个文件
- ✅ 所有脚本自动获得更新
- ✅ 一次测试，全部验证
- ✅ 代码审查简单

---

## 代码量对比

### 项目总代码量

**没有 common.sh**：
```
build.sh              318 行 (包含 85 行重复)
init_dev_env.sh       172 行 (包含 85 行重复)
deploy.sh             110 行 (包含 85 行重复)
backup.sh             95 行 (包含 85 行重复)
----------------------------------------
总计：                695 行
重复代码：            340 行 (49%！)
```

**有 common.sh**：
```
tools/common.sh       85 行 (共享)
build.sh              238 行
init_dev_env.sh       92 行
deploy.sh             30 行
backup.sh             15 行
----------------------------------------
总计：                460 行
重复代码：            0 行 (0%)
节省：                235 行代码 (34%)
```

---

## 维护成本对比

### 添加新功能：支持检查 Node.js

**没有 common.sh**：
```
需要修改的文件：4 个
需要修改的行数：4 × 10 = 40 行
需要的测试：4 个脚本 × 2 个测试用例 = 8 个测试
估计时间：30-60 分钟
出错风险：高（可能在某个文件中出错）
```

**有 common.sh**：
```
需要修改的文件：1 个 (common.sh)
需要修改的行数：10 行
需要的测试：1 个函数 × 2 个测试用例 = 2 个测试
估计时间：10-15 分钟
出错风险：低（只有一个实现）
```

**时间节省**：60-75%
**风险降低**：显著

---

## 用户体验对比

### 没有 common.sh - 不一致的输出

```bash
# build.sh 的输出
✓ Flutter installed
✓ Dart installed
[OK] Melos installed

# init_dev_env.sh 的输出（不小心用了不同的符号）
✓ Flutter installed
✓ Dart installed
√ Melos installed

# deploy.sh 的输出（又不同了）
[✓] Flutter installed
[✓] Dart installed
✓ Melos installed
```

**问题**：用户困惑，看起来不专业

### 有 common.sh - 一致的输出

```bash
# 所有脚本的输出都完全一致
✓ Flutter installed
✓ Dart installed
✓ Melos installed
```

**优势**：专业、一致、清晰

---

## 总结对比表

| 特性 | 没有 common.sh | 有 common.sh |
|------|----------------|--------------|
| 代码重复 | 340 行 (49%) | 0 行 (0%) |
| 添加新脚本 | 需要复制 85+ 行 | 只需 1 行 source |
| 修复 Bug | 需要修改多个文件 | 只修改 1 个文件 |
| 测试工作量 | N × 测试用例 | 1 × 测试用例 |
| 维护时间 | 高（多处修改） | 低（单处修改） |
| 一致性 | 难以保证 | 自动保证 |
| 代码审查 | 复杂（多处查看） | 简单（一处查看） |
| 学习曲线 | 简单（但重复） | 简单（更清晰） |

---

## 结论

**common.sh 不是"额外的复杂性"，而是"必要的简化"！**

它让我们：
- ✅ 写更少的代码
- ✅ 减少 bug
- ✅ 更容易维护
- ✅ 保持一致性
- ✅ 节省时间

> 💡 **关键思想**：花 5 分钟创建一个共享库，可以在未来节省数小时的维护时间。
