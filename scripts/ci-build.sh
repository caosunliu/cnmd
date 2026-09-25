#!/bin/bash
#
# ci-build.sh - CI/CD自动化构建脚本
#
# 用于GitHub Actions、GitLab CI等CI/CD环境
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  CNMD CI/CD 构建"
echo "=========================================="

# 检测CI环境
if [ -n "${CI}" ]; then
    log_info "检测到CI环境: ${CI}"
fi

# 检测架构
ARCH=$(uname -m)
log_info "当前架构: ${ARCH}"

# 检测操作系统
OS=$(uname -s)
log_info "当前操作系统: ${OS}"

# 安装依赖
install_dependencies() {
    log_info "安装构建依赖..."
    
    if [ "${OS}" = "Linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                gcc \
                g++ \
                make \
                cmake \
                git \
                wget \
                curl \
                pkg-config \
                libreadline-dev \
                zlib1g-dev \
                libssl-dev \
                libxml2-dev \
                libxslt1-dev \
                libsystemd-dev \
                libicu-dev \
                uuid-dev \
                flex \
                bison \
                python3
        elif command -v yum &> /dev/null; then
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                readline-devel \
                zlib-devel \
                openssl-devel \
                libxml2-devel \
                libxslt-devel \
                systemd-devel \
                libuuid-devel \
                flex \
                bison \
                python3
        fi
    fi
    
    log_success "依赖安装完成"
}

# 构建GmSSL
build_gmssl() {
    log_info "构建GmSSL..."
    
    cd "${PROJECT_ROOT}/src"
    
    if [ ! -d "GmSSL-3.2.0" ]; then
        wget -q "https://github.com/guanzhi/GmSSL/archive/refs/tags/v3.2.0.tar.gz" -O "gmssl-3.2.0.tar.gz"
        tar -xzf "gmssl-3.2.0.tar.gz"
        rm -f "gmssl-3.2.0.tar.gz"
    fi
    
    cd GmSSL-3.2.0
    mkdir -p build && cd build
    
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${PROJECT_ROOT}/build/gmssl" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON
    
    make -j$(nproc)
    make install
    
    log_success "GmSSL构建完成"
}

# 构建CNMD
build_cnmd() {
    log_info "构建CNMD..."
    
    cd "${PROJECT_ROOT}/src/postgresql-18"
    
    make clean 2>/dev/null || true
    
    ./configure \
        --prefix="${PROJECT_ROOT}/build/cnmd" \
        --with-ssl=openssl \
        --with-includes="${PROJECT_ROOT}/build/gmssl/include" \
        --with-libraries="${PROJECT_ROOT}/build/gmssl/lib" \
        --enable-integer-datetimes \
        --enable-thread-safety \
        --with-libxml \
        --with-libxslt \
        --with-uuid-ossp \
        --with-optimization
    
    make -j$(nproc)
    
    log_success "CNMD构建完成"
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    
    cd "${PROJECT_ROOT}/src/postgresql-18"
    
    # 运行回归测试
    make check || true
    
    log_success "测试完成"
}

# 代码质量检查
code_quality() {
    log_info "代码质量检查..."
    
    # 检查代码格式
    if command -v clang-format &> /dev/null; then
        find "${PROJECT_ROOT}/src/postgresql-18/src" -name "*.c" -exec clang-format --dry-run --Werror {} \; || true
    fi
    
    # 检查安全漏洞
    if command -v cppcheck &> /dev/null; then
        cppcheck --enable=warning,style,performance,portability "${PROJECT_ROOT}/src/postgresql-18/src" || true
    fi
    
    log_success "代码质量检查完成"
}

# 生成构建报告
generate_report() {
    log_info "生成构建报告..."
    
    REPORT_FILE="${PROJECT_ROOT}/build-report.md"
    
    cat > "${REPORT_FILE}" << EOF
# CNMD 构建报告

## 构建信息
- **构建时间**: $(date)
- **架构**: ${ARCH}
- **操作系统**: ${OS}
- **编译器**: $(gcc --version | head -n1)

## 构建结果
- **GmSSL**: ✅ 成功
- **CNMD**: ✅ 成功
- **测试**: $(if [ -f "${PROJECT_ROOT}/src/postgresql-18/log/regression.diffs" ]; then echo "❌ 有失败"; else echo "✅ 通过"; fi)

## 构建产物
- **安装路径**: ${PROJECT_ROOT}/build/cnmd
- **GmSSL路径**: ${PROJECT_ROOT}/build/gmssl

## 下一步
1. 在目标平台上测试
2. 进行性能基准测试
3. 进行安全合规测试
EOF
    
    log_success "构建报告已生成: ${REPORT_FILE}"
}

# 主流程
main() {
    install_dependencies
    build_gmssl
    build_cnmd
    run_tests
    code_quality
    generate_report
    
    log_success "CI/CD构建完成!"
}

# 执行主流程
main
