import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
  let settingsStore: SettingsStore
  let bluetoothDeviceService: BluetoothDeviceService
  let audioRouteService: AudioRouteService
  let reconnectCoordinator: ReconnectCoordinator

  init() {
    let settingsStore = SettingsStore()
    let bluetoothDeviceService = BluetoothDeviceService()
    let audioRouteService = AudioRouteService()

    self.settingsStore = settingsStore
    self.bluetoothDeviceService = bluetoothDeviceService
    self.audioRouteService = audioRouteService
    self.reconnectCoordinator = ReconnectCoordinator(
      settingsStore: settingsStore,
      bluetoothDeviceService: bluetoothDeviceService,
      audioRouteService: audioRouteService
    )

    audioRouteService.defaultOutputChanged = { [weak self] outputDevice in
      self?.recordRecentBluetoothOutput(outputDevice)
    }

    recordRecentBluetoothOutput(audioRouteService.currentOutputDevice)
    reconnectCoordinator.startLoginReconnect()
  }

  func connectNow() {
    reconnectCoordinator.connectNow()
  }

  func cancelReconnect() {
    reconnectCoordinator.cancelReconnect()
  }

  func refreshDevices() {
    bluetoothDeviceService.refreshPairedAudioDevices()
    reconnectCoordinator.refreshStatusFromTarget()
  }

  func setPinnedDevice(_ device: BluetoothAudioDevice) {
    settingsStore.setPinnedDevice(device)
    reconnectCoordinator.refreshStatusFromTarget()
  }

  func clearPinnedDevice() {
    settingsStore.setPinnedDevice(nil)
    reconnectCoordinator.refreshStatusFromTarget()
  }

  func useRecentDevice() {
    settingsStore.setPinnedDevice(nil)
    reconnectCoordinator.refreshStatusFromTarget()
  }

  func setLaunchesAtLogin(_ enabled: Bool) {
    do {
      try settingsStore.setLaunchesAtLogin(enabled)
    } catch {
      reconnectCoordinator.refreshStatusFromTarget()
    }
  }

  func openBluetoothSettings() {
    openSettingsPane("x-apple.systempreferences:com.apple.BluetoothSettings")
  }

  func openSoundSettings() {
    openSettingsPane("x-apple.systempreferences:com.apple.Sound-Settings.extension")
  }

  private func recordRecentBluetoothOutput(_ outputDevice: AudioOutputDevice?) {
    guard let outputDevice else {
      return
    }

    bluetoothDeviceService.refreshPairedAudioDevices()

    guard let bluetoothDevice = audioRouteService.matchingBluetoothDevice(
      for: outputDevice,
      in: bluetoothDeviceService.pairedAudioDevices
    ) else {
      return
    }

    settingsStore.setRecentDevice(bluetoothDevice)
    reconnectCoordinator.refreshStatusFromTarget()
  }

  private func openSettingsPane(_ urlString: String) {
    guard let url = URL(string: urlString) else {
      return
    }

    NSWorkspace.shared.open(url)
  }
}
