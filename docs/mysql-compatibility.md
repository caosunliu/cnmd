# CNMD MySQL兼容性说明

本文档介绍CNMD数据库的MySQL兼容模式功能。

## 概述

CNMD提供了MySQL兼容模式，允许用户使用MySQL语法和客户端工具连接CNMD数据库，降低从MySQL迁移到CNMD的难度。

## 启用MySQL兼容模式

### 方法1：会话级别

```sql
SET cnmd.compatibility_mode = 'mysql';
```

### 方法2：用户级别

```sql
ALTER ROLE username SET cnmd.compatibility_mode = 'mysql';
```

### 方法3：数据库级别

```sql
ALTER DATABASE dbname SET cnmd.compatibility_mode = 'mysql';
```

### 方法4：全局级别

在postgresql.conf中设置：

```conf
cnmd.compatibility_mode = 'mysql'
```

## 支持的MySQL语法

### SHOW命令

```sql
-- 显示数据库
SHOW DATABASES;

-- 显示表
SHOW TABLES;

-- 显示列
SHOW COLUMNS FROM table_name;

-- 显示索引
SHOW INDEX FROM table_name;

-- 显示状态
SHOW STATUS;

-- 显示变量
SHOW VARIABLES;

-- 显示进程
SHOW PROCESSLIST;
```

### DESCRIBE/DESC命令

```sql
-- 描述表结构
DESCRIBE table_name;
DESC table_name;
```

### SELECT @@变量

```sql
-- 查询系统变量
SELECT @@sql_mode;
SELECT @@version;
SELECT @@autocommit;
```

### INSERT语法

```sql
-- INSERT IGNORE（忽略重复键错误）
INSERT IGNORE INTO table_name (id, name) VALUES (1, 'test');

-- INSERT ... ON DUPLICATE KEY UPDATE
INSERT INTO table_name (id, name) VALUES (1, 'test')
ON DUPLICATE KEY UPDATE name = 'updated';
```

### REPLACE语法

```sql
-- REPLACE INTO（替换现有记录）
REPLACE INTO table_name (id, name) VALUES (1, 'test');
```

### LIMIT语法

```sql
-- MySQL风格的LIMIT
SELECT * FROM table_name LIMIT 10, 20;  -- 跳过10行，返回20行

-- 等价于PostgreSQL语法
SELECT * FROM table_name LIMIT 20 OFFSET 10;
```

### 其他语法

```sql
-- IFNULL函数
SELECT IFNULL(column_name, 'default') FROM table_name;

-- GROUP_CONCAT函数
SELECT GROUP_CONCAT(name) FROM table_name;

-- NOW函数
SELECT NOW();
```

## 支持的MySQL数据类型

| MySQL类型 | CNMD类型 | 说明 |
|-----------|----------|------|
| TINYINT | SMALLINT | -128到127 |
| MEDIUMINT | INTEGER | -2147483648到2147483647 |
| DATETIME | TIMESTAMP | 日期时间 |
| TEXT | TEXT | 文本数据 |
| BLOB | BYTEA | 二进制数据 |
| LONGTEXT | TEXT | 长文本 |
| LONGBLOB | BYTEA | 长二进制数据 |
| ENUM | TEXT | 枚举类型 |
| SET | TEXT | 集合类型 |

## 支持的MySQL函数

### 日期函数

```sql
-- NOW() -> CURRENT_TIMESTAMP
SELECT NOW();

-- CURDATE() -> CURRENT_DATE
SELECT CURDATE();

-- CURTIME() -> CURRENT_TIME
SELECT CURTIME();

-- DATE_FORMAT() -> TO_CHAR()
SELECT DATE_FORMAT(now(), '%Y-%m-%d');
```

### 字符串函数

```sql
-- IFNULL() -> COALESCE()
SELECT IFNULL(column_name, 'default');

-- CONCAT() -> || 或 CONCAT()
SELECT CONCAT(first_name, ' ', last_name);

-- SUBSTRING() -> SUBSTRING()
SELECT SUBSTRING(column_name, 1, 10);
```

### 聚合函数

```sql
-- GROUP_CONCAT() -> STRING_AGG()
SELECT GROUP_CONCAT(name SEPARATOR ', ');

-- 等价于PostgreSQL语法
SELECT STRING_AGG(name, ', ');
```

## MySQL客户端连接

### 使用MySQL客户端

```bash
# 使用MySQL客户端连接
mysql -h localhost -P 5432 -U postgres -D postgres

# 使用MySQL Workbench连接
# 主机: localhost
# 端口: 5432
# 用户: postgres
# 密码: ***
```

### 连接参数

```bash
# 设置连接参数
SET client_encoding = 'UTF8';
SET client_min_messages = 'notice';
SET standard_conforming_strings = 'on';
```

## 限制和注意事项

### 不支持的MySQL特性

1. **存储过程**：MySQL存储过程语法与PostgreSQL不兼容
2. **触发器**：MySQL触发器语法与PostgreSQL不兼容
3. **事件调度器**：MySQL事件调度器与PostgreSQL不兼容
4. **自增列**：MySQL AUTO_INCREMENT与PostgreSQL SERIAL不完全兼容

### 性能考虑

1. **兼容模式开销**：启用兼容模式会增加一定的性能开销
2. **查询优化**：某些MySQL风格的查询可能无法充分利用PostgreSQL优化器

### 迁移建议

1. **测试环境**：先在测试环境验证兼容性
2. **逐步迁移**：逐步迁移应用，避免一次性切换
3. **性能测试**：进行性能测试，确保满足业务需求

## 示例应用

### Python应用示例

```python
import mysql.connector

# 连接CNMD数据库
config = {
    'host': 'localhost',
    'port': 5432,
    'user': 'postgres',
    'password': 'password',
    'database': 'postgres'
}

conn = mysql.connector.connect(**config)
cursor = conn.cursor()

# 执行MySQL风格的查询
cursor.execute("SHOW TABLES")
tables = cursor.fetchall()

# 使用LIMIT语法
cursor.execute("SELECT * FROM table_name LIMIT 10, 20")
rows = cursor.fetchall()

conn.close()
```

### Java应用示例

```java
import java.sql.*;

public class CNMDExample {
    public static void main(String[] args) throws Exception {
        // 连接CNMD数据库
        String url = "jdbc:mysql://localhost:5432/postgres";
        String user = "postgres";
        String password = "password";
        
        Connection conn = DriverManager.getConnection(url, user, password);
        Statement stmt = conn.createStatement();
        
        // 执行MySQL风格的查询
        ResultSet rs = stmt.executeQuery("SHOW TABLES");
        while (rs.next()) {
            System.out.println(rs.getString(1));
        }
        
        conn.close();
    }
}
```
