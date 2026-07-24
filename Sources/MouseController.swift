import CoreGraphics
import AppKit

/// 所有系统级鼠标事件注入
enum MouseController {

    // MARK: - 拖拽状态

    private static var isLeftDown = false

    // MARK: - 移动

    /// 相对移动光标（dx/dy 为像素偏移）
    static func move(dx: Double, dy: Double) {
        let pos = currentMousePosition
        let newX = pos.x + dx
        let newY = pos.y + dy

        let type: CGEventType = isLeftDown ? .leftMouseDragged : .mouseMoved
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: CGPoint(x: newX, y: newY),
            mouseButton: .left
        ) else { return }

        event.post(tap: .cghidEventTap)
    }

    // MARK: - 点击

    static func click(button: CGMouseButton) {
        let pos = currentMousePosition

        guard let down = CGEvent(
            mouseEventSource: nil,
            mouseType: downType(for: button),
            mouseCursorPosition: pos,
            mouseButton: button
        ) else { return }

        down.post(tap: .cghidEventTap)
        usleep(10_000)

        guard let up = CGEvent(
            mouseEventSource: nil,
            mouseType: upType(for: button),
            mouseCursorPosition: pos,
            mouseButton: button
        ) else { return }

        up.post(tap: .cghidEventTap)
    }

    /// 双击左键 — 两次点击间隔约 50ms，macOS 原生双击识别范围内
    static func doubleClick() {
        click(button: .left)
        usleep(50_000)
        click(button: .left)
    }

    // MARK: - 按住 / 松开（拖拽用）

    static func mouseDown(button: CGMouseButton) {
        if button == .left { isLeftDown = true }
        guard let down = CGEvent(
            mouseEventSource: nil,
            mouseType: downType(for: button),
            mouseCursorPosition: currentMousePosition,
            mouseButton: button
        ) else { return }
        down.post(tap: .cghidEventTap)
    }

    static func mouseUp(button: CGMouseButton) {
        if button == .left { isLeftDown = false }
        guard let up = CGEvent(
            mouseEventSource: nil,
            mouseType: upType(for: button),
            mouseCursorPosition: currentMousePosition,
            mouseButton: button
        ) else { return }
        up.post(tap: .cghidEventTap)
    }

    // MARK: - 瞬移

    /// 将光标移到主屏幕正中央
    static func warpToCenter() {
        guard let screen = NSScreen.main else { return }
        // NSScreen.frame 是左下原点，转成 Quartz 左上原点
        let quartzY = screen.frame.height - screen.frame.midY
        let center = CGPoint(x: screen.frame.midX, y: quartzY)

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: center,
            mouseButton: .left
        ) else { return }

        event.post(tap: .cghidEventTap)
    }

    // MARK: - 按键

    static func keyPress(keyCode: Int64) {
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true),
            let up   = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false)
        else { return }

        down.post(tap: .cghidEventTap)
        usleep(5_000)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - 滚动

    static func scroll(dx: Int32, dy: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else { return }

        event.post(tap: .cghidEventTap)
    }

    // MARK: - 坐标

    /// 当前鼠标位置，Quartz 坐标系（左上角为原点）
    static var currentMousePosition: CGPoint {
        let nsPoint = NSEvent.mouseLocation            // 左下角原点
        let screenHeight = NSScreen.main?.frame.height ?? 900
        return CGPoint(
            x: nsPoint.x,
            y: screenHeight - nsPoint.y                // 翻转为左上角原点
        )
    }

    // MARK: - Helpers

    private static func downType(for button: CGMouseButton) -> CGEventType {
        switch button {
        case .left:  return .leftMouseDown
        case .right: return .rightMouseDown
        default:     return .otherMouseDown
        }
    }

    private static func upType(for button: CGMouseButton) -> CGEventType {
        switch button {
        case .left:  return .leftMouseUp
        case .right: return .rightMouseUp
        default:     return .otherMouseUp
        }
    }
}
