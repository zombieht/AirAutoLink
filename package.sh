#!/bin/bash
set -euo pipefail

# 设置变量与版本号
PROJECT_NAME="AirAutoLink"
CONFIGURATION="Release"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj"
BUILD_DIR="${PROJECT_DIR}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"
DMG_SOURCE_DIR="${BUILD_DIR}/dmg-root"

cd "${PROJECT_DIR}"

# 获取版本号：优先使用命令行传入的参数，其次自动从 Xcode 项目中提取 MARKETING_VERSION
VERSION="${1:-}"
OVERRIDES_MARKETING_VERSION=false

if [ -n "${VERSION}" ]; then
    # 命令行传入版本号时，同时写入本次构建的 MARKETING_VERSION，避免包名与 App 内版本不一致。
    OVERRIDES_MARKETING_VERSION=true
    echo "==> 使用传入的版本号: ${VERSION}"
else
    # 明确从 Release 配置读取版本号，避免多配置或多 Target 时取到错误值。
    VERSION=$(xcodebuild -project "${PROJECT_FILE}" \
        -scheme "${PROJECT_NAME}" \
        -configuration "${CONFIGURATION}" \
        -showBuildSettings \
        | awk -F' = ' '/MARKETING_VERSION/ {version=$2} END {print version}')

    if [ -z "${VERSION}" ]; then
        echo "❌ 错误: 未能从 Xcode 构建配置中读取 MARKETING_VERSION。"
        exit 1
    fi

    echo "==> 自动从 Xcode 项目提取版本号: ${VERSION}"
fi

DMG_PATH="${BUILD_DIR}/${PROJECT_NAME}-${VERSION}.dmg"
ZIP_PATH="${BUILD_DIR}/${PROJECT_NAME}-${VERSION}.zip"

cleanup() {
    # 只清理脚本本次产生的临时目录与 create-dmg 中间镜像，保留最终 .dmg/.zip 产物。
    rm -rf "${DERIVED_DATA_DIR}" "${DMG_SOURCE_DIR}" "${BUILD_DIR}"/rw.*."${PROJECT_NAME}-${VERSION}".dmg
}

trap cleanup EXIT

# 清理并创建构建目录
echo "==> 清理旧的构建目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 检查依赖 create-dmg
if ! command -v create-dmg &> /dev/null; then
    if ! command -v brew &> /dev/null; then
        echo "❌ 错误: 未找到 create-dmg，且当前环境没有 Homebrew，无法自动安装。"
        exit 1
    fi

    echo "==> 未找到 create-dmg 工具，正在通过 Homebrew 安装..."
    brew install create-dmg
fi

echo "==> 正在编译 ${CONFIGURATION} 版本..."
# 编译应用，并将输出重定向到 build/DerivedData，避免污染默认 DerivedData。
if [ "${OVERRIDES_MARKETING_VERSION}" = true ]; then
    xcodebuild -project "${PROJECT_FILE}" \
        -scheme "${PROJECT_NAME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        MARKETING_VERSION="${VERSION}" \
        build
else
    xcodebuild -project "${PROJECT_FILE}" \
        -scheme "${PROJECT_NAME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        build
fi

# 找到生成的 .app
COMPILED_APP="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"

if [ ! -d "${COMPILED_APP}" ]; then
    echo "❌ 错误: 未能找到编译后的 .app 文件。"
    exit 1
fi

# create-dmg 的源参数必须是包含 .app 的目录，而不是 .app Bundle 本身。
rm -rf "${DMG_SOURCE_DIR}"
mkdir -p "${DMG_SOURCE_DIR}"

# 仅在临时打包目录保留 App，避免 build 根目录的同名 .app 被 LaunchServices 误当作安装副本。
echo "==> 复制应用到临时打包目录..."
ditto "${COMPILED_APP}" "${DMG_SOURCE_DIR}/${PROJECT_NAME}.app"

# 进行 Ad-Hoc 签名
echo "==> 进行本地 Ad-Hoc 签名..."
codesign --force --deep --sign - "${DMG_SOURCE_DIR}/${PROJECT_NAME}.app"

echo "==> 正在创建 ZIP 压缩包..."
(
    cd "${DMG_SOURCE_DIR}"
    ditto -c -k --sequesterRsrc --keepParent "${PROJECT_NAME}.app" "${ZIP_PATH}"
)

create_pretty_dmg() {
    create-dmg \
        --volname "${PROJECT_NAME} Installer" \
        --volicon "${PROJECT_DIR}/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${PROJECT_NAME}.app" 150 190 \
        --hide-extension "${PROJECT_NAME}.app" \
        --app-drop-link 450 190 \
        "${DMG_PATH}" \
        "${DMG_SOURCE_DIR}"
}

create_fallback_dmg() {
    create-dmg \
        --skip-jenkins \
        --volname "${PROJECT_NAME} Installer" \
        --volicon "${PROJECT_DIR}/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${PROJECT_NAME}.app" 150 190 \
        --hide-extension "${PROJECT_NAME}.app" \
        --app-drop-link 450 190 \
        "${DMG_PATH}" \
        "${DMG_SOURCE_DIR}"
}

echo "==> 正在创建美化版 DMG..."
if ! create_pretty_dmg; then
    echo "==> Finder 美化步骤失败，改用无 Finder 美化模式重新创建 DMG..."
    rm -f "${DMG_PATH}" "${BUILD_DIR}"/rw.*."${PROJECT_NAME}-${VERSION}".dmg
    create_fallback_dmg
fi

echo "==> 清理临时文件..."
cleanup
trap - EXIT

echo "✅ 打包完成！"
echo "DMG 路径: ${DMG_PATH}"
echo "ZIP 路径: ${ZIP_PATH}"
