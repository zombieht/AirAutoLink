#!/bin/bash

# ==============================================================================
# AirAutoLink 自动构建与打包脚本 (支持图标生成与注入)
# 
# 本脚本用于一键编译 AirAutoLink 菜单栏应用为 Release 版本，
# 并自动将 AppIcon.png 转换为 AppIcon.icns 图标注入到应用包内，
# 最终打包输出可分发的 .dmg (带有 Applications 快捷方式) 和 .zip 格式安装包。
# ==============================================================================

# 遇到任何命令行错误时，立即终止执行，确保流程安全
set -e

# ------------------------------------------------------------------------------
# 1. 变量定义与环境初始化
# ------------------------------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"
APP_NAME="AirAutoLink"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
ZIP_NAME="${APP_NAME}.zip"

PNG_ICON="${PROJECT_DIR}/AppIcon.png"
ICNS_ICON="${PROJECT_DIR}/AppIcon.icns"

echo "=== [1/9] 开始打包流程 ==="

# ------------------------------------------------------------------------------
# 2. 清理并准备临时构建目录
# ------------------------------------------------------------------------------
echo "-> [2/9] 准备干净的临时构建目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

# ------------------------------------------------------------------------------
# 3. 自动生成 AppIcon.icns 文件 (如果存在 AppIcon.png)
# ------------------------------------------------------------------------------
if [ -f "${PNG_ICON}" ]; then
  echo "-> [3/9] 检测到 AppIcon.png，正在自动生成 macOS 格式 AppIcon.icns..."
  ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
  rm -rf "${ICONSET_DIR}"
  mkdir -p "${ICONSET_DIR}"
  
  # 使用 macOS 内置 sips 将原始 PNG 缩放并转换为真正的 PNG 图标资源
  sips -s format png -z 16 16     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null 2>&1
  sips -s format png -z 32 32     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null 2>&1
  sips -s format png -z 32 32     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null 2>&1
  sips -s format png -z 64 64     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null 2>&1
  sips -s format png -z 128 128   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null 2>&1
  sips -s format png -z 256 256   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null 2>&1
  sips -s format png -z 256 256   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null 2>&1
  sips -s format png -z 512 512   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null 2>&1
  sips -s format png -z 512 512   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null 2>&1
  sips -s format png -z 1024 1024 "${PNG_ICON}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null 2>&1
  
  # 使用 iconutil 将 iconset 文件夹编译为标准的 .icns 文件
  rm -f "${ICNS_ICON}"
  iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_ICON}"
  rm -rf "${ICONSET_DIR}"
  echo "[+] AppIcon.icns 生成成功"
else
  echo "-> [3/9] 未找到 AppIcon.png，跳过图标生成..."
fi

# ------------------------------------------------------------------------------
# 4. 运行 xcodebuild 编译 Release 版本
# ------------------------------------------------------------------------------
echo "-> [4/9] 正在使用 xcodebuild 编译 Release 版本..."
xcodebuild \
  -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  clean build

# ------------------------------------------------------------------------------
# 5. 验证编译生成的 .app 目录是否存在
# ------------------------------------------------------------------------------
BUILT_APP_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_BUNDLE}"

if [ ! -d "${BUILT_APP_PATH}" ]; then
  echo "[-] 错误: 未能在目标路径找到编译出的应用包: ${BUILT_APP_PATH}"
  exit 1
fi

echo "-> [5/9] 成功找到编译产物: ${BUILT_APP_PATH}"

# ------------------------------------------------------------------------------
# 6. 动态注入 AppIcon.icns 进应用包内并刷新元数据
# ------------------------------------------------------------------------------
if [ -f "${ICNS_ICON}" ]; then
  echo "-> [6/9] 正在向应用包中注入 AppIcon.icns 图标..."
  mkdir -p "${BUILT_APP_PATH}/Contents/Resources"
  cp "${ICNS_ICON}" "${BUILT_APP_PATH}/Contents/Resources/"
  # touch 应用包以刷新 macOS 系统的元数据和图标缓存
  touch "${BUILT_APP_PATH}"
  echo "[+] 图标注入成功"
else
  echo "-> [6/9] 未检测到 AppIcon.icns，跳过图标注入..."
fi

# ------------------------------------------------------------------------------
# 7. 打包 ZIP 安装包
# ------------------------------------------------------------------------------
echo "-> [7/9] 正在生成 ZIP 压缩安装包..."
rm -f "${PROJECT_DIR}/${ZIP_NAME}"
# 进入 Release 目录进行 zip，确保解包时不会多出层级，-y 用于保留 macOS 应用内的软链接
(cd "${DERIVED_DATA_DIR}/Build/Products/Release" && zip -r -y "${PROJECT_DIR}/${ZIP_NAME}" "${APP_BUNDLE}")
echo "[+] ZIP 安装包已生成: ${PROJECT_DIR}/${ZIP_NAME}"

# ------------------------------------------------------------------------------
# 8. 拷贝 App 到 DMG 制作目录，并添加系统 Applications 目录的软链接
# ------------------------------------------------------------------------------
echo "-> [8/9] 拷贝应用包并创建 Applications 快捷方式..."
cp -R "${BUILT_APP_PATH}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# ------------------------------------------------------------------------------
# 9. 使用 hdiutil 将目录打包为 DMG
# ------------------------------------------------------------------------------
echo "-> [9/9] 正在生成 DMG 磁盘映像安装包..."
rm -f "${PROJECT_DIR}/${DMG_NAME}"
hdiutil create \
  -fs HFS+ \
  -srcfolder "${DMG_TEMP_DIR}" \
  -volname "${APP_NAME}" \
  -ov \
  "${PROJECT_DIR}/${DMG_NAME}"
echo "[+] DMG 安装包已生成: ${PROJECT_DIR}/${DMG_NAME}"

# ------------------------------------------------------------------------------
# 收尾清理工作
# ------------------------------------------------------------------------------
echo "-> 正在清理临时构建文件..."
rm -rf "${BUILD_DIR}"

echo "=== 打包流程圆满完成！ ==="
echo "生成产物信息："
echo "1. DMG 磁盘镜像: ${PROJECT_DIR}/${DMG_NAME}"
echo "2. ZIP 压缩包  : ${PROJECT_DIR}/${ZIP_NAME}"
