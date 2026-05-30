import Foundation
import OSLog

@MainActor
final class ReconnectCoordinator: ObservableObject {
  @Published private(set) var status: ConnectionStatus = .noTarget

  private let settingsStore: SettingsStore
  private let bluetoothDeviceService: BluetoothDeviceService
  private let audioRouteService: AudioRouteService
  private let logger = Logger(subsystem: "AirAutoLink", category: "Reconnect")
  private var reconnectTask: Task<Void, Never>?

  private let loginDelay: Duration = .seconds(8)
  private let retryDelay: Duration = .seconds(15)
  private let maxAttempts = 10

  init(
    settingsStore: SettingsStore,
    bluetoothDeviceService: BluetoothDeviceService,
    audioRouteService: AudioRouteService
  ) {
    self.settingsStore = settingsStore
    self.bluetoothDeviceService = bluetoothDeviceService
    self.audioRouteService = audioRouteService
    refreshStatusFromTarget()
  }

  deinit {
    reconnectTask?.cancel()
  }

  func startLoginReconnect() {
    reconnectTask?.cancel()

    reconnectTask = Task { [weak self] in
      guard let self else {
        return
      }

      try? await Task.sleep(for: loginDelay)
      await runRetryLoop()
    }
  }

  func connectNow() {
    reconnectTask?.cancel()

    reconnectTask = Task { [weak self] in
      await self?.connectOnce(attempt: 1, maxAttempts: 1, shouldRetry: false)
    }
  }

  func cancelReconnect() {
    reconnectTask?.cancel()
    reconnectTask = nil
    refreshStatusFromTarget()
  }

  func refreshStatusFromTarget() {
    settingsStore.refreshLoginItemStatus()

    if settingsStore.loginItemRequiresApproval {
      status = .loginItemRequiresApproval
      return
    }

    guard let targetDevice = currentTargetDevice() else {
      status = .noTarget
      return
    }

    if let resolvedDevice = bluetoothDeviceService.resolvedDevice(for: targetDevice),
      resolvedDevice.isConnected
    {
      status = .connected(targetName: resolvedDevice.name)
      return
    }

    status = .ready(targetName: targetDevice.name)
  }

  private func runRetryLoop() async {
    guard currentTargetDevice() != nil else {
      status = .noTarget
      return
    }

    for attempt in 1...maxAttempts {
      if Task.isCancelled {
        return
      }

      let didFinish = await connectOnce(
        attempt: attempt,
        maxAttempts: maxAttempts,
        shouldRetry: true
      )

      if didFinish || Task.isCancelled {
        return
      }

      do {
        try await Task.sleep(for: retryDelay)
      } catch {
        return
      }
    }
  }

  @discardableResult
  private func connectOnce(attempt: Int, maxAttempts: Int, shouldRetry: Bool) async -> Bool {
    if Task.isCancelled {
      return true
    }

    guard let storedTargetDevice = currentTargetDevice() else {
      status = .noTarget
      return true
    }

    guard let targetDevice = bluetoothDeviceService.resolvedDevice(for: storedTargetDevice) else {
      let message = "设备未配对或已移除：\(storedTargetDevice.name)"
      status = .failed(message: message)
      logger.error("\(message, privacy: .public)")
      return true
    }

    status = .retrying(
      targetName: targetDevice.name,
      attempt: attempt,
      maxAttempts: maxAttempts
    )

    let result: BluetoothConnectionResult

    if targetDevice.isConnected {
      result = .connected(targetDevice)
    } else {
      result = await bluetoothDeviceService.connect(to: targetDevice)
    }

    if Task.isCancelled {
      return true
    }

    switch result {
    case let .connected(connectedDevice):
      await switchOutputIfNeeded(for: connectedDevice)
      return true
    case let .failed(message):
      if shouldRetry && attempt < maxAttempts {
        logger.warning("\(message, privacy: .public)")
        return false
      }

      status = .failed(message: message)
      logger.error("\(message, privacy: .public)")
      return true
    }
  }

  private func switchOutputIfNeeded(for device: BluetoothAudioDevice) async {
    do {
      try Task.checkCancellation()

      guard settingsStore.automaticallySwitchesOutput else {
        status = .connected(targetName: device.name)
        return
      }

      guard let outputDevice = try await audioRouteService.waitForOutputDevice(
        matching: device,
        timeout: 20
      ) else {
        try Task.checkCancellation()

        let message = "已连接，但未找到音频输出：\(device.name)"
        status = .failed(message: message)
        logger.error("\(message, privacy: .public)")
        return
      }

      try Task.checkCancellation()
      try audioRouteService.setDefaultOutputDevice(outputDevice)
      try Task.checkCancellation()

      settingsStore.setRecentDevice(device)
      status = .connected(targetName: device.name)
    } catch is CancellationError {
      return
    } catch {
      let message = "已连接，但切换输出失败：\(device.name)"
      status = .failed(message: message)
      logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
  }

  private func currentTargetDevice() -> BluetoothAudioDevice? {
    settingsStore.pinnedDevice ?? settingsStore.recentDevice
  }
}
