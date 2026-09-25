#!/bin/bash
#
# test-gm-crypto.sh - 国密算法测试脚本
#
# 用法: ./test-gm-crypto.sh [数据库连接信息]
#

set -e

# 默认参数
DB_HOST=${1:-localhost}
DB_PORT=${2:-5432}
DB_NAME=${3:-postgres}
DB_USER=${4:-postgres}

echo "=========================================="
echo "  CNMD 国密算法测试"
echo "=========================================="
echo ""
echo "数据库连接: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo ""

# 测试SM3哈希
echo "测试1: SM3哈希算法"
echo "-------------------------------------------"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
SELECT sm3_hash('abc') as sm3_hash;
SELECT sm3_hash('hello world') as sm3_hash_hw;
"

# 测试SM4加密
echo ""
echo "测试2: SM4加密算法"
echo "-------------------------------------------"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
-- 生成SM4密钥
SELECT sm4_generate_key() as sm4_key;

-- 使用固定密钥测试SM4加密解密
SELECT sm4_encrypt('Hello, CNMD!', '0123456789abcdef', '0000000000000000') as encrypted;
SELECT sm4_decrypt(sm4_encrypt('Hello, CNMD!', '0123456789abcdef', '0000000000000000'), '0123456789abcdef', '0000000000000000') as decrypted;
"

# 测试SM2签名
echo ""
echo "测试3: SM2签名算法"
echo "-------------------------------------------"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
-- 生成SM2密钥对
SELECT sm2_keygen() as sm2_keypair;

-- 注意: SM2签名需要密钥参数，实际使用时需要提供有效的密钥
"

# 测试MySQL兼容模式
echo ""
echo "测试4: MySQL兼容模式"
echo "-------------------------------------------"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
-- 启用MySQL兼容模式
SET cnmd.compatibility_mode = 'mysql';

-- 显示兼容模式
SHOW cnmd.compatibility_mode;

-- 测试MySQL风格的SHOW命令
SHOW DATABASES;
SHOW TABLES;
"

# 测试安全审计
echo ""
echo "测试5: 安全审计"
echo "-------------------------------------------"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
-- 查看审计配置
SHOW audit_log;
SHOW audit_log_file;
SHOW audit_log_statement;

-- 查看审计日志表（如果存在）
SELECT * FROM pg_audit_log LIMIT 10;
"

echo ""
echo "=========================================="
echo "  测试完成"
echo "=========================================="
