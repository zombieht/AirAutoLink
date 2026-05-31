# AirAutoLink

一个用于解决 macOS 重新开机或重新登录后，第三方蓝牙音响/音箱不能自动连接到上一次使用设备问题的现代化菜单栏及桌面控制面板工具。

## 功能

- **普通应用与菜单栏入口**：应用会显示在 Dock、启动台与应用切换器中，同时保留菜单栏图标，方便从任一入口打开控制面板。
- **现代化控制面板**：提供精美磨砂玻璃（毛玻璃）质感的主窗口界面，支持直观查看当前连接状态与系统音频输出。
- **设备管理与固定**：支持在大头针（Pin）列表中固定特定的蓝牙音频设备，未固定时会自动记住并重连最近一次使用的设备。
- **手动连接控制**：可在控制面板和菜单栏中随时点击“立即连接”启动重连，或点击“停止重试”中断连接。
- **自动重连与切换**：登录后智能等待蓝牙与音频系统就绪，自动重试连接，并在连接成功后自动将系统默认音频输出切换至该设备（可配置是否自动切换）。
- **常用设置与辅助**：支持开机自动运行开关、连接后自动切换输出开关，一键直达系统“声音”和“蓝牙”配置。

## 系统要求

- macOS 15 或更高版本。
- 目标蓝牙音响需要先在 macOS 系统设置中完成配对。

## 构建

```bash
# Debug 构建
xcodebuild -project AirAutoLink.xcodeproj -scheme AirAutoLink -configuration Debug build
```

Release 构建：

```bash
# Release 构建
xcodebuild -project AirAutoLink.xcodeproj -scheme AirAutoLink -configuration Release build
```

## 打包

```bash
# 使用 Xcode 工程中的 MARKETING_VERSION 打包
./package.sh

# 临时指定本次打包的展示版本号，不会写回工程配置
./package.sh 1.1.0
```

打包产物会生成到 `build/` 目录，包括 `.dmg` 与 `.zip` 文件。

## 运行

可以直接用 Xcode 打开 `AirAutoLink.xcodeproj` 并运行 `AirAutoLink` scheme。

命令行构建后的 Debug 版本默认位于 Xcode DerivedData 目录，例如：

```text
~/Library/Developer/Xcode/DerivedData/AirAutoLink-*/Build/Products/Debug/AirAutoLink.app
```

首次运行时，macOS 可能会请求蓝牙访问权限。允许后，AirAutoLink 才能读取已配对的蓝牙音频设备并尝试连接。

## 使用流程

1. 先在系统设置中确认蓝牙音箱/音响已经配对。
2. 启动 AirAutoLink，点击菜单栏中的音箱图标，或双击启动台中的应用图标打开控制面板。
3. 在设备列表中，点击目标音响旁边的大头针（Pin）图标将其固定；或先手动将系统输出切换到该音响，让应用记住最近设备。
4. 在控制面板或菜单中勾选“开机自动运行”与“连接后切换输出”选项。
5. 下次登录后，应用会自动尝试重连目标设备并自动切换输出。

## 说明
- 安装出现提示删除请到隐私与安全性-->安全性 选择仍要打开
- 第一版面向本机自用，未启用 App Sandbox，也未做公证、安装器或自动更新。
- 应用负责重连已配对设备，不负责首次配对。
- 如果登录项显示需要批准，请到系统设置的登录项页面手动允许 AirAutoLink。
