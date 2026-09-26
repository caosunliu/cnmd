# CNMD 全量验证报告

**验证时间**: 2026-09-26 11:03:11

## 验证总结

| 项目 | 数量 |
|------|------|
| 总检查项 | 56 |
| 通过 | 56 |
| 失败 | 0 |
| 警告 | 0 |

## 详细结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 目录 src/ | ✅ 通过 | 存在 |
| 目录 docs/ | ✅ 通过 | 存在 |
| 目录 scripts/ | ✅ 通过 | 存在 |
| 目录 patches/ | ✅ 通过 | 存在 |
| 目录 config/ | ✅ 通过 | 存在 |
| 目录 contrib/ | ✅ 通过 | 存在 |
| 目录 docker/ | ✅ 通过 | 存在 |
| 文件 README.md | ✅ 通过 | 存在 |
| 文件 LICENSE | ✅ 通过 | 存在 |
| 文件 VERSION | ✅ 通过 | 存在 |
| 文件 .gitignore | ✅ 通过 | 存在 |
| PostgreSQL源码目录 | ✅ 通过 | 存在 (26 个条目) |
|   postgresql-18/src/ | ✅ 通过 | 存在 |
|   postgresql-18/contrib/ | ✅ 通过 | 存在 |
|   postgresql-18/doc/ | ✅ 通过 | 存在 |
|   postgresql-18/config/ | ✅ 通过 | 存在 |
|   postgresql-18/configure | ✅ 通过 | 存在 |
|   postgresql-18/Makefile | ✅ 通过 | 存在 |
|   postgresql-18/README.md | ✅ 通过 | 存在 |
|   postgresql-18/COPYRIGHT | ✅ 通过 | 存在 |
|   postgresql-18/HISTORY | ✅ 通过 | 存在 |
| 脚本 build.sh | ✅ 通过 | 存在 (7974 字节) |
| 脚本 build-cnmd.sh | ✅ 通过 | 存在 (4889 字节) |
| 脚本 build-gmssl.sh | ✅ 通过 | 存在 (2002 字节) |
| 脚本 build-multiarch.sh | ✅ 通过 | 存在 (3197 字节) |
| 脚本 install-cnmd.sh | ✅ 通过 | 存在 (4657 字节) |
| 脚本 test-gm-crypto.sh | ✅ 通过 | 存在 (2420 字节) |
| 脚本 ci-build.sh | ✅ 通过 | 存在 (5118 字节) |
| 配置 postgresql.conf | ✅ 通过 | 格式正确 |
| 配置 pg_hba.conf | ✅ 通过 | 格式正确 |
| 文档 installation.md | ✅ 通过 | 完整 (2060 字符) |
| 文档 developer-guide.md | ✅ 通过 | 完整 (4665 字符) |
| 文档 security-guide.md | ✅ 通过 | 完整 (4770 字符) |
| 文档 mysql-compatibility.md | ✅ 通过 | 完整 (4318 字符) |
| 文档 gm-crypto.md | ✅ 通过 | 完整 (3372 字符) |
| 补丁 001-mysql-compat.patch | ✅ 通过 | 格式正确 |
| 补丁 002-gm-crypto.patch | ✅ 通过 | 格式正确 |
| 补丁 003-security-audit.patch | ✅ 通过 | 格式正确 |
| 代码 sm3.c | ✅ 通过 | 包含所有必要函数 |
| 代码 sm4.c | ✅ 通过 | 包含所有必要函数 |
| 代码 cnmd_security.c | ✅ 通过 | 包含所有必要函数 |
| Docker Dockerfile | ✅ 通过 | 格式正确 |
| Docker Dockerfile.builder | ✅ 通过 | 格式正确 |
| Docker docker-compose.yml | ✅ 通过 | 存在 |
| Docker docker-compose.dev.yml | ✅ 通过 | 存在 |
| Docker build-docker-multiarch.sh | ✅ 通过 | 存在 |
| Docker build-all-architectures.sh | ✅ 通过 | 存在 |
| GitHub Actions工作流 | ✅ 通过 | 配置正确 |
| 版本号格式 | ✅ 通过 | 有效: 1.0.0 |
| README.md内容 | ✅ 通过 | 包含版本信息和标题 |
| 语法 cnmd_security.c | ✅ 通过 | 语法正确 |
| 语法 sm3.c | ✅ 通过 | 语法正确 |
| 语法 sm4.c | ✅ 通过 | 语法正确 |
| 补丁 001-mysql-compat.patch | ✅ 通过 | 格式正确 |
| 补丁 002-gm-crypto.patch | ✅ 通过 | 格式正确 |
| 补丁 003-security-audit.patch | ✅ 通过 | 格式正确 |

## 结论

✅ **验证通过** - 项目结构完整，代码质量良好
