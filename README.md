# CNMD - 国产信创数据库服务器

基于PostgreSQL 18二次开发，满足信创要求的国产数据库服务器软件。

## 项目简介

CNMD（**C**hinese **N**ational **M**anaged **D**atabase）是一个基于PostgreSQL 18深度定制的国产信创数据库，旨在提供完全自主可控、安全可靠的数据库解决方案。

## 核心特性

### 国密算法支持
- **SM2**：非对称加密/签名算法，替代RSA/ECDSA
- **SM3**：哈希摘要算法，替代SHA-256/MD5
- **SM4**：对称加密算法，替代AES/DES
- 基于GmSSL 3.2.0集成，符合GM/T标准

### MySQL兼容模式
- 支持MySQL协议兼容
- 支持MySQL语法兼容
- 支持MySQL数据类型映射
- 支持MySQL客户端工具连接

### 国产平台适配
- **CPU架构**：龙芯(LoongArch)、飞腾(Phytium)、鲲鹏(Kunpeng)、海光(Hygon)
- **操作系统**：银河麒麟(Kylin)、统信UOS、欧拉(openEuler)

### 安全增强
- 透明数据加密（TDE）支持国密算法
- 安全审计日志（符合GB/T 20274标准）
- 细粒度访问控制（RBAC增强）
- 密码策略强化

## 版本信息

- **当前版本**：1.0.0
- **基础版本**：PostgreSQL 18.6
- **许可证**：Apache License 2.0

## 快速开始

### 环境要求

- 操作系统：银河麒麟V10 / 统信UOS / openEuler 22.03+
- CPU架构：x86_64 / ARM64 / LoongArch
- 编译工具：GCC 9.0+ / Clang 12.0+
- 依赖库：GmSSL 3.2.0、zlib、libxml2

### 编译安装

```bash
# 1. 克隆源码
git clone https://github.com/your-repo/cnmd.git
cd cnmd

# 2. 编译GmSSL
scripts/build-gmssl.sh

# 3. 编译CNMD
scripts/build-cnmd.sh

# 4. 安装
sudo scripts/install-cnmd.sh

# 5. 初始化数据库
cnmd-initdb -D /var/lib/cnmd/data

# 6. 启动服务
cnmd-pg_ctl start -D /var/lib/cnmd/data
```

### 使用MySQL兼容模式

```bash
# 连接数据库
cnmd-psql -U postgres

# 启用MySQL兼容模式
SET cnmd.compatibility_mode = 'mysql';

# 使用MySQL语法
SHOW TABLES;
SELECT @@sql_mode;
```

### 使用国密算法

```sql
-- 使用SM3哈希
SELECT sm3_hash('hello world');

-- 使用SM4加密
SELECT sm4_encrypt('sensitive data', 'key');

-- 使用SM2签名
SELECT sm2_sign('message', 'private_key');
```

## 项目结构

```
cnmd/
├── src/                    # PostgreSQL源码目录
├── docs/                   # 文档目录
├── scripts/                # 构建脚本
├── patches/                # 补丁文件
├── config/                 # 配置文件
├── contrib/                # 额外贡献模块
├── docker/                 # Docker构建环境
├── README.md               # 项目说明
├── LICENSE                 # 许可证
├── VERSION                 # 版本号
└── .gitignore              # Git忽略文件
```

## 开发指南

### 代码规范

- 遵循PostgreSQL编码规范
- 使用C99标准
- 支持多架构编译

### 构建系统

- 使用Make/Autoconf构建
- 支持Docker容器化构建
- 支持多平台交叉编译

### 测试

```bash
# 运行功能测试
make check

# 运行安全测试
make security-check

# 运行性能测试
make benchmark
```

## 文档

- [安装指南](docs/installation.md)
- [用户手册](docs/user-guide.md)
- [开发者文档](docs/developer-guide.md)
- [安全指南](docs/security-guide.md)
- [MySQL兼容性说明](docs/mysql-compatibility.md)
- [国密算法说明](docs/gm-crypto.md)

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork本仓库
2. 创建特性分支
3. 提交更改
4. 推送到分支
5. 创建Pull Request

## 许可证

本项目采用Apache License 2.0许可证，详见[LICENSE](LICENSE)文件。

## 联系方式

- 项目主页：https://github.com/your-repo/cnmd
- 问题反馈：https://github.com/your-repo/cnmd/issues
- 邮箱：contact@cnmd-db.com

## 致谢

- PostgreSQL全球开发组
- GmSSL项目（北京大学）
- 信创产业联盟
