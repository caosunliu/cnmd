#!/bin/bash
#
# build-all-architectures.sh - 构建所有支持架构的Docker镜像
#
# 用法: ./build-all-architectures.sh [选项]
#   --push           推送到镜像仓库
#   --tag TAG        指定标签 (默认: latest)
#   -h, --help       显示帮助
#

set -e

# 默认参数
PUSH=false
TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
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

echo "=========================================="
echo "  CNMD 全架构Docker构建"
echo "=========================================="

# 支持的架构列表
ARCHITECTURES=(
    "amd64"
    "arm64"
)

# 构建每个架构
for ARCH in "${ARCHITECTURES[@]}"; do
    echo ""
    echo "-------------------------------------------"
    echo "  构建架构: ${ARCH}"
    echo "-------------------------------------------"
    
    BUILD_CMD="${SCRIPT_DIR}/build-docker-multiarch.sh --arch ${ARCH} --tag ${TAG}"
    
    if [ "${PUSH}" = true ]; then
        BUILD_CMD="${BUILD_CMD} --push"
    fi
    
    eval "${BUILD_CMD}"
done

echo ""
echo "=========================================="
echo "  所有架构构建完成!"
echo "=========================================="

# 显示所有构建的镜像
echo ""
echo "[信息] 所有构建的镜像:"
docker images "cnmd/cnmd-db" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
