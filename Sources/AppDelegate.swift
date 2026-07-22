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

    // MARK: - 菜单栏

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        if !PermissionManager.isTrusted {
            button.image = NSImage(
                systemSymbolName: "circle",
                accessibilityDescription: "无权限"
            )
            button.toolTip = "wasd-cursor — 缺少辅助功能权限"
        } else {
            switch AppState.shared.mode {
            case .normal:
                button.image = NSImage(
                    systemSymbolName: "circle.fill",
                    accessibilityDescription: "待机"
                )
                button.toolTip = "wasd-cursor — 待机 (Esc+I 激活)"

            case .cursor:
                button.image = NSImage(
                    systemSymbolName: "record.circle.fill",
                    accessibilityDescription: "光标模式"
                )
                button.toolTip = "wasd-cursor — 光标模式 (Esc+I 退出)"

            case .input:
                button.image = NSImage(
                    systemSymbolName: "circle.dotted",
                    accessibilityDescription: "输入模式"
                )
                button.toolTip = "wasd-cursor — 输入模式 (Esc+I 退出)"
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
