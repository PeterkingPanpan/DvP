import Foundation

/// 系统模式
enum SystemMode {
    case normal   // 正常打字
    case cursor   // 光标控制
    case input    // 临时输入
}

/// 线程安全的状态持有者
final class AppState {
    static let shared = AppState()

    var mode: SystemMode = .normal {
        didSet { onModeChange?(mode) }
    }

    /// UI 层注册回调以响应模式变化
    var onModeChange: ((SystemMode) -> Void)?

    private init() {}
}
