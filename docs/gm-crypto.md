# CNMD 国密算法说明

本文档介绍CNMD数据库集成的国密算法功能。

## 概述

CNMD集成了GmSSL国密算法库，支持SM2、SM3、SM4等国密算法，满足信创环境下的安全要求。

## 支持的算法

### SM2 - 椭圆曲线公钥密码算法

SM2是基于椭圆曲线密码学的公钥密码算法，用于替代RSA/ECDSA。

**功能**：
- 密钥生成
- 数字签名与验签
- 公钥加密与解密
- 密钥交换

**应用场景**：
- 数字证书
- 安全通信
- 数据签名

### SM3 - 密码杂凑算法

SM3是密码哈希算法，用于替代SHA-256/MD5。

**功能**：
- 消息摘要计算
- HMAC-SM3
- 密码哈希

**应用场景**：
- 数据完整性验证
- 数字签名
- 密码存储

### SM4 - 分组密码算法

SM4是对称加密算法，用于替代AES/DES。

**功能**：
- ECB模式加密/解密
- CBC模式加密/解密
- CTR模式加密/解密
- GCM模式加密/解密（带认证）

**应用场景**：
- 数据加密
- 传输加密
- 存储加密

## 使用方法

### SM3哈希函数

```sql
-- 计算SM3哈希
SELECT sm3_hash('hello world') as hash_value;

-- 输出示例:
-- \x66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0

-- 验证SM3哈希
SELECT sm3_verify_hash('hello world', '\x66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0') as is_valid;
```

### SM4加密函数

```sql
-- 生成SM4密钥
SELECT sm4_generate_key() as key_value;

-- SM4 CBC模式加密
SELECT sm4_encrypt('Hello, CNMD!', '0123456789abcdef', '0000000000000000') as encrypted;

-- SM4 CBC模式解密
SELECT sm4_decrypt(sm4_encrypt('Hello, CNMD!', '0123456789abcdef', '0000000000000000'), '0123456789abcdef', '0000000000000000') as decrypted;

-- SM4 ECB模式加密
SELECT sm4_encrypt_ecb('Hello, CNMD!', '0123456789abcdef') as encrypted_ecb;

-- SM4 ECB模式解密
SELECT sm4_decrypt_ecb(sm4_encrypt_ecb('Hello, CNMD!', '0123456789abcdef'), '0123456789abcdef') as decrypted_ecb;
```

### SM2签名函数

```sql
-- 生成SM2密钥对
SELECT sm2_keygen() as keypair;

-- 注意: SM2签名需要密钥参数，实际使用时需要提供有效的密钥
```

## 透明数据加密(TDE)

CNMD支持使用SM4算法进行透明数据加密。

### 启用TDE

```sql
-- 创建加密表
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    data TEXT
) WITH (encryption = true, encryption_algorithm = 'sm4');

-- 查看加密表信息
SELECT * FROM pg_encrypted_tables;
```

### 密钥管理

```sql
-- 创建加密密钥
SELECT sm4_generate_key() as encryption_key;

-- 设置加密密钥
ALTER SYSTEM SET encryption_key = 'your_key_here';
```

## SSL/TLS配置

### 生成国密证书

```bash
# 生成SM2私钥
gmssl genpkey -algorithm SM2 -out server.key

# 生成证书签名请求
gmssl req -new -key server.key -out server.csr

# 自签名证书
gmssl req -x509 -key server.key -days 365 -out server.crt
```

### 配置SSL

在postgresql.conf中添加：

```conf
# 启用SSL
ssl = on
ssl_cert_file = '/etc/cnmd/server.crt'
ssl_key_file = '/etc/cnmd/server.key'

# 国密SSL套件
ssl_ciphers = 'SM4-GCM-SM3'

# TLCP协议（可选）
ssl_protocols = 'tlcp1.1'
```

### 客户端连接

```bash
# 使用gmssl客户端连接
gmssl s_client -connect localhost:5432

# 使用psql连接
psql "host=localhost port=5432 sslmode=require"
```

## 性能优化

### SM4硬件加速

在支持AES-NI的CPU上，SM4可以使用硬件加速。

```conf
# 启用硬件加速
sm4_use_aesni = on
```

### 批量加密

```sql
-- 批量加密数据
UPDATE table_name 
SET encrypted_column = sm4_encrypt(original_column, 'key', 'iv')
WHERE id IN (SELECT id FROM table_name WHERE needs_encryption = true);
```

## 安全建议

1. **密钥管理**：使用安全的密钥管理系统
2. **定期轮换**：定期轮换加密密钥
3. **访问控制**：限制对加密函数的访问权限
4. **审计日志**：启用加密操作的审计日志
5. **备份策略**：确保备份包含密钥信息

## 合规标准

CNMD国密算法实现符合以下标准：

- **GM/T 0003-2012**：SM2密码算法
- **GM/T 0004-2012**：SM3密码算法
- **GM/T 0002-2012**：SM4密码算法
- **GB/T 32905-2016**：SM3密码算法
- **GB/T 32907-2016**：SM4密码算法

## 故障排除

### 常见问题

1. **GmSSL未安装**
   ```
   ERROR: SM3算法需要GmSSL支持
   ```
   解决方案：安装GmSSL库并重新编译CNMD

2. **密钥长度错误**
   ```
   ERROR: SM4密钥长度必须为16字节
   ```
   解决方案：确保密钥长度为16字节（128位）

3. **SSL证书错误**
   ```
   ERROR: SSL证书无效
   ```
   解决方案：重新生成有效的SM2证书

### 日志检查

```bash
# 查看数据库日志
tail -f /var/log/cnmd/cnmd.log

# 查看审计日志
tail -f /var/log/cnmd/audit.log
```
