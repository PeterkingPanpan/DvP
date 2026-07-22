import CoreGraphics
import Foundation
import AppKit

final class InputManager {

    // MARK: - Key codes

    private enum KC {
        static let esc: Int64 = 53
        static let i: Int64   = 34
        static let j: Int64   = 38
        static let k: Int64   = 40
        static let l: Int64   = 37
        static let semicolon: Int64 = 41
        static let space: Int64 = 49
        static let n: Int64   = 45
        static let m: Int64   = 46
        static let o: Int64   = 31
        static let u: Int64   = 32
        static let h: Int64   = 4
        // 滚动 / 翻页
        static let w: Int64   = 13
        static let a: Int64   = 0
        static let s: Int64   = 1
        static let d: Int64   = 2
        static let ctrl: Int64 = 59
    }

    /// 每秒滚动像素
    private static let scrollSpeed: Double = 480

    // MARK: - State

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var heldKeys = Set<Int64>()
    private var firedClickKeys = Set<Int64>()
    private var isRunning = false
    private var updateTimer: Timer?
    private var cursorEngine = CursorEngine()

    // MARK: - Lifecycle

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
                let manager = Unmanaged<InputManager>
                    .fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
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
        firedClickKeys.removeAll()
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

    private func tick() {
        // ── 光标移动 ──
        let speedHeld = heldKeys.contains(KC.semicolon)
        let (dx, dy) = cursorEngine.update(
            heldKeys: heldKeys,
            speedKeyHeld: speedHeld,
            deltaTime: 1.0 / 120.0
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

        // ── 点击键（边沿触发：按下瞬间发射一次，松手重置）──
        func fireOnce(_ key: Int64, _ action: () -> Void) {
            if heldKeys.contains(key) {
                if !firedClickKeys.contains(key) {
                    firedClickKeys.insert(key)
                    action()
                }
            } else {
                firedClickKeys.remove(key)
            }
        }

        fireOnce(KC.space) { MouseController.click(button: .left) }
        fireOnce(KC.n)     { MouseController.click(button: .right) }
        fireOnce(KC.m)     { MouseController.click(button: .center) }
        fireOnce(KC.o)     { MouseController.keyPress(keyCode: 36) }
        fireOnce(KC.h)     { MouseController.warpToCenter() }

        // ── WASD：方向键 / 滚轮（Ctrl 切换语义）──
        // 用系统级 flags 而非 heldKeys：左右 Control 都生效
        let ctrlHeld = CGEventSource.flagsState(.hidSystemState)
            .contains(.maskControl)

        if !ctrlHeld {
            // WASD → 方向键（边沿触发）
            fireOnce(KC.w) { MouseController.keyPress(keyCode: 126) } // ↑
            fireOnce(KC.a) { MouseController.keyPress(keyCode: 123) } // ←
            fireOnce(KC.s) { MouseController.keyPress(keyCode: 125) } // ↓
            fireOnce(KC.d) { MouseController.keyPress(keyCode: 124) } // →
        } else {
            // Ctrl + W/S → 垂直滚轮，Ctrl + A/D → 水平滚轮（连续）
            let dt = 1.0 / 120.0
            var sx: Double = 0, sy: Double = 0
            if heldKeys.contains(KC.w) { sy -= Self.scrollSpeed * dt }
            if heldKeys.contains(KC.s) { sy += Self.scrollSpeed * dt }
            if heldKeys.contains(KC.a) { sx -= Self.scrollSpeed * dt }
            if heldKeys.contains(KC.d) { sx += Self.scrollSpeed * dt }
            if sx != 0 || sy != 0 {
                MouseController.scroll(dx: Int32(sx), dy: Int32(sy))
            }
        }
    }

    // MARK: - Event processing

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch type {
        case .keyDown:
            heldKeys.insert(keyCode)

            // Esc+I 和弦 — 始终检测
            if heldKeys.contains(KC.esc) && keyCode == KC.i {
                if AppState.shared.mode == .normal {
                    enterCursorMode()
                } else {
                    enterNormalMode()
                }
                return nil
            }

            // U：光标 → 输入（仅光标模式下）
            if AppState.shared.mode == .cursor && keyCode == KC.u {
                enterInputMode()
                return nil
            }

            // Esc+U：输入 → 光标
            if heldKeys.contains(KC.esc) && keyCode == KC.u {
                if AppState.shared.mode == .input { enterCursorMode() }
                return nil
            }

            // 光标模式 → 吞掉其余按键（移动/点击/滚动由 tick() 处理）
            if AppState.shared.mode == .cursor {
                return nil
            }

            // 输入模式 → 放行所有按键（Esc+I 已在上面处理）
            if AppState.shared.mode == .input {
                return Unmanaged.passUnretained(event)
            }

        case .keyUp:
            heldKeys.remove(keyCode)

            // 输入模式 → 放行
            if AppState.shared.mode == .input {
                return Unmanaged.passUnretained(event)
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func enterCursorMode() {
        AppState.shared.mode = .cursor
        heldKeys.removeAll()       // 清掉切换和弦的残留按键
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
