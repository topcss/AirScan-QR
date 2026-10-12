#!/bin/bash
# =================================================================
# ios-cfc-client 命令行一键编译脚本
# =================================================================

set -e

# 颜色设置
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Reset Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODE_PROJ="${PROJECT_DIR}/cfc.xcodeproj"
SCHEME="cfc"
BUILD_DIR="${PROJECT_DIR}/build"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}🚀 ios-cfc-client 命令行编译工具${NC}"
echo -e "${BLUE}======================================================${NC}\n"

# 1. 检查并设置 Xcode 环境
if [ -z "$DEVELOPER_DIR" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

DEVELOPER_DIR_CHECK=$(xcode-select -p 2>/dev/null || echo "")
if [[ "$DEVELOPER_DIR_CHECK" == *"/Library/Developer/CommandLineTools"* ]] && [ -z "$DEVELOPER_DIR" ]; then
    echo -e "${YELLOW}⚠️ 检测到当前的 xcode-select 指向了 CommandLineTools。${NC}"
    echo -e "${YELLOW}💡 脚本已自动为你导出 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer${NC}\n"
fi

MODE="${1:-simulator}"

mkdir -p "${BUILD_DIR}"

if [ "$MODE" == "simulator" ]; then
    echo -e "${GREEN}📱 正在为 iOS 模拟器 (iphonesimulator) 进行命令行编译...${NC}"
    xcodebuild -project "${XCODE_PROJ}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -configuration Debug \
               -derivedDataPath "${BUILD_DIR}/DerivedData" \
               CODE_SIGNING_ALLOWED=NO \
               build

    APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Debug-iphonesimulator/cfc.app"
    echo -e "\n${GREEN}🎉 编译成功！iOS 模拟器包位置：${NC}"
    echo -e "👉 ${APP_PATH}\n"

elif [ "$MODE" == "iphone" ] || [ "$MODE" == "device" ]; then
    echo -e "${GREEN}📲 正在为实体 iPhone 真机 (iphoneos) 进行命令行编译...${NC}"
    xcodebuild -project "${XCODE_PROJ}" \
               -scheme "${SCHEME}" \
               -sdk iphoneos \
               -configuration Release \
               -derivedDataPath "${BUILD_DIR}/DerivedData" \
               CODE_SIGNING_ALLOWED=NO \
               build

    APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release-iphoneos/cfc.app"
    echo -e "\n${GREEN}🎉 编译成功！iOS 真机 Release 包位置：${NC}"
    echo -e "👉 ${APP_PATH}\n"
    echo -e "${BLUE}💡 命令行安装到 iPhone 提示：${NC}"
    echo -e "  方式 1 (iOS 17+ 官方 CLI): ${YELLOW}xcrun devicectl device install app --device <iPhone设备ID> \"${APP_PATH}\"${NC}"
    echo -e "  方式 2 (Homebrew 工具):   ${YELLOW}ios-deploy --bundle \"${APP_PATH}\"${NC}"
    echo -e "  方式 3 (Xcode 窗口):       在 Xcode 中按 Shift+Cmd+2，把 cfc.app 拖入 Installed Apps 区域\n"

elif [ "$MODE" == "clean" ]; then
    echo -e "${YELLOW}🧹 正在清理构建缓存...${NC}"
    rm -rf "${BUILD_DIR}"
    echo -e "${GREEN}✅ 清理完成！${NC}"

else
    echo -e "${RED}❌ 未知的编译模式: ${MODE}${NC}"
    echo -e "用法说明:"
    echo -e "  ./build.sh simulator  # 编译 iOS 模拟器版本 (默认)"
    echo -e "  ./build.sh iphone     # 编译 iPhone 真机版本"
    echo -e "  ./build.sh clean      # 清理编译产物"
    exit 1
fi
