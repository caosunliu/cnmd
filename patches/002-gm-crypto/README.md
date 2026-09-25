# CNMD 国密算法集成补丁

本补丁将GmSSL国密算法库集成到PostgreSQL中。

## 支持的算法

1. **SM2** - 非对称加密/签名算法
   - 密钥生成
   - 数字签名与验签
   - 公钥加密与解密
   - 密钥交换

2. **SM3** - 哈希摘要算法
   - 消息摘要计算
   - HMAC-SM3
   - 密码哈希

3. **SM4** - 对称加密算法
   - ECB模式
   - CBC模式
   - CTR模式
   - GCM模式

## 功能特性

1. **pgcrypto扩展增强**
   - 添加SM2/SM3/SM4支持
   - 支持国密SSL/TLS
   - 支持国密证书

2. **密码认证增强**
   - SM3密码哈希
   - 国密SSL连接认证

3. **数据加密**
   - 透明数据加密(TDE)支持SM4
   - 列级加密支持SM2/SM4

4. **SSL/TLS支持**
   - TLCP 1.1协议
   - TLS 1.3国密套件

## 安装

补丁会在编译时自动应用，无需手动安装。

## 配置

在postgresql.conf中添加：

```
# 国密算法配置
ssl = on
ssl_ciphers = 'SM4-GCM-SM3'
sm2_curve = 'sm2p256v1'
sm4_mode = 'cbc'
```

## 使用示例

```sql
-- SM3哈希
SELECT sm3_hash('hello world');

-- SM4加密
SELECT sm4_encrypt('sensitive data', 'key');
SELECT sm4_decrypt(sm4_encrypt('data', 'key'), 'key');

-- SM2签名
SELECT sm2_sign('message', 'private_key');
SELECT sm2_verify('signature', 'message', 'public_key');

-- 国密SSL连接
-- 使用gmcrypt工具生成证书
-- gmcrypt genrsa -out server.key 2048
-- gmcrypt req -new -x509 -key server.key -out server.crt
```
