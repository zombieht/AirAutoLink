import SwiftUI
import AppKit

struct MainWindowView: View {
  @ObservedObject var appState: AppState
  
  // 观察状态以便在 UI 中动态更新
  @ObservedObject private var settingsStore: SettingsStore
  @ObservedObject private var reconnectCoordinator: ReconnectCoordinator
  @ObservedObject private var bluetoothDeviceService: BluetoothDeviceService
  
  // 鼠标悬停在设备列表项上的状态
  @State private var hoveredDeviceId: String? = nil
  
  init(appState: AppState) {
    self.appState = appState
    self.settingsStore = appState.settingsStore
    self.reconnectCoordinator = appState.reconnectCoordinator
    self.bluetoothDeviceService = appState.bluetoothDeviceService
  }
  
  var body: some View {
    HStack(spacing: 0) {
      // 左栏：状态面板与偏好设置
      leftPanel
        .frame(width: 260)
        .background(
          LinearGradient(
            colors: [
              Color(NSColor.windowBackgroundColor).opacity(0.95),
              Color(NSColor.underPageBackgroundColor).opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      
      Divider()
      
      // 右栏：蓝牙设备管理列表
      rightPanel
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
    }
    .frame(width: 560, height: 380)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .onAppear {
      // 窗口显示时，动态将应用策略设置为普通应用（在 Dock 显示并可聚焦）
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
    .onDisappear {
      // 窗口关闭时，动态将应用策略恢复为 Accessory 辅助应用（在 Dock 隐藏，保持菜单栏静默常驻）
      NSApp.setActivationPolicy(.accessory)
    }
  }
  
  // MARK: - 左侧面板 (状态与设置)
  private var leftPanel: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 顶部标题区域
      HStack {
        Image(systemName: "bolt.horizontal.fill")
          .foregroundStyle(.blue)
          .font(.title2)
        Text("AirAutoLink")
          .font(.system(.title2, design: .rounded))
          .fontWeight(.bold)
      }
      .padding(.top, 16)
      
      // 核心连接状态卡片
      statusCard
      
      // 核心控制按钮组
      HStack(spacing: 12) {
        let currentTarget = settingsStore.pinnedDevice ?? settingsStore.recentDevice
        let isWorking = reconnectCoordinator.status.isWorking
        
        Button {
          appState.connectNow()
        } label: {
          Text("立即连接")
            .fontWeight(.medium)
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(isWorking || currentTarget == nil)
        
        Button {
          appState.cancelReconnect()
        } label: {
          Text("停止重试")
            .fontWeight(.medium)
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.bordered)
        .disabled(!isWorking)
      }
      
      Divider()
      
      // 偏好设置 Toggle 区域
      VStack(alignment: .leading, spacing: 12) {
        Toggle("开机自动运行", isOn: Binding(
          get: { settingsStore.launchesAtLogin },
          set: { appState.setLaunchesAtLogin($0) }
        ))
        .toggleStyle(.checkbox)
        
        Toggle("连接后切换输出", isOn: Binding(
          get: { settingsStore.automaticallySwitchesOutput },
          set: { settingsStore.automaticallySwitchesOutput = $0 }
        ))
        .toggleStyle(.checkbox)
      }
      .font(.body)
      
      Spacer()
      
      // 底部系统设置与退出按钮
      HStack(spacing: 8) {
        Button {
          appState.openSoundSettings()
        } label: {
          Label("声音", systemImage: "speaker.wave.3.fill")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        
        Spacer()
        
        Button {
          appState.openBluetoothSettings()
        } label: {
          Label("蓝牙", systemImage: "wave.3.right.circle.fill")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        
        Spacer()
        
        Button {
          NSApplication.shared.terminate(nil)
        } label: {
          Text("退出")
            .font(.caption)
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
      }
      .padding(.bottom, 16)
    }
    .padding(.horizontal, 16)
  }
  
  // MARK: - 状态卡片组件
  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
          .shadow(color: statusColor.opacity(0.6), radius: 3)
        
        Text(reconnectCoordinator.status.title)
          .font(.subheadline)
          .fontWeight(.medium)
          .lineLimit(1)
      }
      
      if let currentOutput = appState.audioRouteService.currentOutputDevice {
        Text("当前音频输出：\(currentOutput.name)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      } else {
        Text("当前音频输出：默认设备")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    )
  }
  
  // MARK: - 右侧面板 (蓝牙设备列表)
  private var rightPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 头部标题与刷新按钮
      HStack {
        Text("配对的蓝牙音箱")
          .font(.headline)
        Spacer()
        Button {
          appState.refreshDevices()
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.subheadline)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("刷新设备列表")
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)
      
      Divider()
      
      let devices = pinnedAwareDevices
      
      if devices.isEmpty {
        VStack {
          Spacer()
          Image(systemName: "speaker.slash")
            .font(.system(size: 32))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
          Text("未发现已配对的蓝牙音频设备")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
          Spacer()
        }
        .frame(maxWidth: .infinity)
      } else {
        // 设备列表滚动视图
        ScrollView {
          VStack(spacing: 8) {
            ForEach(devices) { device in
              deviceRow(for: device)
            }
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
        }
      }
    }
  }
  
  // MARK: - 设备列表行组件
  private func deviceRow(for device: BluetoothAudioDevice) -> some View {
    Button {
      if device.isPinned {
        appState.clearPinnedDevice()
      } else {
        appState.setPinnedDevice(device)
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: device.isConnected ? "speaker.wave.2.fill" : "speaker.fill")
          .foregroundStyle(device.isConnected ? .green : .secondary)
          .font(.title3)
          .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(device.name)
            .font(.subheadline)
            .fontWeight(device.isPinned ? .semibold : .regular)
            .foregroundStyle(.primary)
            .lineLimit(1)
          
          if device.isConnected {
            Text("已连接")
              .font(.system(size: 10))
              .foregroundStyle(.green)
          } else {
            Text("已配对")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }
        }
        
        Spacer()
        
        // Pin/Checkmark 标记指示
        if device.isPinned {
          Image(systemName: "pin.fill")
            .foregroundStyle(.blue)
            .font(.caption)
            .help("已固定此设备")
        } else if hoveredDeviceId == device.id {
          Image(systemName: "pin")
            .foregroundStyle(.tertiary)
            .font(.caption)
        }
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(
          device.isPinned
          ? Color.blue.opacity(0.1)
          : (hoveredDeviceId == device.id ? Color.secondary.opacity(0.1) : Color.clear)
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          device.isPinned ? Color.blue.opacity(0.3) : Color.clear,
          lineWidth: 1
        )
    )
    .onHover { isHovered in
      hoveredDeviceId = isHovered ? device.id : nil
    }
  }
  
  // MARK: - 辅助属性计算
  private var statusColor: Color {
    switch reconnectCoordinator.status {
    case .noTarget:
      return .secondary
    case .ready:
      return .blue
    case .retrying:
      return .orange
    case .connected:
      return .green
    case .failed:
      return .red
    case .loginItemRequiresApproval:
      return .yellow
    }
  }
  
  private var pinnedAwareDevices: [BluetoothAudioDevice] {
    bluetoothDeviceService.pairedAudioDevices.map { device in
      device.withPinnedState(settingsStore.pinnedDevice?.id == device.id)
    }
  }
}
