import CoreAudio
import Foundation
import OSLog

struct AudioOutputDevice: Equatable, Sendable {
  let id: AudioObjectID
  let name: String
  let uid: String
  let transportType: UInt32

  var isBluetooth: Bool {
    transportType == UInt32(kAudioDeviceTransportTypeBluetooth)
      || transportType == UInt32(kAudioDeviceTransportTypeBluetoothLE)
  }
}

enum AudioRouteError: LocalizedError {
  case defaultOutputReadFailed(OSStatus)
  case defaultOutputWriteFailed(OSStatus)
  case deviceListReadFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case let .defaultOutputReadFailed(status):
      return "读取默认输出设备失败（\(Self.hexStatus(status))）"
    case let .defaultOutputWriteFailed(status):
      return "切换默认输出设备失败（\(Self.hexStatus(status))）"
    case let .deviceListReadFailed(status):
      return "读取音频输出设备失败（\(Self.hexStatus(status))）"
    }
  }

  private static func hexStatus(_ status: OSStatus) -> String {
    let unsignedStatus = UInt32(bitPattern: status)

    return String(format: "0x%08X", unsignedStatus)
  }
}

@MainActor
final class AudioRouteService: ObservableObject {
  @Published private(set) var currentOutputDevice: AudioOutputDevice?

  var defaultOutputChanged: ((AudioOutputDevice?) -> Void)?

  private let logger = Logger(subsystem: "AirAutoLink", category: "AudioRoute")
  private var defaultOutputAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )

  init() {
    refreshCurrentOutputDevice(notify: false)
    registerDefaultOutputListener()
  }

  func refreshCurrentOutputDevice(notify: Bool = true) {
    do {
      currentOutputDevice = try defaultOutputDevice()
      if notify {
        defaultOutputChanged?(currentOutputDevice)
      }
    } catch {
      logger.error("Failed to refresh default output device: \(error.localizedDescription, privacy: .public)")
      currentOutputDevice = nil
    }
  }

  func waitForOutputDevice(
    matching bluetoothDevice: BluetoothAudioDevice,
    timeout: TimeInterval
  ) async -> AudioOutputDevice? {
    let deadline = Date().addingTimeInterval(timeout)

    repeat {
      if let outputDevice = bluetoothOutputDevice(matching: bluetoothDevice) {
        return outputDevice
      }

      try? await Task.sleep(for: .milliseconds(500))
    } while Date() < deadline

    return nil
  }

  func setDefaultOutputDevice(_ outputDevice: AudioOutputDevice) throws {
    var address = defaultOutputAddress
    var deviceID = outputDevice.id
    let dataSize = UInt32(MemoryLayout<AudioObjectID>.size)

    let status = AudioObjectSetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      dataSize,
      &deviceID
    )

    guard status == noErr else {
      throw AudioRouteError.defaultOutputWriteFailed(status)
    }

    refreshCurrentOutputDevice()
  }

  func bluetoothOutputDevice(matching bluetoothDevice: BluetoothAudioDevice)
    -> AudioOutputDevice?
  {
    outputDevices()
      .filter(\.isBluetooth)
      .first { outputDevice in
        Self.outputDevice(outputDevice, matches: bluetoothDevice)
      }
  }

  func matchingBluetoothDevice(
    for outputDevice: AudioOutputDevice,
    in bluetoothDevices: [BluetoothAudioDevice]
  ) -> BluetoothAudioDevice? {
    guard outputDevice.isBluetooth else {
      return nil
    }

    return bluetoothDevices.first { bluetoothDevice in
      Self.outputDevice(outputDevice, matches: bluetoothDevice)
    }
  }

  private func registerDefaultOutputListener() {
    var address = defaultOutputAddress

    // CoreAudio 的默认输出变化不走 NotificationCenter，只能注册 AudioObject 监听。
    // 回调已经派发到主队列，后续更新菜单状态时不需要再切线程。
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      DispatchQueue.main
    ) { [weak self] _, _ in
      Task { @MainActor in
        self?.refreshCurrentOutputDevice()
      }
    }

    if status != noErr {
      logger.error("Failed to register default output listener: \(status)")
    }
  }

  private func outputDevices() -> [AudioOutputDevice] {
    do {
      let deviceIDs = try audioDeviceIDs()

      return deviceIDs.compactMap { deviceID in
        guard hasOutputStreams(deviceID: deviceID) else {
          return nil
        }

        guard let name = stringProperty(deviceID: deviceID, selector: kAudioObjectPropertyName) else {
          return nil
        }

        guard let uid = stringProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceUID) else {
          return nil
        }

        guard let transportType = uint32Property(
          deviceID: deviceID,
          selector: kAudioDevicePropertyTransportType
        ) else {
          return nil
        }

        return AudioOutputDevice(
          id: deviceID,
          name: name,
          uid: uid,
          transportType: transportType
        )
      }
    } catch {
      logger.error("Failed to read audio output devices: \(error.localizedDescription, privacy: .public)")
      return []
    }
  }

  private func defaultOutputDevice() throws -> AudioOutputDevice? {
    var address = defaultOutputAddress
    var deviceID = AudioObjectID(kAudioObjectUnknown)
    var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &dataSize,
      &deviceID
    )

    guard status == noErr else {
      throw AudioRouteError.defaultOutputReadFailed(status)
    }

    guard deviceID != kAudioObjectUnknown else {
      return nil
    }

    return outputDevices().first { outputDevice in
      outputDevice.id == deviceID
    }
  }

  private func audioDeviceIDs() throws -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0

    var status = AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &dataSize
    )

    guard status == noErr else {
      throw AudioRouteError.deviceListReadFailed(status)
    }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
    var deviceIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: deviceCount)

    status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &dataSize,
      &deviceIDs
    )

    guard status == noErr else {
      throw AudioRouteError.deviceListReadFailed(status)
    }

    return deviceIDs
  }

  private func hasOutputStreams(deviceID: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0

    let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)

    return status == noErr && dataSize > 0
  }

  private func stringProperty(
    deviceID: AudioObjectID,
    selector: AudioObjectPropertySelector
  ) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    var value: Unmanaged<CFString>?

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)

    guard status == noErr else {
      return nil
    }

    return value?.takeRetainedValue() as String?
  }

  private func uint32Property(
    deviceID: AudioObjectID,
    selector: AudioObjectPropertySelector
  ) -> UInt32? {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)

    guard status == noErr else {
      return nil
    }

    return value
  }

  private static func outputDevice(
    _ outputDevice: AudioOutputDevice,
    matches bluetoothDevice: BluetoothAudioDevice
  ) -> Bool {
    let outputUID = BluetoothAudioDevice.normalizedAddress(outputDevice.uid)
    let outputName = outputDevice.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let bluetoothName = bluetoothDevice.name.trimmingCharacters(in: .whitespacesAndNewlines)

    if !bluetoothDevice.normalizedAddress.isEmpty
      && outputUID.contains(bluetoothDevice.normalizedAddress)
    {
      return true
    }

    guard !outputName.isEmpty, !bluetoothName.isEmpty else {
      return false
    }

    return outputName.localizedCaseInsensitiveCompare(bluetoothName) == .orderedSame
      || outputName.localizedCaseInsensitiveContains(bluetoothName)
      || bluetoothName.localizedCaseInsensitiveContains(outputName)
  }
}
