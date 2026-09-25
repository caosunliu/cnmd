#!/bin/bash
#
# build-gmssl.sh - 编译安装GmSSL国密算法库
#
# 用法: ./build-gmssl.sh [版本号]
# 默认版本: 3.2.0
#

set -e

GMSSL_VERSION=${1:-3.2.0}
GMSSL_DIR="GmSSL-${GMSSL_VERSION}"
INSTALL_PREFIX="/usr/local/gmssl"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  GmSSL 国密算法库编译安装脚本"
echo "  版本: ${GMSSL_VERSION}"
echo "=========================================="

# 检查是否已安装
if [ -d "${INSTALL_PREFIX}" ]; then
    echo "[警告] GmSSL已安装在 ${INSTALL_PREFIX}"
    read -p "是否重新编译安装? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "跳过安装"
        exit 0
    fi
    sudo rm -rf "${INSTALL_PREFIX}"
fi

# 进入源码目录
cd "${PROJECT_ROOT}/src"

# 下载GmSSL（如果不存在）
if [ ! -d "${GMSSL_DIR}" ]; then
    echo "[信息] 下载GmSSL ${GMSSL_VERSION}..."
    wget -q "https://github.com/guanzhi/GmSSL/archive/refs/tags/v${GMSSL_VERSION}.tar.gz" -O "gmssl-${GMSSL_VERSION}.tar.gz"
    tar -xzf "gmssl-${GMSSL_VERSION}.tar.gz"
    rm -f "gmssl-${GMSSL_VERSION}.tar.gz"
fi

# 进入编译目录
cd "${GMSSL_DIR}"

# 创建构建目录
mkdir -p build && cd build

# 配置
echo "[信息] 配置GmSSL..."
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF

# 编译
echo "[信息] 编译GmSSL..."
make -j$(nproc)

# 安装
echo "[信息] 安装GmSSL..."
sudo make install

# 更新动态链接库缓存
echo "[信息] 更新动态链接库缓存..."
sudo ldconfig

echo ""
echo "=========================================="
echo "  GmSSL安装完成!"
echo "  安装路径: ${INSTALL_PREFIX}"
echo "=========================================="
echo ""
echo "环境变量设置:"
echo "  export LD_LIBRARY_PATH=${INSTALL_PREFIX}/lib:\$LD_LIBRARY_PATH"
echo "  export PATH=${INSTALL_PREFIX}/bin:\$PATH"
