import CoreGraphics
import AppKit

/// 所有系统级鼠标事件注入
enum MouseController {

    // MARK: - 移动

    /// 相对移动光标（dx/dy 为像素偏移）
    static func move(dx: Double, dy: Double) {
        let pos = currentMousePosition  // Quartz 坐标（左上角原点）
        let newX = pos.x + dx
        let newY = pos.y + dy

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: CGPoint(x: newX, y: newY),
            mouseButton: .left
        ) else { return }

        event.post(tap: .cghidEventTap)
    }

    // MARK: - 点击

    static func click(button: CGMouseButton) {
        let pos = currentMousePosition

        guard
            let down = CGEvent(
                mouseEventSource: nil,
                mouseType: downType(for: button),
                mouseCursorPosition: pos,
                mouseButton: button
            ),
            let up = CGEvent(
                mouseEventSource: nil,
                mouseType: upType(for: button),
                mouseCursorPosition: pos,
                mouseButton: button
            )
        else { return }

        down.post(tap: .cghidEventTap)
        usleep(10_000)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - 按键

    static func keyPress(keyCode: Int64) {
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false)
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
    private static var currentMousePosition: CGPoint {
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
