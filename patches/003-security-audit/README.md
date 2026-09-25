# CNMD 安全审计补丁

本补丁为PostgreSQL添加安全审计功能，符合GB/T 20274标准。

## 功能特性

1. **审计日志**
   - 记录所有数据库操作
   - 支持多种审计事件类型
   - 可配置审计策略

2. **访问控制增强**
   - 基于角色的访问控制(RBAC)
   - 细粒度权限管理
   - 权限继承机制

3. **密码策略**
   - 密码复杂度要求
   - 密码有效期管理
   - 账户锁定策略

4. **会话管理**
   - 会话超时设置
   - 并发连接限制
   - 异常会话检测

## 审计事件类型

1. **连接事件**
   - 用户登录/登出
   - 连接建立/断开
   - 认证成功/失败

2. **操作事件**
   - DDL操作（CREATE, ALTER, DROP）
   - DML操作（SELECT, INSERT, UPDATE, DELETE）
   - DCL操作（GRANT, REVOKE）

3. **安全事件**
   - 权限变更
   - 密码修改
   - 角色变更

4. **系统事件**
   - 数据库启动/停止
   - 配置变更
   - 备份/恢复

## 配置

在postgresql.conf中添加：

```
# 审计配置
audit_log = on
audit_log_file = '/var/log/cnmd/audit.log'
audit_log_statement = 'all'
audit_log_relation = 'pg_audit_log'

# 密码策略
password_min_length = 8
password_max_age = 90
password_history = 5

# 会话管理
statement_timeout = 300
idle_in_transaction_session_timeout = 60
```

## 使用示例

```sql
-- 查看审计日志表
SELECT * FROM pg_audit_log ORDER BY event_time DESC;

-- 配置审计策略
ALTER SYSTEM SET audit_log_statement = 'ddl, dcl';
ALTER SYSTEM SET audit_log_relation = on;

-- 查看当前审计设置
SHOW audit_log;
SHOW audit_log_statement;
```
