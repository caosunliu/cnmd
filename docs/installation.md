# CNMD 安装指南

本文档介绍如何安装和配置CNMD数据库服务器。

## 系统要求

### 硬件要求

- **CPU**：x86_64 / ARM64 / LoongArch
- **内存**：最低2GB，推荐8GB+
- **磁盘**：最低20GB，推荐100GB+
- **网络**：100Mbps+

### 软件要求

- **操作系统**：
  - 银河麒麟V10 SP1+
  - 统信UOS 20+
  - openEuler 22.03+
  - CentOS 7+
  - Ubuntu 20.04+

- **编译工具**：
  - GCC 9.0+ / Clang 12.0+
  - CMake 3.16+
  - Make

- **依赖库**：
  - GmSSL 3.2.0
  - zlib 1.2+
  - libxml2 2.9+
  - libxslt 1.1+
  - OpenSSL 1.1+

## 编译安装

### 1. 获取源码

```bash
git clone https://github.com/your-repo/cnmd.git
cd cnmd
```

### 2. 编译GmSSL

```bash
./scripts/build-gmssl.sh 3.2.0
```

### 3. 编译CNMD

```bash
./scripts/build-cnmd.sh --prefix=/usr/local/cnmd
```

### 4. 安装CNMD

```bash
sudo ./scripts/install-cnmd.sh --prefix=/usr/local/cnmd
```

## Docker安装

### 1. 构建Docker镜像

```bash
cd docker
docker-compose build
```

### 2. 启动容器

```bash
docker-compose up -d
```

### 3. 连接数据库

```bash
docker exec -it cnmd-server /usr/local/cnmd/bin/cnmd-psql -U postgres
```

## 配置

### 主要配置文件

- **postgresql.conf**：主配置文件
- **pg_hba.conf**：客户端认证配置

### 启用国密算法

在postgresql.conf中添加：

```conf
# 启用SSL
ssl = on
ssl_cert_file = '/etc/cnmd/server.crt'
ssl_key_file = '/etc/cnmd/server.key'

# 国密算法配置
ssl_ciphers = 'SM4-GCM-SM3'
sm2_curve = 'sm2p256v1'
sm4_mode = 'cbc'
```

### 启用MySQL兼容模式

在postgresql.conf中添加：

```conf
cnmd.compatibility_mode = 'mysql'
```

### 启用安全审计

在postgresql.conf中添加：

```conf
audit_log = on
audit_log_file = '/var/log/cnmd/audit.log'
audit_log_statement = 'all'
```

## 验证安装

### 检查版本

```bash
cnmd --version
```

### 连接测试

```bash
cnmd-psql -U postgres -c "SELECT version();"
```

### 功能测试

```bash
./scripts/test-gm-crypto.sh
```

## 故障排除

### 常见问题

1. **编译失败**
   - 检查依赖库是否安装
   - 检查GCC版本是否满足要求

2. **启动失败**
   - 检查日志文件
   - 检查端口是否被占用

3. **连接失败**
   - 检查pg_hba.conf配置
   - 检查防火墙设置

### 日志文件

- **数据库日志**：/var/log/cnmd/cnmd.log
- **审计日志**：/var/log/cnmd/audit.log

## 卸载

```bash
# 停止服务
sudo systemctl stop cnmd

# 删除文件
sudo rm -rf /usr/local/cnmd
sudo rm -rf /var/lib/cnmd
sudo rm -rf /var/log/cnmd
sudo rm -rf /etc/cnmd

# 删除用户
sudo userdel -r cnmd
```
