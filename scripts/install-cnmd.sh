#!/bin/bash
#
# install-cnmd.sh - 安装CNMD数据库服务
#
# 用法: ./install-cnmd.sh [选项]
#   -p, --prefix DIR     安装路径 (默认: /usr/local/cnmd)
#   -d, --data-dir DIR   数据目录 (默认: /var/lib/cnmd/data)
#   -u, --user USER      运行用户 (默认: cnmd)
#   -h, --help           显示帮助
#

set -e

# 默认参数
PREFIX="/usr/local/cnmd"
DATA_DIR="/var/lib/cnmd/data"
DB_USER="cnmd"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -u|--user)
            DB_USER="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  -p, --prefix DIR     安装路径 (默认: /usr/local/cnmd)"
            echo "  -d, --data-dir DIR   数据目录 (默认: /var/lib/cnmd/data)"
            echo "  -u, --user USER      运行用户 (默认: cnmd)"
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
echo "  CNMD 数据库安装脚本"
echo "=========================================="
echo ""
echo "安装配置:"
echo "  安装路径: ${PREFIX}"
echo "  数据目录: ${DATA_DIR}"
echo "  运行用户: ${DB_USER}"
echo ""

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "[错误] 请使用root权限运行此脚本"
    echo "用法: sudo $0"
    exit 1
fi

# 创建用户和组
echo "[信息] 创建用户和组..."
if ! id -u "${DB_USER}" >/dev/null 2>&1; then
    groupadd -r "${DB_USER}"
    useradd -r -g "${DB_USER}" -d /var/lib/cnmd -s /bin/bash "${DB_USER}"
    echo "[信息] 用户 ${DB_USER} 创建成功"
else
    echo "[信息] 用户 ${DB_USER} 已存在"
fi

# 创建目录
echo "[信息] 创建目录结构..."
mkdir -p "${DATA_DIR}"
mkdir -p /var/log/cnmd
mkdir -p /var/run/cnmd
mkdir -p /etc/cnmd

# 设置权限
echo "[信息] 设置目录权限..."
chown -R "${DB_USER}:${DB_USER}" /var/lib/cnmd
chown -R "${DB_USER}:${DB_USER}" /var/log/cnmd
chown -R "${DB_USER}:${DB_USER}" /var/run/cnmd
chmod 700 "${DATA_DIR}"

# 复制配置文件
echo "[信息] 复制配置文件..."
cp "${PROJECT_ROOT}/config/postgresql.conf" /etc/cnmd/postgresql.conf
cp "${PROJECT_ROOT}/config/pg_hba.conf" /etc/cnmd/pg_hba.conf
chown -R "${DB_USER}:${DB_USER}" /etc/cnmd
chmod 600 /etc/cnmd/pg_hba.conf

# 创建systemd服务
echo "[信息] 创建systemd服务..."
cat > /etc/systemd/system/cnmd.service << EOF
[Unit]
Description=CNMD Database Server
After=network.target

[Service]
Type=forking
User=${DB_USER}
Group=${DB_USER}
ExecStart=${PREFIX}/bin/cnmd-pg_ctl start -D ${DATA_DIR} -l /var/log/cnmd/cnmd.log
ExecStop=${PREFIX}/bin/cnmd-pg_ctl stop -D ${DATA_DIR}
ExecReload=/bin/kill -HUP \$MAINPID
TimeoutSec=120

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd
systemctl daemon-reload

# 初始化数据库
echo "[信息] 初始化数据库..."
sudo -u "${DB_USER}" "${PREFIX}/bin/cnmd-initdb" \
    -D "${DATA_DIR}" \
    -E UTF8 \
    --locale=zh_CN.UTF-8 \
    --encoding=UTF8 \
    --data-checksums

# 配置数据库
echo "[信息] 配置数据库..."
cat >> "${DATA_DIR}/postgresql.cnmd.conf" << EOF

# CNMD自定义配置
include = '/etc/cnmd/postgresql.conf'

# 安全配置
password_encryption = sm3
audit_log = on
audit_log_file = '/var/log/cnmd/audit.log'

# MySQL兼容模式
cnmd.compatibility_mode = 'mysql'

# 国密算法配置
ssl = on
ssl_cert_file = '/etc/cnmd/server.crt'
ssl_key_file = '/etc/cnmd/server.key'
ssl_ciphers = 'SM4-GCM-SM3'
EOF

# 启动服务
echo "[信息] 启动CNMD服务..."
sudo -u "${DB_USER}" "${PREFIX}/bin/cnmd-pg_ctl" \
    -D "${DATA_DIR}" \
    -l /var/log/cnmd/cnmd.log \
    start

echo ""
echo "=========================================="
echo "  CNMD安装完成!"
echo "=========================================="
echo ""
echo "服务管理:"
echo "  启动: systemctl start cnmd"
echo "  停止: systemctl stop cnmd"
echo "  重启: systemctl restart cnmd"
echo "  状态: systemctl status cnmd"
echo ""
echo "连接数据库:"
echo "  ${PREFIX}/bin/cnmd-psql -U ${DB_USER} -d postgres"
echo ""
echo "配置文件:"
echo "  主配置: ${DATA_DIR}/postgresql.cnmd.conf"
echo "  认证配置: /etc/cnmd/pg_hba.conf"
echo "  日志文件: /var/log/cnmd/cnmd.log"
echo ""
echo "默认端口: 5432"
