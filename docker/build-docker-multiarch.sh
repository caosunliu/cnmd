#!/bin/bash
#
# build-docker-multiarch.sh - Docker多架构构建脚本
#
# 支持架构: amd64, arm64, loongarch64
#
# 用法: ./build-docker-multiarch.sh [选项]
#   --arch ARCH      指定架构 (默认: 本机架构)
#   --push           推送到镜像仓库
#   --tag TAG        指定标签 (默认: latest)
#   -h, --help       显示帮助
#

set -e

# 默认参数
ARCH=""
PUSH=false
TAG="latest"
REGISTRY="cnmd"
IMAGE_NAME="cnmd-db"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --arch ARCH      指定架构 (默认: 本机架构)"
            echo "  --push           推送到镜像仓库"
            echo "  --tag TAG        指定标签 (默认: latest)"
            echo "  -h, --help       显示帮助"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 检测本机架构
if [ -z "${ARCH}" ]; then
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)       echo "不支持的架构: ${ARCH}"; exit 1 ;;
    esac
fi

echo "=========================================="
echo "  CNMD Docker多架构构建"
echo "  目标架构: ${ARCH}"
echo "  镜像标签: ${REGISTRY}/${IMAGE_NAME}:${TAG}"
echo "=========================================="

# 检查Docker是否可用
if ! command -v docker &> /dev/null; then
    echo "[错误] 未找到Docker命令"
    exit 1
fi

# 检查Docker Buildx是否可用
if ! docker buildx version &> /dev/null; then
    echo "[错误] 未找到Docker Buildx，请安装Docker Buildx插件"
    exit 1
fi

# 创建buildx构建器（如果不存在）
BUILDER_NAME="cnmd-builder"
if ! docker buildx inspect "${BUILDER_NAME}" &> /dev/null; then
    echo "[信息] 创建buildx构建器..."
    docker buildx create --name "${BUILDER_NAME}" --use
else
    echo "[信息] 使用已存在的buildx构建器"
    docker buildx use "${BUILDER_NAME}"
fi

# 构建参数
BUILD_ARGS=(
    --platform "linux/${ARCH}"
    --tag "${REGISTRY}/${IMAGE_NAME}:${TAG}-${ARCH}"
    --file "${SCRIPT_DIR}/Dockerfile"
    "${PROJECT_ROOT}"
)

# 如果需要推送，添加push参数
if [ "${PUSH}" = true ]; then
    BUILD_ARGS+=(--push)
else
    BUILD_ARGS+=(--load)
fi

# 执行构建
echo ""
echo "[信息] 开始构建Docker镜像..."
docker buildx build "${BUILD_ARGS[@]}"

echo ""
echo "=========================================="
echo "  构建完成!"
echo "  镜像: ${REGISTRY}/${IMAGE_NAME}:${TAG}-${ARCH}"
echo "=========================================="

# 如果是本地构建，显示镜像信息
if [ "${PUSH}" = false ]; then
    echo ""
    echo "[信息] 本地镜像:"
    docker images "${REGISTRY}/${IMAGE_NAME}"
fi
