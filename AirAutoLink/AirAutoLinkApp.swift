import SwiftUI

enum AppVersion {
  // 统一从 Info.plist 读取展示版本，避免界面文本与构建配置中的版本号不一致。
  static var displayText: String {
    let version = infoValue(forKey: "CFBundleShortVersionString", fallback: "0.0")

    return "版本 \(version)"
  }

  private static func infoValue(forKey key: String, fallback: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty else {
      return fallback
    }

    return value
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    // 用户双击启动台图标或在 Dock 重新点击图标时，直接通过 WindowManager 显示主控制面板
    WindowManager.shared.showMainWindow()
    return true
  }
}

@main
struct AirAutoLinkApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    MenuBarExtra(
      "AirAutoLink",
      systemImage: appState.reconnectCoordinator.status.systemImageName,
      isInserted: Binding(
        get: { appState.settingsStore.showsMenuBarIcon },
        set: { newValue in
          guard appState.settingsStore.showsMenuBarIcon != newValue else { return }
          appState.settingsStore.showsMenuBarIcon = newValue
        }
      )
    ) {
      MenuBarView(
        appState: appState,
        settingsStore: appState.settingsStore,
        bluetoothDeviceService: appState.bluetoothDeviceService,
        reconnectCoordinator: appState.reconnectCoordinator
      )
    }
    .menuBarExtraStyle(.menu)

    // 提供一个隐藏的 Settings Scene 作为占位符，
    // 保证即使在菜单栏图标和 Dock 图标都被隐藏时，应用仍能正常编译并维持生命周期。
    Settings {
      EmptyView()
    }
  }
}
