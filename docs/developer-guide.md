# CNMD 开发者指南

本文档为CNMD数据库的开发者提供开发指南。

## 项目结构

```
cnmd/
├── src/                    # PostgreSQL源码目录
├── docs/                   # 文档目录
│   ├── installation.md     # 安装指南
│   ├── mysql-compatibility.md  # MySQL兼容性说明
│   ├── gm-crypto.md        # 国密算法说明
│   ├── security-guide.md   # 安全指南
│   └── developer-guide.md  # 开发者指南
├── scripts/                # 构建脚本
│   ├── build-gmssl.sh      # 编译GmSSL
│   ├── build-cnmd.sh       # 编译CNMD
│   ├── build-multiarch.sh  # 多架构编译
│   ├── install-cnmd.sh     # 安装CNMD
│   └── test-gm-crypto.sh   # 测试脚本
├── patches/                # 补丁文件
│   ├── 001-mysql-compat/   # MySQL兼容补丁
│   ├── 002-gm-crypto/      # 国密算法补丁
│   └── 003-security-audit/ # 安全审计补丁
├── config/                 # 配置文件
│   ├── postgresql.conf     # 主配置文件
│   └── pg_hba.conf         # 认证配置文件
├── contrib/                # 贡献模块
│   ├── sm2.c               # SM2算法实现
│   ├── sm3.c               # SM3算法实现
│   ├── sm4.c               # SM4算法实现
│   └── cnmd_security.c     # 安全审计实现
├── docker/                 # Docker构建环境
│   ├── Dockerfile          # Docker镜像定义
│   └── docker-compose.yml  # Docker Compose配置
├── README.md               # 项目说明
├── LICENSE                 # 许可证
├── VERSION                 # 版本号
└── .gitignore              # Git忽略文件
```

## 开发环境搭建

### 1. 克隆项目

```bash
git clone https://github.com/your-repo/cnmd.git
cd cnmd
```

### 2. 安装依赖

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential gcc g++ make cmake git wget curl \
    libreadline-dev zlib1g-dev libssl-dev libxml2-dev libxslt1-dev \
    libsystemd-dev libicu-dev uuid-dev flex bison python3

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install readline-devel zlib-devel openssl-devel libxml2-devel \
    libxslt-devel systemd-devel libuuid-devel flex bison python3
```

### 3. 编译GmSSL

```bash
./scripts/build-gmssl.sh 3.2.0
```

### 4. 编译CNMD

```bash
./scripts/build-cnmd.sh --prefix=/usr/local/cnmd --debug
```

## 代码规范

### C代码规范

1. **遵循PostgreSQL编码规范**
2. **使用C99标准**
3. **支持多架构编译**
4. **添加必要的注释**

### 代码风格

```c
/*
 * 函数注释
 */
DataType
function_name(TypeArg1 arg1, TypeArg2 arg2)
{
    /* 变量声明 */
    DataType result;
    
    /* 代码逻辑 */
    if (condition)
    {
        result = value1;
    }
    else
    {
        result = value2;
    }
    
    return result;
}
```

### 命名规范

- **函数名**：小写字母加下划线
- **变量名**：小写字母加下划线
- **常量名**：大写字母加下划线
- **类型名**：大驼峰命名

## 开发流程

### 1. 创建特性分支

```bash
git checkout -b feature/new-feature
```

### 2. 开发和测试

```bash
# 编译
make clean && make -j$(nproc)

# 运行测试
make check

# 运行特定测试
make installcheck SUBDIRS="contrib/pgcrypto"
```

### 3. 提交代码

```bash
git add .
git commit -m "feat: 添加新功能描述"
git push origin feature/new-feature
```

### 4. 创建Pull Request

在GitHub上创建Pull Request，等待代码审查。

## 添加新功能

### 1. 添加新的SQL函数

```c
// 在contrib目录下创建新文件
// contrib/my_function.c

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

PG_FUNCTION_INFO_V1(my_function);

Datum
my_function(PG_FUNCTION_ARGS)
{
    // 函数实现
    PG_RETURN_TEXT_P(cstring_to_text("result"));
}
```

### 2. 更新Makefile

```makefile
# 在contrib/Makefile中添加
MODULES += my_function
```

### 3. 注册函数

```sql
-- 创建SQL函数
CREATE FUNCTION my_function(text) RETURNS text
AS 'my_function', 'my_function'
LANGUAGE C STRICT;
```

### 4. 添加测试

```sql
-- 在sql/目录下创建测试文件
-- sql/my_function.sql
SELECT my_function('test');
```

## 调试技巧

### 使用GDB调试

```bash
# 编译调试版本
./scripts/build-cnmd.sh --debug

# 启动GDB
gdb --args /usr/local/cnmd/bin/cnmd-postgres -D /var/lib/cnmd/data

# 设置断点
(gdb) break main
(gdb) run
```

### 使用Valgrind检测内存泄漏

```bash
valgrind --leak-check=full /usr/local/cnmd/bin/cnmd-postgres -D /var/lib/cnmd/data
```

### 查看日志

```bash
# 数据库日志
tail -f /var/log/cnmd/cnmd.log

# 审计日志
tail -f /var/log/cnmd/audit.log
```

## 性能优化

### 1. 编译优化

```bash
# 使用优化编译选项
CFLAGS="-O2 -march=native" ./scripts/build-cnmd.sh
```

### 2. 配置优化

```conf
# postgresql.conf
shared_buffers = '256MB'
effective_cache_size = '1GB'
work_mem = '16MB'
maintenance_work_mem = '64MB'
```

### 3. 查询优化

```sql
-- 使用EXPLAIN分析查询
EXPLAIN ANALYZE SELECT * FROM large_table WHERE condition;

-- 创建索引
CREATE INDEX idx_column ON table_name(column);
```

## 贡献指南

### 代码审查

所有提交都需要经过代码审查，确保代码质量。

### 测试要求

1. **单元测试**：每个新功能都需要添加单元测试
2. **集成测试**：确保与现有功能兼容
3. **性能测试**：确保性能不会退化

### 文档要求

1. **代码注释**：添加必要的注释
2. **API文档**：更新API文档
3. **用户文档**：更新用户指南

## 常见问题

### 编译失败

```bash
# 检查依赖库
pkg-config --libs openssl

# 检查GCC版本
gcc --version
```

### 测试失败

```bash
# 查看测试输出
make check -v

# 查看日志
cat log/my_function.log
```

### 性能问题

```bash
# 分析查询性能
EXPLAIN ANALYZE SELECT ...

# 查看系统统计
SELECT * FROM pg_stat_activity;
SELECT * FROM pg_stat_user_tables;
```
