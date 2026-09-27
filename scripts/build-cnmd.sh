#!/bin/bash
#
# build-cnmd.sh - 编译安装CNMD数据库
#
# 用法: ./build-cnmd.sh [选项]
#   -p, --prefix DIR     安装路径 (默认: /usr/local/cnmd)
#   -j, --jobs N         并行编译数 (默认: CPU核心数)
#   --debug              启用调试模式
#   --mysql-compat       启用MySQL兼容模式
#   -h, --help           显示帮助
#

set -e

# 默认参数
PREFIX="/usr/local/cnmd"
JOBS=$(nproc)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEBUG=false
MYSQL_COMPAT=true
SRC_DIR="${PROJECT_ROOT}/src/postgresql-18"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --mysql-compat)
            MYSQL_COMPAT=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  -p, --prefix DIR     安装路径 (默认: /usr/local/cnmd)"
            echo "  -j, --jobs N         并行编译数 (默认: CPU核心数)"
            echo "  --debug              启用调试模式"
            echo "  --mysql-compat       启用MySQL兼容模式"
            echo "  -h, --help           显示帮助"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  CNMD 数据库编译安装脚本"
echo "  版本: 1.0.0"
echo "  基础版本: PostgreSQL 18"
echo "=========================================="
echo ""
echo "编译配置:"
echo "  安装路径: ${PREFIX}"
echo "  并行编译: ${JOBS}线程"
echo "  调试模式: ${DEBUG}"
echo "  MySQL兼容: ${MYSQL_COMPAT}"
echo ""

# 检查PostgreSQL源码
if [ ! -d "${SRC_DIR}" ]; then
    echo "[信息] PostgreSQL源码不存在，开始获取..."
    cd "${PROJECT_ROOT}/src"
    git clone --branch REL_18_6 --depth 1 https://github.com/postgres/postgres.git postgresql-18
    cd postgresql-18
    echo "[信息] 应用CNMD补丁..."
    git apply "${PROJECT_ROOT}/patches/"*.patch 2>/dev/null || true
fi

# 进入源码目录
cd "${SRC_DIR}"

# 清理之前的编译
echo "[信息] 清理之前的编译文件..."
make clean 2>/dev/null || true

# 配置编译选项
echo "[信息] 配置编译选项..."

CONFIGURE_OPTS=(
    --prefix="${PREFIX}"
    --with-ssl=openssl
    --enable-integer-datetimes
    --enable-thread-safety
    --enable-debug
    --with-libxml
    --with-libxslt
    --with-uuid-ossp
    --with-systemd
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

# MySQL兼容模式
if [ "${MYSQL_COMPAT}" = true ]; then
    CONFIGURE_OPTS+=(
        --with-mysql-compat
    )
fi

# 执行配置
./configure "${CONFIGURE_OPTS[@]}"

# 编译
echo "[信息] 开始编译 (使用${JOBS}个线程)..."
make -j"${JOBS}"

# 运行测试（可选）
echo ""
read -p "是否运行回归测试? (y/n): " run_tests
if [ "$run_tests" = "y" ]; then
    echo "[信息] 运行回归测试..."
    make check
fi

# 安装
echo "[信息] 安装CNMD..."
sudo make install

# 安装contrib模块
echo "[信息] 安装贡献模块..."
cd contrib
for dir in */; do
    if [ -f "${dir}/Makefile" ]; then
        echo "  安装 ${dir}..."
        cd "${dir}"
        make install
        cd ..
    fi
done
cd ..

echo ""
echo "=========================================="
echo "  CNMD安装完成!"
echo "  安装路径: ${PREFIX}"
echo "=========================================="
echo ""
echo "环境变量设置:"
echo "  export PATH=${PREFIX}/bin:\$PATH"
echo "  export LD_LIBRARY_PATH=${PREFIX}/lib:\$LD_LIBRARY_PATH"
echo "  export MANPATH=${PREFIX}/share/man:\$MANPATH"
echo ""
echo "下一步操作:"
echo "  1. 创建数据目录: sudo mkdir -p /var/lib/cnmd/data"
echo "  2. 创建用户: sudo useradd -m -s /bin/bash cnmd"
echo "  3. 初始化数据库: sudo -u cnmd ${PREFIX}/bin/cnmd-initdb -D /var/lib/cnmd/data"
echo "  4. 启动服务: sudo -u cnmd ${PREFIX}/bin/cnmd-pg_ctl start -D /var/lib/cnmd/data"
