# ============================================
# CNMD 多架构构建环境 Dockerfile
# 支持: linux/amd64, linux/arm64, linux/loongarch64
# ============================================

# 基础镜像 - 使用Ubuntu作为构建环境
FROM ubuntu:22.04 AS builder

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 安装构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    git \
    wget \
    curl \
    pkg-config \
    libreadline-dev \
    zlib1g-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libsystemd-dev \
    libicu-dev \
    uuid-dev \
    flex \
    bison \
    python3 \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /build

# 复制项目文件
COPY . /build/cnmd

# 设置脚本执行权限
RUN chmod +x /build/cnmd/scripts/*.sh

# 创建构建入口点脚本
RUN echo '#!/bin/bash\n\
set -e\n\
echo "==========================================="\n\
echo "  CNMD 多架构构建环境"\n\
echo "  目标架构: $(uname -m)"\n\
echo "==========================================="\n\
exec "$@"' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
