#!/bin/bash

# MenuTerm 构建脚本

set -e

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 构建配置
PROJECT="MenuTerm.xcodeproj"
SCHEME="MenuTerm"
CONFIG="Debug"
BUILD_DIR="build/$CONFIG"
DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"

echo "Building MenuTerm..."
echo "Project: $PROJECT"
echo "Scheme: $SCHEME"
echo "Config: $CONFIG"
echo "Output: $BUILD_DIR"
echo ""

# 使用默认路径构建（避免 SPM 路径问题）
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  build

# 找到 DerivedData 中的构建产物
DERIVED_DATA_DIR=$(find "$DERIVED_DATA_BASE" -type d -name "MenuTerm-*" | head -1)
DEFAULT_BUILD="$DERIVED_DATA_DIR/Build/Products/$CONFIG"

# 复制到本地 build 目录
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -R "$DEFAULT_BUILD"/* "$BUILD_DIR/"

echo ""
echo "Build complete: $BUILD_DIR/MenuTerm.app"
