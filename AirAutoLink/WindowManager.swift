import AppKit
import SwiftUI

/// 全局窗口管理器，用于以命令式且常驻内存的方式管理主控制面板窗口。
/// 这样可以确保在 Dock 图标和菜单栏图标均隐藏时，依然能可靠地打开和关闭窗口。
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
  static let shared = WindowManager()

  private var window: NSWindow?
  private var appState: AppState?

  private override init() {
    super.init()
  }

  /// 在应用启动时配置 AppState 引用
  func setup(appState: AppState) {
    self.appState = appState
  }

  /// 显示主控制面板窗口
  func showMainWindow() {
    // 如果窗口已经存在，直接将其带到最前显示
    if let window = window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    guard let appState = appState else {
      return
    }

    // 实例化 SwiftUI 主窗口视图，并用 NSHostingController 承载
    let contentView = MainWindowView(appState: appState)
    let hostingController = NSHostingController(rootView: contentView)

    // 创建底层的 NSWindow
    let win = NSWindow(contentViewController: hostingController)
    win.title = "AirAutoLink 控制面板"
    win.titleVisibility = .hidden
    win.titlebarAppearsTransparent = true
    win.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
    win.isMovableByWindowBackground = true
    win.delegate = self
    win.isReleasedWhenClosed = false // 关闭时不释放窗口，仅 orderOut

    // 设置固定宽高
    win.setContentSize(NSSize(width: 560, height: 380))
    // 在屏幕上居中
    win.center()

    self.window = win
    win.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - NSWindowDelegate

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    // 拦截关闭操作，仅移出屏幕（隐藏），防止 Window 被销毁后无法再次通过启动台拉起
    sender.orderOut(nil)
    return false
  }
}
