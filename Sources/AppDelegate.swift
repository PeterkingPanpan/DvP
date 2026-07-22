import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let inputManager = InputManager()

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        setupMenu()

        // 注册模式变化回调
        AppState.shared.onModeChange = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon()
                self?.setupMenu()
            }
        }

        // 有权限就直接启动监听
        if PermissionManager.isTrusted {
            startInputMonitor()
        } else {
            PermissionManager.requestPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        inputManager.stop()
    }

    // MARK: - 键盘监听

    private func startInputMonitor() {
        do {
            try inputManager.start()
        } catch {
            let alert = NSAlert()
            alert.messageText = "启动失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - 图标颜色

    /// 深蓝色 — 替代系统灰
    private static let accentBlue = NSColor(
        red: 0.08, green: 0.38, blue: 0.75, alpha: 1.0
    )

    /// 给 SF Symbol 染色（非 template 才能在菜单栏显色）
    private static func tintedIcon(_ name: String, color: NSColor = accentBlue) -> NSImage? {
        guard let raw = NSImage(systemSymbolName: name,
                                accessibilityDescription: nil) else { return nil }
        let config = NSImage.SymbolConfiguration(hierarchicalColor: color)
        let tinted = raw.withSymbolConfiguration(config)
        tinted?.isTemplate = false
        return tinted
    }

    // MARK: - 菜单栏

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        if !PermissionManager.isTrusted {
            button.image = Self.tintedIcon("circle", color: .systemGray)
            button.toolTip = "wasd-cursor — 缺少辅助功能权限"
        } else {
            switch AppState.shared.mode {
            case .normal:
                button.image = Self.tintedIcon("circle.fill")
                button.toolTip = "wasd-cursor — 待机 (Esc+I 激活)"

            case .cursor:
                button.image = Self.tintedIcon("record.circle.fill")
                button.toolTip = "wasd-cursor — 光标模式 (Esc+I 退出)"

            case .input:
                button.image = Self.tintedIcon("circle.dotted")
                button.toolTip = "wasd-cursor — 输入模式 (Esc+U 返回)"
            }
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let perm = PermissionManager.isTrusted ? "✓" : "✗ 未授权"
        menu.addItem(NSMenuItem(
            title: "权限: \(perm)",
            action: nil,
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem(
            title: "模式: \(modeLabel)",
            action: nil,
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "重新检查权限",
            action: #selector(recheckPermission),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    private var modeLabel: String {
        switch AppState.shared.mode {
        case .normal: return "待机"
        case .cursor: return "光标控制"
        case .input:  return "临时输入"
        }
    }

    @objc private func recheckPermission() {
        if !PermissionManager.isTrusted {
            PermissionManager.requestPermission()
        }
        if PermissionManager.isTrusted {
            startInputMonitor()
        }
        updateMenuBarIcon()
        setupMenu()
    }
}
