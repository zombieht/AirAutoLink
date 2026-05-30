import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    // 用户双击启动台图标或在 Dock 重新点击图标时发送通知，以便打开主窗口
    NotificationCenter.default.post(name: .showMainWindow, object: nil)
    return true
  }
}

@main
struct AirAutoLinkApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()
  @Environment(\.openWindow) private var openWindow

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(
        appState: appState,
        settingsStore: appState.settingsStore,
        bluetoothDeviceService: appState.bluetoothDeviceService,
        reconnectCoordinator: appState.reconnectCoordinator
      )
    } label: {
      MenuBarLabel(reconnectCoordinator: appState.reconnectCoordinator)
        .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
          // 接收到通知后在主线程打开主控制面板窗口
          openWindow(id: "main-window")
        }
    }
    .menuBarExtraStyle(.menu)

    // 添加控制面板窗口，限制其尺寸，采用隐藏标题栏的现代化毛玻璃设计
    Window("AirAutoLink 控制面板", id: "main-window") {
      MainWindowView(appState: appState)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
  }
}

extension Notification.Name {
  static let showMainWindow = Notification.Name("showMainWindow")
}
