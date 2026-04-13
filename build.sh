#!/bin/bash

# MenuTerm 构建脚本

set -e

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 默认配置
CONFIG="${CONFIG:-Debug}"
CLEAN="${CLEAN:-false}"
ARCHIVE="${ARCHIVE:-false}"

# 构建配置
PROJECT="MenuTerm.xcodeproj"
SCHEME="MenuTerm"
BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 打印用法
usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -c, --config CONFIG    构建配置: Debug 或 Release (默认: Debug)"
    echo "  -C, --clean            清理构建"
    echo "  -a, --archive          创建归档"
    echo "  -h, --help             显示帮助"
    echo ""
    echo "环境变量:"
    echo "  CONFIG=Release         等同于 -c Release"
    echo "  CLEAN=true             等同于 -C"
    echo "  ARCHIVE=true           等同于 -a"
    echo ""
    echo "示例:"
    echo "  $0                    # 构建 Debug"
    echo "  $0 -c Release         # 构建 Release"
    echo "  $0 -c Release -C      # 清理并构建 Release"
    echo "  CONFIG=Release $0      # 构建 Release (环境变量)"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG="$2"
            shift 2
            ;;
        -C|--clean)
            CLEAN=true
            shift
            ;;
        -a|--archive)
            ARCHIVE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# 验证配置
if [[ "$CONFIG" != "Debug" && "$CONFIG" != "Release" ]]; then
    echo -e "${RED}错误: CONFIG 必须是 Debug 或 Release${NC}"
    exit 1
fi

# 打印构建信息
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}MenuTerm 构建脚本${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo "配置:    $CONFIG"
echo "清理:    $CLEAN"
echo "归档:    $ARCHIVE"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

# 构建
if [[ "$ARCHIVE" == "true" ]]; then
    # 归档构建
    ARCHIVE_PATH="$BUILD_DIR/MenuTerm.xcarchive"

    echo "创建归档..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIG" \
        -derivedDataPath "$DERIVED_DATA" \
        -archivePath "$ARCHIVE_PATH" \
        CLEAN=$CLEAN

    # 复制 .app
    APP_PATH="$BUILD_DIR/MenuTerm.app"
    rm -rf "$APP_PATH"
    cp -R "$ARCHIVE_PATH/Products/Applications/MenuTerm.app" "$APP_PATH"

    echo ""
    echo -e "${GREEN}✓ 构建成功!${NC}"
    echo "App: $APP_PATH"
    echo "Archive: $ARCHIVE_PATH"

else
    # 普通构建
    echo "构建 $CONFIG..."
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIG" \
        -derivedDataPath "$DERIVED_DATA" \
        CLEAN=$CLEAN

    # 复制 .app
    APP_PATH="$BUILD_DIR/$CONFIG/MenuTerm.app"
    rm -rf "$APP_PATH"
    mkdir -p "$(dirname "$APP_PATH")"
    cp -R "$DERIVED_DATA/Build/Products/$CONFIG/MenuTerm.app" "$APP_PATH"

    echo ""
    echo -e "${GREEN}✓ 构建成功!${NC}"
    echo "App: $APP_PATH"
fi
