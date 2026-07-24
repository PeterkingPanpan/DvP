import AppKit

/// 辅助功能权限的检查与请求
enum PermissionManager {

    /// 检查是否已获得辅助功能权限
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 弹出系统权限请求对话框。用户会被引导到 系统设置 → 隐私与安全性 → 辅助功能。
    /// 如果已有权限则直接返回 true，不弹窗。
    @discardableResult
    static func requestPermission() -> Bool {
        if isTrusted { return true }

        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }
}
