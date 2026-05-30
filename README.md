# AirAutoLink

一个用于解决 macOS 重新开机或重新登录后，第三方蓝牙音响不能自动连接到上一次使用设备问题的菜单栏工具。

## 功能

- 常驻菜单栏，不显示 Dock 图标。
- 支持手动固定一个蓝牙音频设备。
- 未固定设备时，自动记住最近一次作为系统输出的蓝牙音频设备。
- 登录后等待蓝牙和音频服务就绪，再自动重试连接。
- 连接成功后自动切换系统默认输出到目标蓝牙音响。
- 支持开启或关闭开机自动运行。
- 菜单中提供刷新设备、打开蓝牙设置、打开声音设置和退出入口。

## 系统要求

- macOS 15 或更高版本。
- Xcode 26.5 或兼容版本。
- 目标蓝牙音响需要先在 macOS 系统设置中完成配对。

## 构建

```bash
xcodebuild -project AirAutoLink.xcodeproj -scheme AirAutoLink -configuration Debug build
```

Release 构建：

```bash
xcodebuild -project AirAutoLink.xcodeproj -scheme AirAutoLink -configuration Release build
```

## 运行

可以直接用 Xcode 打开 `AirAutoLink.xcodeproj` 并运行 `AirAutoLink` scheme。

命令行构建后的 Debug 版本默认位于 Xcode DerivedData 目录，例如：

```text
~/Library/Developer/Xcode/DerivedData/AirAutoLink-*/Build/Products/Debug/AirAutoLink.app
```

首次运行时，macOS 可能会请求蓝牙访问权限。允许后，AirAutoLink 才能读取已配对的蓝牙音频设备并尝试连接。

## 使用流程

1. 先在系统设置中确认蓝牙音响已经配对。
2. 启动 AirAutoLink，点击菜单栏中的音响图标。
3. 在“固定设备”列表中选择目标音响，或先手动把系统输出切到该音响，让应用记住最近设备。
4. 根据需要开启“开机自动运行”。
5. 下次登录后，应用会等待 8 秒，然后最多重试 10 次，每次间隔 15 秒。

## 说明

- 第一版面向本机自用，未启用 App Sandbox，也未做公证、安装器或自动更新。
- 应用负责重连已配对设备，不负责首次配对。
- 如果登录项显示需要批准，请到系统设置的登录项页面手动允许 AirAutoLink。

