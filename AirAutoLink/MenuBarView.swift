import AppKit
import SwiftUI

struct MenuBarLabel: View {
  @ObservedObject var reconnectCoordinator: ReconnectCoordinator

  var body: some View {
    Image(systemName: reconnectCoordinator.status.systemImageName)
  }
}

struct MenuBarView: View {
  @ObservedObject var appState: AppState
  @ObservedObject var settingsStore: SettingsStore
  @ObservedObject var bluetoothDeviceService: BluetoothDeviceService
  @ObservedObject var reconnectCoordinator: ReconnectCoordinator

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      statusHeader

      Divider()

      Button("显示控制面板...") {
        WindowManager.shared.showMainWindow()
      }

      Divider()

      Button("立即连接") {
        appState.connectNow()
      }
      .disabled(reconnectCoordinator.status.isWorking || currentTargetDevice == nil)

      Button("停止重试") {
        appState.cancelReconnect()
      }
      .disabled(!reconnectCoordinator.status.isWorking)

      Divider()

      Toggle(
        "开机自动运行",
        isOn: Binding(
          get: {
            settingsStore.launchesAtLogin
          },
          set: { newValue in
            appState.setLaunchesAtLogin(newValue)
          }
        )
      )

      Toggle(
        "连接后切换输出",
        isOn: Binding(
          get: {
            settingsStore.automaticallySwitchesOutput
          },
          set: { newValue in
            settingsStore.automaticallySwitchesOutput = newValue
          }
        )
      )

      Toggle(
        "显示 Dock 图标",
        isOn: Binding(
          get: {
            settingsStore.showsDockIcon
          },
          set: { newValue in
            handleDockIconToggle(newValue)
          }
        )
      )

      Toggle(
        "显示菜单栏图标",
        isOn: Binding(
          get: {
            settingsStore.showsMenuBarIcon
          },
          set: { newValue in
            handleMenuBarIconToggle(newValue)
          }
        )
      )

      Divider()

      deviceSection

      Divider()

      Button("刷新设备列表") {
        appState.refreshDevices()
      }

      Button("打开蓝牙设置") {
        appState.openBluetoothSettings()
      }

      Button("打开声音设置") {
        appState.openSoundSettings()
      }

      Divider()

      Button("退出 AirAutoLink") {
        NSApplication.shared.terminate(nil)
      }
    }
    .padding(.vertical, 6)
    .frame(minWidth: 260)
  }

  private var statusHeader: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("AirAutoLink")
        .font(.headline)

      Text(AppVersion.displayText)
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(reconnectCoordinator.status.title)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      if let currentOutput = appState.audioRouteService.currentOutputDevice {
        Text("当前输出：\(currentOutput.name)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private var deviceSection: some View {
    let devices = pinnedAwareDevices

    if devices.isEmpty {
      Text("没有已配对的蓝牙音频设备")
        .foregroundStyle(.secondary)
    } else {
      Section("固定设备") {
        ForEach(devices) { device in
          Button {
            appState.setPinnedDevice(device)
          } label: {
            HStack {
              Text(device.name)
              Spacer()
              if device.isPinned {
                Image(systemName: "checkmark")
              }
            }
          }
        }
      }
    }

    if settingsStore.pinnedDevice != nil {
      Button("清除固定设备") {
        appState.clearPinnedDevice()
      }
    }

    if let recentDevice = settingsStore.recentDevice {
      Button("使用最近设备：\(recentDevice.name)") {
        appState.useRecentDevice()
      }
    }
  }

  private var currentTargetDevice: BluetoothAudioDevice? {
    settingsStore.pinnedDevice ?? settingsStore.recentDevice
  }

  private var pinnedAwareDevices: [BluetoothAudioDevice] {
    bluetoothDeviceService.pairedAudioDevices.map { device in
      device.withPinnedState(settingsStore.pinnedDevice?.id == device.id)
    }
  }

  // MARK: - 图标显示交互处理

  private func handleDockIconToggle(_ newValue: Bool) {
    guard settingsStore.showsDockIcon != newValue else { return }
    if !newValue && !settingsStore.showsMenuBarIcon {
      showDoubleHideAlert { confirmed in
        if confirmed {
          settingsStore.showsDockIcon = false
        }
      }
    } else {
      settingsStore.showsDockIcon = newValue
    }
  }

  private func handleMenuBarIconToggle(_ newValue: Bool) {
    guard settingsStore.showsMenuBarIcon != newValue else { return }
    if !newValue && !settingsStore.showsDockIcon {
      showDoubleHideAlert { confirmed in
        if confirmed {
          settingsStore.showsMenuBarIcon = false
        }
      }
    } else {
      settingsStore.showsMenuBarIcon = newValue
    }
  }

  private func showDoubleHideAlert(completion: @escaping (Bool) -> Void) {
    let alert = NSAlert()
    alert.messageText = "确定要同时隐藏所有图标吗？"
    alert.informativeText = "同时隐藏 Dock 图标和菜单栏图标后，应用将在后台静默运行。\n\n若需重新打开控制面板，请通过系统【启动台 (Launchpad)】再次点击 AirAutoLink 应用程序图标。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "确定隐藏")
    alert.addButton(withTitle: "取消")

    let response = alert.runModal()
    completion(response == .alertFirstButtonReturn)
  }
}
