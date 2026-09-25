# CNMD 安全指南

本文档介绍CNMD数据库的安全特性和配置方法。

## 概述

CNMD提供了多层次的安全保护机制，包括身份认证、访问控制、数据加密、审计日志等，满足信创环境下的安全要求。

## 身份认证

### 密码认证

CNMD支持多种密码认证方式：

1. **SM3密码哈希**：使用国密SM3算法进行密码哈希
2. **SCRAM-SHA-256**：标准的SCRAM认证方式
3. **MD5**：传统的MD5认证（不推荐）

配置密码认证：

```conf
# 在postgresql.conf中设置
password_encryption = sm3  # 或 scram-sha-256
```

### SSL证书认证

使用SM2证书进行客户端认证：

```conf
# 在postgresql.conf中设置
ssl = on
ssl_cert_file = '/etc/cnmd/server.crt'
ssl_key_file = '/etc/cnmd/server.key'
ssl_ca_file = '/etc/cnmd/ca.crt'
```

在pg_hba.conf中配置证书认证：

```
# 使用证书认证
hostssl all all 0.0.0.0/0 cert
```

### LDAP认证

集成LDAP/AD进行用户认证：

```conf
# 在pg_hba.conf中配置
host all all 192.168.1.0/24 ldap ldapserver=ldap.example.com ldapbasedn="dc=example,dc=com"
```

## 访问控制

### 基于角色的访问控制(RBAC)

```sql
-- 创建角色
CREATE ROLE readonly;
CREATE ROLE readwrite;
CREATE ROLE admin;

-- 授权
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO readwrite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;

-- 创建用户并分配角色
CREATE USER user1 WITH PASSWORD 'password1';
CREATE USER user2 WITH PASSWORD 'password2';

GRANT readonly TO user1;
GRANT readwrite TO user2;
```

### 行级安全策略

```sql
-- 启用行级安全
ALTER TABLE sensitive_data ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY user_isolation ON sensitive_data
    USING (user_name = current_user);

-- 测试策略
SET ROLE user1;
SELECT * FROM sensitive_data;  -- 只能看到user1的数据
RESET ROLE;
```

### 列级权限控制

```sql
-- 授予列级权限
GRANT SELECT (id, name) ON TABLE users TO user1;
GRANT SELECT (id, email) ON TABLE users TO user2;

-- 撤销列级权限
REVOKE SELECT (email) ON TABLE users FROM user2;
```

## 数据加密

### 透明数据加密(TDE)

```sql
-- 创建加密表
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    data TEXT
) WITH (encryption = true);

-- 查看加密表
SELECT * FROM pg_encrypted_tables;
```

### 列级加密

```sql
-- 使用SM4加密列数据
INSERT INTO sensitive_data (id, data) 
VALUES (1, sm4_encrypt('敏感数据', 'key', 'iv'));

-- 解密数据
SELECT sm4_decrypt(data, 'key', 'iv') FROM sensitive_data WHERE id = 1;
```

### SSL/TLS加密传输

```conf
# 在postgresql.conf中配置SSL
ssl = on
ssl_cert_file = '/etc/cnmd/server.crt'
ssl_key_file = '/etc/cnmd/server.key'

# 使用国密SSL套件
ssl_ciphers = 'SM4-GCM-SM3'
```

## 审计日志

### 启用审计

```conf
# 在postgresql.conf中配置
audit_log = on
audit_log_file = '/var/log/cnmd/audit.log'
audit_log_statement = 'all'
```

### 审计事件类型

1. **连接事件**：用户登录/登出
2. **DDL事件**：CREATE/ALTER/DROP
3. **DML事件**：SELECT/INSERT/UPDATE/DELETE
4. **DCL事件**：GRANT/REVOKE
5. **安全事件**：密码修改、权限变更

### 查询审计日志

```sql
-- 查看审计日志表
SELECT * FROM pg_audit_log ORDER BY event_time DESC;

-- 按用户查询
SELECT * FROM pg_audit_log WHERE user_name = 'user1';

-- 按时间查询
SELECT * FROM pg_audit_log WHERE event_time > NOW() - INTERVAL '1 day';
```

## 密码策略

### 密码复杂度要求

```conf
# 在postgresql.conf中配置
password_min_length = 8
password_require_uppercase = on
password_require_lowercase = on
password_require_digit = on
password_require_special = on
```

### 密码有效期

```conf
# 设置密码有效期（天）
password_max_age = 90
password_warning_days = 14
```

### 密码历史

```conf
# 记录密码历史
password_history = 5
```

### 账户锁定

```conf
# 登录失败锁定
password_lock_threshold = 5
password_lock_duration = 30
```

## 会话管理

### 会话超时

```conf
# 语句执行超时（秒）
statement_timeout = 300

# 空闲事务超时（秒）
idle_in_transaction_session_timeout = 60

# 空闲会话超时（秒）
idle_session_timeout = 600
```

### 并发连接限制

```conf
# 最大连接数
max_connections = 100

# 每用户最大连接数
max_connections_per_user = 10
```

## 网络安全

### 防火墙配置

```bash
# 开放端口
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload

# 限制IP访问
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="5432" protocol="tcp" accept'
```

### pg_hba.conf配置

```
# 只允许特定IP段访问
host all all 192.168.1.0/24 scram-sha-256

# 只允许SSL连接
hostssl all all 0.0.0.0/0 scram-sha-256

# 拒绝所有其他连接
host all all 0.0.0.0/0 reject
```

## 备份安全

### 加密备份

```bash
# 使用gpg加密备份
pg_dumpall | gpg -c > backup.sql.gpg

# 还原备份
gpg -d backup.sql.gpg | psql
```

### 安全存储

```bash
# 使用加密文件系统存储备份
sudo cryptsetup luksFormat /dev/sdb1
sudo cryptsetup open /dev/sdb1 backup_encrypted
sudo mkfs.ext4 /dev/mapper/backup_encrypted
sudo mount /dev/mapper/backup_encrypted /mnt/backup
```

## 合规标准

CNMD安全特性符合以下标准：

- **GB/T 20274.2-2026**：信息系统安全保障评估框架
- **GB/T 22239-2019**：信息安全技术网络安全等级保护基本要求
- **GM/T 0054-2018**：信息系统密码应用基本要求

## 安全检查清单

### 部署前检查

- [ ] 修改默认密码
- [ ] 配置SSL/TLS
- [ ] 启用审计日志
- [ ] 配置防火墙
- [ ] 限制网络访问
- [ ] 备份密钥和证书

### 运行时检查

- [ ] 监控审计日志
- [ ] 定期轮换密钥
- [ ] 检查账户权限
- [ ] 更新安全补丁
- [ ] 验证备份完整性

## 故障排除

### 常见安全问题

1. **密码暴力破解**
   - 启用账户锁定
   - 配置入侵检测

2. **SQL注入**
   - 使用参数化查询
   - 启用WAF

3. **权限提升**
   - 定期审计权限
   - 使用最小权限原则

### 安全事件响应

1. **检测**：监控异常活动
2. **响应**：隔离受影响系统
3. **恢复**：从备份恢复
4. **总结**：分析事件原因
