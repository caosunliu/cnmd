# CNMD MySQL兼容模式补丁

本补丁为PostgreSQL添加MySQL兼容模式支持。

## 功能特性

1. **协议兼容**
   - 支持MySQL客户端协议连接
   - 支持MySQL身份验证方式

2. **语法兼容**
   - SHOW TABLES/DATABASES/COLUMNS
   - DESCRIBE/DESC table
   - SELECT @@variable
   - INSERT IGNORE
   - REPLACE INTO
   - LIMIT offset, count 语法

3. **数据类型映射**
   - TINYINT -> SMALLINT
   - MEDIUMINT -> INTEGER
   - DATETIME -> TIMESTAMP
   - TEXT -> TEXT
   - BLOB -> BYTEA

4. **函数兼容**
   - NOW() -> CURRENT_TIMESTAMP
   - IFNULL() -> COALESCE()
   - GROUP_CONCAT() -> STRING_AGG()

## 安装

补丁会在编译时自动应用，无需手动安装。

## 配置

在postgresql.conf中添加：

```
cnmd.compatibility_mode = 'mysql'
```

## 使用示例

```sql
-- 启用MySQL兼容模式
SET cnmd.compatibility_mode = 'mysql';

-- 使用MySQL语法
SHOW TABLES;
SHOW DATABASES;
DESCRIBE my_table;
SELECT @@sql_mode;

-- MySQL风格的INSERT
INSERT IGNORE INTO my_table (id, name) VALUES (1, 'test');

-- MySQL风格的LIMIT
SELECT * FROM my_table LIMIT 10, 20;
```
