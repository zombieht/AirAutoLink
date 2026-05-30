import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 动态设置为菜单栏应用，这样可以不用在 Info.plist 中写死 LSUIElement，从而确保启动台能 100% 收录该应用
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct AirAutoLinkApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()

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
    }
    .menuBarExtraStyle(.menu)
  }
}
