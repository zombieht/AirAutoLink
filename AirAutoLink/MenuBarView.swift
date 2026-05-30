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
        NotificationCenter.default.post(name: .showMainWindow, object: nil)
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
}
