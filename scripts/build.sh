#!/bin/bash
#
# build.sh - CNMD自动化构建脚本
#
# 用法: ./build.sh [选项]
#   --mode MODE      构建模式: native|docker|all (默认: native)
#   --arch ARCH      目标架构 (默认: 本机)
#   --prefix DIR     安装路径 (默认: /usr/local/cnmd)
#   --jobs N         并行编译数 (默认: CPU核心数)
#   --debug          启用调试模式
#   --clean          清理构建
#   --test           运行测试
#   --install        安装
#   -h, --help       显示帮助
#

set -e

# 默认参数
MODE="native"
ARCH=""
PREFIX="/usr/local/cnmd"
JOBS=$(nproc 2>/dev/null || echo 4)
DEBUG=false
CLEAN=false
TEST=false
INSTALL=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 显示帮助
show_help() {
    echo "CNMD 自动化构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --mode MODE      构建模式: native|docker|all (默认: native)"
    echo "  --arch ARCH      目标架构 (默认: 本机)"
    echo "  --prefix DIR     安装路径 (默认: /usr/local/cnmd)"
    echo "  --jobs N         并行编译数 (默认: CPU核心数)"
    echo "  --debug          启用调试模式"
    echo "  --clean          清理构建"
    echo "  --test           运行测试"
    echo "  --install        安装"
    echo "  -h, --help       显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 --mode native --prefix /opt/cnmd"
    echo "  $0 --mode docker --arch arm64"
    echo "  $0 --clean --build --test --install"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --jobs)
            JOBS="$2"
            shift 2
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  CNMD 自动化构建系统"
echo "=========================================="
echo ""
echo "构建配置:"
echo "  构建模式: ${MODE}"
echo "  目标架构: ${ARCH:-本机}"
echo "  安装路径: ${PREFIX}"
echo "  并行编译: ${JOBS}线程"
echo "  调试模式: ${DEBUG}"
echo "  清理构建: ${CLEAN}"
echo "  运行测试: ${TEST}"
echo "  安装: ${INSTALL}"
echo ""

# 检查依赖
check_dependencies() {
    log_info "检查构建依赖..."
    
    # 检查基本工具
    for cmd in git make gcc; do
        if ! command -v $cmd &> /dev/null; then
            log_error "未找到命令: $cmd"
            exit 1
        fi
    done
    
    # 检查Docker（如果使用Docker模式）
    if [ "${MODE}" = "docker" ] || [ "${MODE}" = "all" ]; then
        if ! command -v docker &> /dev/null; then
            log_error "未找到Docker命令"
            exit 1
        fi
    fi
    
    log_success "依赖检查通过"
}

# 清理构建
clean_build() {
    log_info "清理构建目录..."
    
    if [ -d "${PROJECT_ROOT}/build" ]; then
        rm -rf "${PROJECT_ROOT}/build"
    fi
    
    if [ -d "${PROJECT_ROOT}/src/postgresql-18/build" ]; then
        rm -rf "${PROJECT_ROOT}/src/postgresql-18/build"
    fi
    
    log_success "清理完成"
}

# 构建GmSSL
build_gmssl() {
    log_info "构建GmSSL国密算法库..."
    
    cd "${PROJECT_ROOT}/src"
    
    # 下载GmSSL（如果不存在）
    if [ ! -d "GmSSL-3.2.0" ]; then
        log_info "下载GmSSL 3.2.0..."
        wget -q "https://github.com/guanzhi/GmSSL/archive/refs/tags/v3.2.0.tar.gz" -O "gmssl-3.2.0.tar.gz"
        tar -xzf "gmssl-3.2.0.tar.gz"
        rm -f "gmssl-3.2.0.tar.gz"
    fi
    
    cd GmSSL-3.2.0
    
    # 创建构建目录
    mkdir -p build && cd build
    
    # 配置
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${PROJECT_ROOT}/build/gmssl" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON
    
    # 编译
    make -j"${JOBS}"
    
    # 安装
    make install
    
    log_success "GmSSL构建完成"
}

# 构建PostgreSQL/CNMD
build_cnmd() {
    log_info "构建CNMD数据库..."
    
    cd "${PROJECT_ROOT}/src/postgresql-18"
    
    # 清理之前的构建
    make clean 2>/dev/null || true
    
    # 配置构建选项
    CONFIGURE_OPTS=(
        --prefix="${PREFIX}"
        --with-ssl=openssl
        --with-includes="${PROJECT_ROOT}/build/gmssl/include"
        --with-libraries="${PROJECT_ROOT}/build/gmssl/lib"
        --enable-integer-datetimes
        --enable-thread-safety
        --with-libxml
        --with-libxslt
        --with-uuid-ossp
    )
    
    # 调试模式
    if [ "${DEBUG}" = true ]; then
        CONFIGURE_OPTS+=(
            --enable-cassert
            --enable-debug
            CFLAGS="-O0 -g3"
        )
    else
        CONFIGURE_OPTS+=(
            --with-optimization
        )
    fi
    
    # 执行配置
    ./configure "${CONFIGURE_OPTS[@]}"
    
    # 编译
    log_info "开始编译 (使用${JOBS}个线程)..."
    make -j"${JOBS}"
    
    log_success "CNMD构建完成"
}

# 运行测试
run_tests() {
    log_info "运行回归测试..."
    
    cd "${PROJECT_ROOT}/src/postgresql-18"
    
    make check
    
    log_success "测试完成"
}

# 安装
install_cnmd() {
    log_info "安装CNMD..."
    
    cd "${PROJECT_ROOT}/src/postgresql-18"
    
    sudo make install
    
    # 安装contrib模块
    cd contrib
    for dir in */; do
        if [ -f "${dir}/Makefile" ]; then
            log_info "安装 ${dir}..."
            cd "${dir}"
            sudo make install
            cd ..
        fi
    done
    cd ..
    
    log_success "安装完成: ${PREFIX}"
}

# Docker构建
build_docker() {
    log_info "Docker构建..."
    
    cd "${SCRIPT_DIR}"
    
    # 构建单架构镜像
    docker build -t cnmd/cnmd-db:latest ..
    
    log_success "Docker构建完成"
}

# 主流程
main() {
    check_dependencies
    
    # 清理构建
    if [ "${CLEAN}" = true ]; then
        clean_build
    fi
    
    # 创建构建目录
    mkdir -p "${PROJECT_ROOT}/build"
    
    case ${MODE} in
        native)
            # 构建GmSSL
            build_gmssl
            
            # 构建CNMD
            build_cnmd
            
            # 运行测试
            if [ "${TEST}" = true ]; then
                run_tests
            fi
            
            # 安装
            if [ "${INSTALL}" = true ]; then
                install_cnmd
            fi
            ;;
        docker)
            build_docker
            ;;
        all)
            # 本地构建
            build_gmssl
            build_cnmd
            
            # Docker构建
            build_docker
            
            # 运行测试
            if [ "${TEST}" = true ]; then
                run_tests
            fi
            
            # 安装
            if [ "${INSTALL}" = true ]; then
                install_cnmd
            fi
            ;;
        *)
            log_error "未知构建模式: ${MODE}"
            show_help
            exit 1
            ;;
    esac
    
    log_success "构建完成!"
}

# 执行主流程
main
