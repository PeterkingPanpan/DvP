import AppKit

final class PermissionManager {

    /// 检查是否已获得辅助功能权限
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 弹出系统权限请求对话框。用户会被引导到 系统设置 → 隐私与安全性 → 辅助功能
    /// 返回 true 表示弹窗前已经有权限了（极端情况）
    @discardableResult
    static func requestPermission() -> Bool {
        if isTrusted { return true }

        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    /// 轮询等待权限被授予。直到权限到位才返回。
    /// 用在关键路径上（如创建键盘 hook 前）
    static func waitForPermission(checkInterval: TimeInterval = 1.0) {
        while !isTrusted {
            requestPermission()
            Thread.sleep(forTimeInterval: checkInterval)
        }
    }
}
