import Foundation

struct BluetoothAudioDevice: Codable, Equatable, Identifiable, Sendable {
  let name: String
  let address: String
  let isConnected: Bool
  let isPinned: Bool

  var id: String {
    normalizedAddress
  }

  var normalizedAddress: String {
    Self.normalizedAddress(address)
  }

  init(name: String, address: String, isConnected: Bool, isPinned: Bool = false) {
    self.name = name
    self.address = address
    self.isConnected = isConnected
    self.isPinned = isPinned
  }

  func withConnectionState(_ isConnected: Bool) -> BluetoothAudioDevice {
    BluetoothAudioDevice(
      name: name,
      address: address,
      isConnected: isConnected,
      isPinned: isPinned
    )
  }

  func withPinnedState(_ isPinned: Bool) -> BluetoothAudioDevice {
    BluetoothAudioDevice(
      name: name,
      address: address,
      isConnected: isConnected,
      isPinned: isPinned
    )
  }

  // 蓝牙地址在系统不同 API 里可能使用冒号、连字符或纯十六进制。
  // 统一成小写十六进制字符串后，才能稳定匹配 IOBluetooth 与 CoreAudio 的设备标识。
  static func normalizedAddress(_ value: String) -> String {
    value
      .lowercased()
      .filter { character in
        character.isHexDigit
      }
  }
}
