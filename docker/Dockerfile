# ============================================
# CNMD 多架构构建Dockerfile
# 支持: x86_64, ARM64, LoongArch
# ============================================

# 基础镜像
FROM ubuntu:22.04 AS builder

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 安装构建依赖
RUN apt-get update && apt-get install -y \
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
    clang \
    flex \
    bison \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /build

# 复制构建脚本
COPY scripts/ /build/scripts/
COPY patches/ /build/patches/
COPY config/ /build/config/

# 构建GmSSL
RUN chmod +x /build/scripts/build-gmssl.sh && \
    /build/scripts/build-gmssl.sh 3.2.0

# 获取PostgreSQL源码
RUN git clone --branch REL_18_6 --depth 1 \
    https://github.com/postgres/postgres.git \
    /build/src/postgresql-18

# 应用CNMD补丁
RUN cd /build/src/postgresql-18 && \
    git apply /build/patches/*.patch 2>/dev/null || true

# 构建CNMD
RUN chmod +x /build/scripts/build-cnmd.sh && \
    /build/scripts/build-cnmd.sh --prefix=/usr/local/cnmd

# ============================================
# 运行时镜像
# ============================================
FROM ubuntu:22.04 AS runtime

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libreadline8 \
    zlib1g \
    libssl3 \
    libxml2 \
    libxslt1.1 \
    libsystemd0 \
    libicu70 \
    uuid-runtime \
    locales \
    && rm -rf /var/lib/apt/lists/*

# 设置locale
RUN locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8

# 从构建镜像复制安装文件
COPY --from=builder /usr/local/cnmd /usr/local/cnmd
COPY --from=builder /usr/local/gmssl /usr/local/gmssl

# 设置环境变量
ENV PATH="/usr/local/cnmd/bin:/usr/local/gmssl/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cnmd/lib:/usr/local/gmssl/lib:${LD_LIBRARY_PATH}"

# 创建用户和目录
RUN groupadd -r cnmd && \
    useradd -r -g cnmd -d /var/lib/cnmd -s /bin/bash cnmd && \
    mkdir -p /var/lib/cnmd/data /var/log/cnmd /var/run/cnmd /etc/cnmd && \
    chown -R cnmd:cnmd /var/lib/cnmd /var/log/cnmd /var/run/cnmd /etc/cnmd

# 复制配置文件
COPY config/postgresql.conf /etc/cnmd/postgresql.conf
COPY config/pg_hba.conf /etc/cnmd/pg_hba.conf

# 设置数据目录权限
VOLUME ["/var/lib/cnmd/data"]

# 暴露端口
EXPOSE 5432

# 设置工作目录
WORKDIR /var/lib/cnmd

# 切换用户
USER cnmd

# 启动命令
ENTRYPOINT ["/usr/local/cnmd/bin/cnmd-pg_ctl"]
CMD ["start", "-D", "/var/lib/cnmd/data", "-l", "/var/log/cnmd/cnmd.log"]
