#!/bin/bash
#
# build-xinchuang.sh - 信创平台构建脚本
#
# 支持平台: 银河麒麟、统信UOS、openEuler
# 支持架构: amd64、arm64、loongarch64
#
# 用法: ./build-xinchuang.sh [选项]
#   --platform PLATFORM   目标平台 (kylin|uos|openeuler)
#   --arch ARCH           目标架构 (amd64|arm64|loongarch64)
#   --mode MODE           构建模式 (native|cross|docker)
#   --push                推送Docker镜像
#   -h, --help            显示帮助
#

set -e

# 默认参数
PLATFORM=""
ARCH=""
MODE="native"
PUSH=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# 显示帮助
show_help() {
    echo "CNMD 信创平台构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --platform PLATFORM   目标平台 (kylin|uos|openeuler)"
    echo "  --arch ARCH           目标架构 (amd64|arm64|loongarch64)"
    echo "  --mode MODE           构建模式 (native|cross|docker)"
    echo "  --push                推送Docker镜像"
    echo "  -h, --help            显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 --platform kylin --arch amd64 --mode docker"
    echo "  $0 --platform openeuler --arch arm64 --mode cross"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# 验证参数
if [ -z "${PLATFORM}" ]; then
    log_error "请指定目标平台 (--platform)"
    exit 1
fi

if [ -z "${ARCH}" ]; then
    log_error "请指定目标架构 (--arch)"
    exit 1
fi

echo "=========================================="
echo "  CNMD 信创平台构建"
echo "=========================================="
echo ""
echo "构建配置:"
echo "  目标平台: ${PLATFORM}"
echo "  目标架构: ${ARCH}"
echo "  构建模式: ${MODE}"
echo ""

# 加载平台配置
load_platform_config() {
    local platform=$1
    
    case ${platform} in
        kylin)
            BASE_IMAGE="kylinv10/kylin:latest"
            PKG_MGR="apt"
            ;;
        uos)
            BASE_IMAGE="uos:latest"
            PKG_MGR="apt"
            ;;
        openeuler)
            BASE_IMAGE="openeuler/openeuler:22.03"
            PKG_MGR="yum"
            ;;
        *)
            log_error "不支持的平台: ${platform}"
            exit 1
            ;;
    esac
    
    log_info "加载平台配置: ${platform} (${BASE_IMAGE})"
}

# 安装依赖
install_dependencies() {
    log_info "安装构建依赖..."
    
    if [ "${PKG_MGR}" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y \
            build-essential gcc g++ make cmake git wget curl \
            pkg-config libreadline-dev zlib1g-dev libssl-dev \
            libxml2-dev libxslt1-dev libsystemd-dev libicu-dev \
            uuid-dev flex bison python3
    elif [ "${PKG_MGR}" = "yum" ]; then
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y \
            gcc gcc-c++ make cmake git wget curl \
            pkg-config readline-devel zlib-devel openssl-devel \
            libxml2-devel libxslt-devel systemd-devel libuuid-devel \
            flex bison python3
    fi
    
    log_success "依赖安装完成"
}

# 构建GmSSL
build_gmssl() {
    log_info "构建GmSSL国密算法库..."
    
    cd "${PROJECT_ROOT}/src"
    
    # 下载GmSSL
    if [ ! -d "GmSSL-3.2.0" ]; then
        wget -q "https://github.com/guanzhi/GmSSL/archive/refs/tags/v3.2.0.tar.gz" -O gmssl.tar.gz
        tar -xzf gmssl.tar.gz
        rm -f gmssl.tar.gz
    fi
    
    cd GmSSL-3.2.0
    mkdir -p build && cd build
    
    # 交叉编译配置
    CMAKE_OPTS=(
        -DCMAKE_INSTALL_PREFIX="${PROJECT_ROOT}/build/gmssl"
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_SHARED_LIBS=ON
    )
    
    if [ "${MODE}" = "cross" ]; then
        case ${ARCH} in
            loongarch64)
                CMAKE_OPTS+=(
                    -DCMAKE_SYSTEM_NAME=Linux
                    -DCMAKE_SYSTEM_PROCESSOR=loongarch64
                    -DCMAKE_C_COMPILER=loongarch64-linux-gnu-gcc
                )
                ;;
            arm64)
                CMAKE_OPTS+=(
                    -DCMAKE_SYSTEM_NAME=Linux
                    -DCMAKE_SYSTEM_PROCESSOR=aarch64
                    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc
                )
                ;;
        esac
    fi
    
    cmake .. "${CMAKE_OPTS[@]}"
    make -j$(nproc)
    make install
    
    log_success "GmSSL构建完成"
}

# 构建CNMD
build_cnmd() {
    log_info "构建CNMD数据库..."
    
    cd "${PROJECT_ROOT}/src/postgresql-18"
    
    make clean 2>/dev/null || true
    
    CONFIGURE_OPTS=(
        --prefix="${PROJECT_ROOT}/build/cnmd"
        --with-ssl=openssl
        --with-includes="${PROJECT_ROOT}/build/gmssl/include"
        --with-libraries="${PROJECT_ROOT}/build/gmssl/lib"
        --enable-integer-datetimes
        --enable-thread-safety
        --with-libxml
        --with-libxslt
        --with-uuid-ossp
    )
    
    if [ "${MODE}" = "cross" ]; then
        case ${ARCH} in
            loongarch64)
                CONFIGURE_OPTS+=(--host=loongarch64-linux-gnu)
                ;;
            arm64)
                CONFIGURE_OPTS+=(--host=aarch64-linux-gnu)
                ;;
        esac
    fi
    
    ./configure "${CONFIGURE_OPTS[@]}"
    make -j$(nproc)
    
    log_success "CNMD构建完成"
}

# Docker构建
build_docker() {
    log_info "Docker构建..."
    
    cd "${SCRIPT_DIR}/../docker"
    
    case ${PLATFORM} in
        kylin)
            DOCKERFILE="Dockerfile.kylin"
            ;;
        uos)
            DOCKERFILE="Dockerfile.uos"
            ;;
        openeuler)
            DOCKERFILE="Dockerfile.openeuler"
            ;;
    esac
    
    docker build -t cnmd/cnmd-${PLATFORM}:${ARCH} -f ${DOCKERFILE} ..
    
    if [ "${PUSH}" = true ]; then
        docker push cnmd/cnmd-${PLATFORM}:${ARCH}
    fi
    
    log_success "Docker构建完成"
}

# 主流程
main() {
    load_platform_config "${PLATFORM}"
    install_dependencies
    build_gmssl
    build_cnmd
    
    if [ "${MODE}" = "docker" ]; then
        build_docker
    fi
    
    log_success "构建完成!"
}

main
