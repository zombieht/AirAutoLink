#!/bin/bash
set -e

# 设置变量
PROJECT_NAME="AirAutoLink"
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/${PROJECT_NAME}.app"
DMG_PATH="${BUILD_DIR}/${PROJECT_NAME}.dmg"
ZIP_PATH="${BUILD_DIR}/${PROJECT_NAME}.zip"

# 清理并创建构建目录
echo "==> 清理旧的构建目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 检查依赖 create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "==> 未找到 create-dmg 工具，正在通过 Homebrew 安装..."
    brew install create-dmg
fi

echo "==> 正在编译 Release 版本..."
# 编译应用，并将输出重定向到 BUILD_DIR 下的一个临时归档
xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${PROJECT_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    build

# 找到生成的 .app
COMPILED_APP=$(find "${BUILD_DIR}/DerivedData" -name "${PROJECT_NAME}.app" -type d | head -n 1)

if [ -z "$COMPILED_APP" ]; then
    echo "❌ 错误: 未能找到编译后的 .app 文件。"
    exit 1
fi

# 复制 app 到 build_output
echo "==> 复制应用并进行本地 Ad-Hoc 签名..."
cp -R "${COMPILED_APP}" "${BUILD_DIR}/"

# 进行 Ad-Hoc 签名
echo "==> 进行本地 Ad-Hoc 签名..."
codesign --force --deep --sign - "${APP_PATH}"

echo "==> 正在创建 ZIP 压缩包..."
cd "${BUILD_DIR}"
zip -qr "${PROJECT_NAME}.zip" "${PROJECT_NAME}.app"
cd "${PROJECT_DIR}"

echo "==> 正在创建美化版 DMG..."
create-dmg \
  --volname "${PROJECT_NAME} Installer" \
  --volicon "AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${PROJECT_NAME}.app" 150 190 \
  --hide-extension "${PROJECT_NAME}.app" \
  --app-drop-link 450 190 \
  "${DMG_PATH}" \
  "${APP_PATH}"

echo "==> 清理临时文件..."
rm -rf "${BUILD_DIR}/DerivedData"

echo "✅ 打包完成！"
echo "DMG 路径: ${DMG_PATH}"
echo "ZIP 路径: ${ZIP_PATH}"
