import CoreGraphics
import Foundation
import AppKit
import Combine

final class InputManager: ObservableObject {

    static let shared = InputManager()

    // MARK: - 系统保留键（模式切换），不参与重映射

    private enum KC {
        static let esc: Int64 = 53
        static let u: Int64 = 32
        static let i: Int64 = 34
    }

    /// 加速键（按住翻倍），v1 固定为分号
    static let speedKeyCode: Int64 = 41

    /// 滚轮速度（像素/秒）
    private static let scrollSpeed: Double = 480

    // MARK: - 状态

    /// 当前按住的键（供键盘可视化实时高亮）
    @Published private(set) var heldKeys = Set<Int64>()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var firedKeys = Set<Int64>()
    private var isRunning = false
    private var updateTimer: Timer?
    private var cursorEngine = CursorEngine()

    private init() {}

    // MARK: - 生命周期

    func start() throws {
        guard PermissionManager.isTrusted else { throw WasdError.noPermission }
        guard !isRunning else { return }

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                Unmanaged<InputManager>
                    .fromOpaque(refcon!).takeUnretainedValue()
                    .handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            throw WasdError.tapCreationFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    func stop() {
        stopUpdateLoop()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    // MARK: - Update loop (120 Hz)

    private func startUpdateLoop() {
        stopUpdateLoop()
        cursorEngine.reset()
        firedKeys.removeAll()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 120.0,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - 每帧逻辑

    private func tick() {
        let dt = 1.0 / 120.0
        let map = ConfigStore.shared.keyMap

        // ── 光标移动 ──
        syncEngineParams()
        let speedHeld = heldKeys.contains(Self.speedKeyCode)
        let (dx, dy) = cursorEngine.update(
            moveUp: directionHeld(.up, map),
            moveDown: directionHeld(.down, map),
            moveLeft: directionHeld(.left, map),
            moveRight: directionHeld(.right, map),
            speedKeyHeld: speedHeld,
            deltaTime: dt
        )
        if dx != 0 || dy != 0 {
            MouseController.move(dx: dx, dy: dy)
        }

        // ── 撞墙检测：到屏幕边缘立即清零该方向速度 ──
        if let screen = NSScreen.main {
            let pos = MouseController.currentMousePosition
            let w = screen.frame.width
            let h = screen.frame.height
            let margin: CGFloat = 2
            cursorEngine.killVelocity(
                x: pos.x <= margin || pos.x >= w - margin,
                y: pos.y <= margin || pos.y >= h - margin
            )
        }

        // ── 拖拽（按住 = mouseDown，松开 = mouseUp）──
        handleDrag(map)

        // ── 边沿触发动作 ──
        let shiftHeld = CGEventSource.flagsState(.hidSystemState).contains(.maskShift)
        for keyCode in heldKeys {
            guard let action = map[keyCode] else { continue }
            switch action {
            case .move, .drag, .scroll, .unbound:
                break  // move 由引擎处理；drag/scroll 单独处理
            case .click(let type):
                fireOnce(keyCode) { Self.performClick(type) }
            case .enter:
                fireOnce(keyCode) { MouseController.keyPress(keyCode: 36) }  // Return
            case .warpCenter:
                fireOnce(keyCode) { MouseController.warpToCenter() }
            case .arrowKey(let dir):
                if !shiftHeld {
                    fireOnce(keyCode) { MouseController.keyPress(keyCode: dir.arrowKeyCode) }
                }
                // Shift + 方向键 → 由下面的滚动段处理
            case .hotkey(let kc, let fl):
                fireOnce(keyCode) { MouseController.keyPress(keyCode: kc, flags: CGEventFlags(rawValue: fl)) }
            }
        }

        // ── 滚动（持续；Shift + 方向键也在此处理）──
        var sx: Double = 0, sy: Double = 0
        for keyCode in heldKeys {
            guard let action = map[keyCode] else { continue }
            let dir: Direction?
            switch action {
            case .scroll(let d): dir = d
            case .arrowKey(let d): dir = shiftHeld ? d : nil
            default: dir = nil
            }
            guard let d = dir else { continue }
            switch d {
            case .up: sy -= Self.scrollSpeed * dt
            case .down: sy += Self.scrollSpeed * dt
            case .left: sx -= Self.scrollSpeed * dt
            case .right: sx += Self.scrollSpeed * dt
            }
        }
        if sx != 0 || sy != 0 {
            MouseController.scroll(dx: Int32(sx), dy: Int32(sy))
        }

        // ── 清理：松开后允许下次再触发 ──
        for key in firedKeys where !heldKeys.contains(key) {
            firedKeys.remove(key)
        }
    }

    // MARK: - 动作分派辅助

    private func syncEngineParams() {
        let s = ConfigStore.shared.speed
        cursorEngine.baseSpeed = s.baseSpeed
        cursorEngine.shiftMultiplier = s.shiftMultiplier
        cursorEngine.maxSpeed = s.maxSpeed
        cursorEngine.smoothing = s.smoothing
        cursorEngine.sigmoidMidpoint = s.sigmoidMidpoint
        cursorEngine.sigmoidSteepness = s.sigmoidSteepness
        cursorEngine.accelerationCap = s.accelerationCap
        cursorEngine.negativeInertia = s.negativeInertia
    }

    private func directionHeld(_ dir: Direction, _ map: [Int64: KeyAction]) -> Bool {
        heldKeys.contains { map[$0] == .move(dir) }
    }

    private func handleDrag(_ map: [Int64: KeyAction]) {
        if let key = heldKeys.first(where: { map[$0] == .drag }) {
            if !firedKeys.contains(key) {
                firedKeys.insert(key)
                MouseController.mouseDown(button: .left)
            }
        }
        if let released = firedKeys.first(where: { !heldKeys.contains($0) && map[$0] == .drag }) {
            firedKeys.remove(released)
            MouseController.mouseUp(button: .left)
        }
    }

    private func fireOnce(_ key: Int64, _ action: () -> Void) {
        if !firedKeys.contains(key) {
            firedKeys.insert(key)
            action()
        }
    }

    private static func performClick(_ type: ClickType) {
        switch type {
        case .leftClick: MouseController.click(button: .left)
        case .leftDouble: MouseController.doubleClick()
        case .rightClick: MouseController.click(button: .right)
        case .middleClick: MouseController.click(button: .center)
        }
    }

    // MARK: - 事件处理

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch type {
        case .keyDown:
            heldKeys.insert(keyCode)

            // Esc+I — 始终生效：切换 待机 ↔ 光标
            if heldKeys.contains(KC.esc) && keyCode == KC.i {
                AppState.shared.mode == .normal
                    ? enterCursorMode()
                    : enterNormalMode()
                return nil
            }

            // Esc+U — 输入 → 光标
            if heldKeys.contains(KC.esc) && keyCode == KC.u {
                if AppState.shared.mode == .input { enterCursorMode() }
                return nil
            }

            // U — 光标 → 输入
            if AppState.shared.mode == .cursor && keyCode == KC.u {
                enterInputMode()
                return nil
            }

            // 光标模式：Cmd/Opt/Ctrl 修饰键 → 放行系统快捷键，其余消费
            if AppState.shared.mode == .cursor {
                let flags = CGEventSource.flagsState(.hidSystemState)
                let isShortcut = flags.contains(.maskCommand)
                    || flags.contains(.maskAlternate)
                    || flags.contains(.maskControl)
                if isShortcut { return Unmanaged.passUnretained(event) }
                return nil
            }

            // 输入模式 → 全部放行
            if AppState.shared.mode == .input {
                return Unmanaged.passUnretained(event)
            }

        case .keyUp:
            heldKeys.remove(keyCode)

            if AppState.shared.mode == .input {
                return Unmanaged.passUnretained(event)
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - 模式切换

    private func enterCursorMode() {
        AppState.shared.mode = .cursor
        heldKeys.removeAll()
        startUpdateLoop()
    }

    private func enterNormalMode() {
        AppState.shared.mode = .normal
        heldKeys.removeAll()
        stopUpdateLoop()
    }

    private func enterInputMode() {
        AppState.shared.mode = .input
        heldKeys.removeAll()
        stopUpdateLoop()
    }
}

// MARK: - Errors

enum WasdError: Error {
    case noPermission
    case tapCreationFailed
}
