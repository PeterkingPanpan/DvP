import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 图标风格

    private enum IconStyle {
        case fill      // 实心 — 光标模式
        case outline   // 描边 — 待机模式
        case dimmed    // 半透明 — 输入模式 / 无权限
    }

    // MARK: - 状态

    private var statusItem: NSStatusItem!
    private let inputManager = InputManager()
    private var permissionPoller: Timer?
    private var monitorStarted = false

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 单实例保护
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.nuturn.dvp"
        )
        if running.count > 1 {
            let alert = NSAlert()
            alert.messageText = "DvP 已在运行"
            alert.informativeText = "DvP 作为菜单栏应用运行，菜单栏右上角可见。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateMenuBarIcon()
        setupMenu()

        AppState.shared.onModeChange = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon()
                self?.setupMenu()
            }
        }

        // 首次启动尝试（没权限会弹一次系统授权窗）
        attemptStart(requestPermissionIfNeeded: true)

        // 轮询：用户去系统设置授权后自动感知
        permissionPoller = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true
        ) { [weak self] _ in
            self?.attemptStart(requestPermissionIfNeeded: false)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionPoller?.invalidate()
        inputManager.stop()
    }

    // MARK: - 权限与监听

    private func attemptStart(requestPermissionIfNeeded showPrompt: Bool) {
        guard !monitorStarted else { return }

        if PermissionManager.isTrusted {
            do {
                try inputManager.start()
                monitorStarted = true
                updateMenuBarIcon()
                setupMenu()
            } catch {}
        } else if showPrompt {
            // 只在启动时 / 手动点击「重新检查」时弹授权窗，轮询时静默
            PermissionManager.requestPermission()
            updateMenuBarIcon()
            setupMenu()
        }
    }

    // MARK: - 图标绘制

    /// 淡蓝 — 主色调 (RGB 140, 209, 255)
    private static let iconColor = NSColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1.0)

    private static func makeIcon(style: IconStyle) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        return NSImage(size: size, flipped: false) { rect in
            let font = NSFont.systemFont(ofSize: 12, weight: .bold)

            let color: NSColor
            let stroke: Double
            switch style {
            case .fill:
                color = iconColor
                stroke = 0
            case .outline:
                color = iconColor
                stroke = 1.5
            case .dimmed:
                color = iconColor.withAlphaComponent(0.5)
                stroke = 0
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .strokeWidth: stroke,
                .kern: -0.5,
            ]
            let text = "DvP" as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
            return true
        }
    }

    // MARK: - 菜单栏

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        if !PermissionManager.isTrusted {
            button.image = Self.makeIcon(style: .dimmed)
            button.toolTip = "DvP — 缺少辅助功能权限"
            return
        }

        switch AppState.shared.mode {
        case .normal:
            button.image = Self.makeIcon(style: .outline)
            button.toolTip = "DvP — 待机 (Esc+I 激活)"
        case .cursor:
            button.image = Self.makeIcon(style: .fill)
            button.toolTip = "DvP — 光标模式 (Esc+I 退出)"
        case .input:
            button.image = Self.makeIcon(style: .dimmed)
            button.toolTip = "DvP — 输入模式 (Esc+U 返回)"
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let hasPerm = PermissionManager.isTrusted
        menu.addItem(NSMenuItem(
            title: "权限: \(hasPerm ? "✓" : "✗ 未授权")",
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
        monitorStarted = false
        attemptStart(requestPermissionIfNeeded: true)
    }
}
