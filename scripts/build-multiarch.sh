#!/bin/bash
#
# build-multiarch.sh - 多架构交叉编译脚本
#
# 支持架构: x86_64, aarch64(ARM64), loongarch64, x86_64(海光)
#
# 用法: ./build-multiarch.sh <架构>
#   架构: x86_64 | aarch64 | loongarch64 | hygon
#

set -e

ARCH=${1:-x86_64}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build-${ARCH}"

echo "=========================================="
echo "  CNMD 多架构编译脚本"
echo "  目标架构: ${ARCH}"
echo "=========================================="

# 架构配置
case ${ARCH} in
    x86_64)
        CROSS_COMPILE=""
        HOST="x86_64-linux-gnu"
        CFLAGS="-O2 -march=x86-64"
        ;;
    aarch64)
        CROSS_COMPILE="aarch64-linux-gnu-"
        HOST="aarch64-linux-gnu"
        CFLAGS="-O2 -march=armv8-a"
        ;;
    loongarch64)
        CROSS_COMPILE="loongarch64-linux-gnu-"
        HOST="loongarch64-linux-gnu"
        CFLAGS="-O2 -march=loongarch64"
        ;;
    hygon)
        CROSS_COMPILE=""
        HOST="x86_64-linux-gnu"
        CFLAGS="-O2 -march=x86-64 -mno-avx512f"
        ;;
    *)
        echo "不支持的架构: ${ARCH}"
        echo "支持的架构: x86_64, aarch64, loongarch64, hygon"
        exit 1
        ;;
esac

echo "架构配置:"
echo "  目标架构: ${ARCH}"
echo "  交叉编译前缀: ${CROSS_COMPILE}"
echo "  宿主系统: ${HOST}"
echo "  编译选项: ${CFLAGS}"
echo ""

# 检查交叉编译工具链
if [ -n "${CROSS_COMPILE}" ]; then
    echo "[信息] 检查交叉编译工具链..."
    if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
        echo "[错误] 未找到交叉编译工具链: ${CROSS_COMPILE}gcc"
        echo "请安装相应的交叉编译工具链"
        echo "  Ubuntu/Debian: sudo apt install gcc-${ARCH}-linux-gnu"
        echo "  CentOS/RHEL: sudo yum install gcc-${ARCH}-linux-gnu"
        exit 1
    fi
fi

# 创建构建目录
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# 配置GmSSL
echo "[信息] 配置GmSSL..."
cd "${PROJECT_ROOT}/src/GmSSL-3.2.0"
mkdir -p build-${ARCH} && cd build-${ARCH}

cmake .. \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=${ARCH} \
    -DCMAKE_C_COMPILER=${CROSS_COMPILE}gcc \
    -DCMAKE_CXX_COMPILER=${CROSS_COMPILE}g++ \
    -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/gmssl" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON

make -j$(nproc)
make install

# 配置PostgreSQL
echo "[信息] 配置PostgreSQL..."
cd "${PROJECT_ROOT}/src/postgresql-18"

./configure \
    --host=${HOST} \
    --prefix="${BUILD_DIR}/cnmd" \
    --with-includes="${BUILD_DIR}/gmssl/include" \
    --with-libraries="${BUILD_DIR}/gmssl/lib" \
    --with-ssl=openssl \
    --enable-integer-datetimes \
    --enable-thread-safety \
    --with-libxml \
    --with-libxslt \
    --with-uuid-ossp \
    CFLAGS="${CFLAGS}" \
    LDFLAGS="-L${BUILD_DIR}/gmssl/lib"

# 编译
echo "[信息] 编译PostgreSQL..."
make -j$(nproc)

# 安装
echo "[信息] 安装PostgreSQL..."
make install

echo ""
echo "=========================================="
echo "  ${ARCH}架构编译完成!"
echo "  安装路径: ${BUILD_DIR}/cnmd"
echo "=========================================="
