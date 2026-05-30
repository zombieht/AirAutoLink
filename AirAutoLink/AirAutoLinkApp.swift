import SwiftUI

@main
struct AirAutoLinkApp: App {
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
