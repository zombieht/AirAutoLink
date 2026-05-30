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
      // 未配置蓝牙设备时，显示带斜线的水平闪电图标作为项目 Logo 的未激活状态
      return "bolt.horizontal.slash"
    case .ready:
      // 准备好连接但未激活时，显示空心水平闪电图标
      return "bolt.horizontal"
    case .retrying:
      // 正在连接中，显示旋转的同步箭头，提供直观的动画感
      return "arrow.triangle.2.circlepath"
    case .connected:
      // 连接成功后，显示实心水平闪电图标表示已激活
      return "bolt.horizontal.fill"
    case .failed:
      // 连接失败时，显示警告三角图标
      return "exclamationmark.triangle"
    case .loginItemRequiresApproval:
      // 需要登录项审批时，显示齿轮与问号图标
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
