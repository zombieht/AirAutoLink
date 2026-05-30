import Foundation
@preconcurrency import IOBluetooth
import OSLog

enum BluetoothConnectionResult: Equatable, Sendable {
  case connected(BluetoothAudioDevice)
  case failed(String)
}

@MainActor
final class BluetoothDeviceService: NSObject, ObservableObject {
  @Published private(set) var pairedAudioDevices: [BluetoothAudioDevice] = []

  private let logger = Logger(subsystem: "AirAutoLink", category: "Bluetooth")
  private var connectNotification: IOBluetoothUserNotification?
  private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

  override init() {
    super.init()

    refreshPairedAudioDevices()
    connectNotification = IOBluetoothDevice.register(
      forConnectNotifications: self,
      selector: #selector(deviceConnected(_:device:))
    )
  }

  deinit {
    connectNotification?.unregister()
    disconnectNotifications.values.forEach { notification in
      notification.unregister()
    }
  }

  func refreshPairedAudioDevices() {
    let ioDevices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []

    pairedAudioDevices = ioDevices
      .filter(Self.isAudioDevice(_:))
      .compactMap(Self.makeBluetoothAudioDevice(from:))
      .sorted { first, second in
        first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
      }

    registerDisconnectNotifications(for: ioDevices)
  }

  func resolvedDevice(for storedDevice: BluetoothAudioDevice) -> BluetoothAudioDevice? {
    refreshPairedAudioDevices()

    return pairedAudioDevices.first { candidate in
      candidate.normalizedAddress == storedDevice.normalizedAddress
    }
  }

  func connect(to device: BluetoothAudioDevice) async -> BluetoothConnectionResult {
    await withCheckedContinuation { continuation in
      let requestedDevice = device.withPinnedState(false)

      // IOBluetoothDevice.openConnection() 是同步调用，目标设备不在范围内时可能阻塞数秒。
      // 放到后台队列执行，避免菜单栏 UI 在重试期间失去响应。
      DispatchQueue.global(qos: .utility).async {
        let result = Self.openConnection(to: requestedDevice)

        Task { @MainActor [weak self] in
          self?.refreshPairedAudioDevices()
          continuation.resume(returning: result)
        }
      }
    }
  }

  private func registerDisconnectNotifications(for devices: [IOBluetoothDevice]) {
    let audioDevices = devices.filter(Self.isAudioDevice(_:))
    let activeAddresses = Set(
      audioDevices.compactMap { ioDevice in
        Self.makeBluetoothAudioDevice(from: ioDevice)?.normalizedAddress
      }
    )

    for (address, notification) in disconnectNotifications where !activeAddresses.contains(address) {
      notification.unregister()
      disconnectNotifications.removeValue(forKey: address)
    }

    for ioDevice in audioDevices {
      guard let device = Self.makeBluetoothAudioDevice(from: ioDevice) else {
        continue
      }

      guard disconnectNotifications[device.normalizedAddress] == nil else {
        continue
      }

      disconnectNotifications[device.normalizedAddress] = ioDevice.register(
        forDisconnectNotification: self,
        selector: #selector(deviceDisconnected(_:device:))
      )
    }
  }

  @objc nonisolated private func deviceConnected(
    _ notification: IOBluetoothUserNotification,
    device: IOBluetoothDevice
  ) {
    // 提取设备名称（String 为 Sendable），避免在 Task 中捕获非 Sendable 的 IOBluetoothDevice
    let nameOrAddress = device.nameOrAddress ?? "unknown"
    Task { @MainActor [weak self] in
      guard let self = self else { return }
      self.logger.info("Bluetooth device connected: \(nameOrAddress, privacy: .public)")
      self.refreshPairedAudioDevices()
    }
  }

  @objc nonisolated private func deviceDisconnected(
    _ notification: IOBluetoothUserNotification,
    device: IOBluetoothDevice
  ) {
    // 提取设备名称（String 为 Sendable），避免在 Task 中捕获非 Sendable 的 IOBluetoothDevice
    let nameOrAddress = device.nameOrAddress ?? "unknown"
    Task { @MainActor [weak self] in
      guard let self = self else { return }
      self.logger.info("Bluetooth device disconnected: \(nameOrAddress, privacy: .public)")
      self.refreshPairedAudioDevices()
    }
  }

  private static func makeBluetoothAudioDevice(from ioDevice: IOBluetoothDevice)
    -> BluetoothAudioDevice?
  {
    guard let address = ioDevice.addressString, !address.isEmpty else {
      return nil
    }

    let fallbackName = address
    let trimmedName = ioDevice.nameOrAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName: String

    if let trimmedName, !trimmedName.isEmpty {
      displayName = trimmedName
    } else {
      displayName = fallbackName
    }

    return BluetoothAudioDevice(
      name: displayName,
      address: address,
      isConnected: ioDevice.isConnected()
    )
  }

  private static func isAudioDevice(_ ioDevice: IOBluetoothDevice) -> Bool {
    let deviceClass = BluetoothDeviceClassMajor(kBluetoothDeviceClassMajorAudio)
    let serviceClass = UInt32(ioDevice.serviceClassMajor)

    return ioDevice.deviceClassMajor == deviceClass
      || (serviceClass & UInt32(kBluetoothServiceClassMajorAudio)) != 0
      || (serviceClass & UInt32(kBluetoothServiceClassMajorRendering)) != 0
  }

  private nonisolated static func openConnection(to device: BluetoothAudioDevice)
    -> BluetoothConnectionResult
  {
    guard let ioDevice = IOBluetoothDevice(addressString: device.address) else {
      return .failed("找不到已配对设备：\(device.name)")
    }

    if ioDevice.isConnected() {
      return .connected(device.withConnectionState(true))
    }

    let status = ioDevice.openConnection()

    if status == kIOReturnSuccess || ioDevice.isConnected() {
      return .connected(device.withConnectionState(true))
    }

    return .failed("连接失败：\(device.name)（\(Self.hexStatus(status))）")
  }

  private nonisolated static func hexStatus(_ status: IOReturn) -> String {
    let unsignedStatus = UInt32(bitPattern: status)

    return String(format: "0x%08X", unsignedStatus)
  }
}
