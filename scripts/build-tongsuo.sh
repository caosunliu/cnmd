#!/bin/bash
#
# build-tongsuo.sh - 编译安装Tongsuo国密SSL库（OpenSSL兼容）
#
# 用法: ./build-tongsuo.sh [安装路径]
# 默认安装路径: /usr/local/tongsuo
# 源码路径: src/Tongsuo-8.4.0
#

set -e

INSTALL_PREFIX=${1:-/usr/local/tongsuo}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TONGSUO_SRC="${PROJECT_ROOT}/src/Tongsuo-8.4.0"

echo "=========================================="
echo "  Tongsuo 国密SSL库编译安装脚本"
echo "  源码路径: ${TONGSUO_SRC}"
echo "  安装路径: ${INSTALL_PREFIX}"
echo "=========================================="

# 检查源码目录
if [ ! -d "${TONGSUO_SRC}" ]; then
    echo "[错误] Tongsuo源码不存在: ${TONGSUO_SRC}"
    exit 1
fi

# 检查是否已安装
if [ -d "${INSTALL_PREFIX}" ]; then
    echo "[警告] Tongsuo已安装在 ${INSTALL_PREFIX}"
    read -p "是否重新编译安装? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "跳过安装"
        exit 0
    fi
    sudo rm -rf "${INSTALL_PREFIX}"
fi

# 进入源码目录
cd "${TONGSUO_SRC}"

# 配置
echo "[信息] 配置Tongsuo..."
chmod +x config
./config \
    --prefix="${INSTALL_PREFIX}" \
    --openssldir="${INSTALL_PREFIX}/ssl" \
    enable-sm2 enable-sm3 enable-sm4

# 编译
echo "[信息] 编译Tongsuo..."
make -j$(nproc)

# 安装开发文件（头文件+库）
echo "[信息] 安装Tongsuo..."
sudo make install_dev

# 更新动态链接库缓存
echo "[信息] 更新动态链接库缓存..."
sudo ldconfig

echo ""
echo "=========================================="
echo "  Tongsuo安装完成!"
echo "  安装路径: ${INSTALL_PREFIX}"
echo "=========================================="
echo ""
echo "环境变量设置:"
echo "  export LD_LIBRARY_PATH=${INSTALL_PREFIX}/lib:\$LD_LIBRARY_PATH"
echo "  export PATH=${INSTALL_PREFIX}/bin:\$PATH"
