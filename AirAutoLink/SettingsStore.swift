import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
  @Published private(set) var pinnedDevice: BluetoothAudioDevice?
  @Published private(set) var recentDevice: BluetoothAudioDevice?
  @Published private(set) var launchesAtLogin = false
  @Published private(set) var loginItemRequiresApproval = false
  @Published var automaticallySwitchesOutput: Bool {
    didSet {
      userDefaults.set(automaticallySwitchesOutput, forKey: Key.automaticallySwitchesOutput)
    }
  }

  private enum Key {
    static let pinnedDevice = "pinnedDevice"
    static let recentDevice = "recentDevice"
    static let automaticallySwitchesOutput = "automaticallySwitchesOutput"
    static let launchesAtLogin = "launchesAtLogin"
  }

  private let userDefaults: UserDefaults
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    self.automaticallySwitchesOutput =
      userDefaults.object(forKey: Key.automaticallySwitchesOutput) as? Bool ?? true
    self.pinnedDevice = Self.readDevice(forKey: Key.pinnedDevice, from: userDefaults)
    self.recentDevice = Self.readDevice(forKey: Key.recentDevice, from: userDefaults)
    refreshLoginItemStatus()
  }

  func setPinnedDevice(_ device: BluetoothAudioDevice?) {
    pinnedDevice = device?.withPinnedState(true)
    writeDevice(pinnedDevice, forKey: Key.pinnedDevice)
  }

  func setRecentDevice(_ device: BluetoothAudioDevice) {
    let storedDevice = device.withPinnedState(false)

    guard recentDevice != storedDevice else {
      return
    }

    recentDevice = storedDevice
    writeDevice(storedDevice, forKey: Key.recentDevice)
  }

  func refreshLoginItemStatus() {
    switch SMAppService.mainApp.status {
    case .enabled:
      launchesAtLogin = true
      loginItemRequiresApproval = false
    case .requiresApproval:
      launchesAtLogin = false
      loginItemRequiresApproval = true
    case .notRegistered, .notFound:
      launchesAtLogin = false
      loginItemRequiresApproval = false
    @unknown default:
      launchesAtLogin = false
      loginItemRequiresApproval = false
    }

    userDefaults.set(launchesAtLogin, forKey: Key.launchesAtLogin)
  }

  func setLaunchesAtLogin(_ enabled: Bool) throws {
    // SMAppService.mainApp 负责把当前 App 注册为登录项；该 API 要求 App 已签名。
    // 本项目本机自用时采用 Xcode/Debug 签名即可，不额外嵌入 helper。
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }

    refreshLoginItemStatus()
  }

  private static func readDevice(forKey key: String, from userDefaults: UserDefaults)
    -> BluetoothAudioDevice?
  {
    guard let data = userDefaults.data(forKey: key) else {
      return nil
    }

    return try? JSONDecoder().decode(BluetoothAudioDevice.self, from: data)
  }

  private func writeDevice(_ device: BluetoothAudioDevice?, forKey key: String) {
    guard let device else {
      userDefaults.removeObject(forKey: key)
      return
    }

    guard let data = try? encoder.encode(device) else {
      return
    }

    userDefaults.set(data, forKey: key)
  }
}
