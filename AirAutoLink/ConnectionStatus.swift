import Foundation

enum ConnectionStatus: Equatable {
  case noTarget
  case ready(targetName: String)
  case retrying(targetName: String, attempt: Int, maxAttempts: Int)
  case connected(targetName: String)
  case failed(message: String)
  case loginItemRequiresApproval

  var title: String {
    switch self {
    case .noTarget:
      return "未配置蓝牙音响"
    case let .ready(targetName):
      return "准备连接：\(targetName)"
    case let .retrying(targetName, attempt, maxAttempts):
      return "正在连接：\(targetName)（\(attempt)/\(maxAttempts)）"
    case let .connected(targetName):
      return "已连接：\(targetName)"
    case let .failed(message):
      return message
    case .loginItemRequiresApproval:
      return "登录项需要在系统设置中批准"
    }
  }

  var systemImageName: String {
    switch self {
    case .noTarget:
      return "speaker.slash"
    case .ready:
      return "speaker.wave.2"
    case .retrying:
      return "arrow.triangle.2.circlepath"
    case .connected:
      return "speaker.wave.3"
    case .failed:
      return "exclamationmark.triangle"
    case .loginItemRequiresApproval:
      return "gear.badge.questionmark"
    }
  }

  var isWorking: Bool {
    if case .retrying = self {
      return true
    }

    return false
  }
}
