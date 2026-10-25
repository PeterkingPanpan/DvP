import Foundation
import CoreGraphics

/// 单个键帽的布局描述
struct KeyCap {
    let keyCode: Int64
    let label: String
    let width: CGFloat   // 以「1 个标准键宽」为单位
}

/// 全键盘布局数据 + 键码 → 标签查询
enum KeyLayout {

    /// 标准键宽（点）
    static let unit: CGFloat = 48
    static let keyHeight: CGFloat = 48
    static let spacing: CGFloat = 5

    /// 系统保留键（模式切换 / 加速），不可重映射
    static let reservedKeyCodes: Set<Int64> = [53, 32, 41]  // Esc, U, 分号

    static let rows: [[KeyCap]] = [
        // 功能键行
        [
            KeyCap(keyCode: 53, label: "esc", width: 1),
            KeyCap(keyCode: 122, label: "F1", width: 1),
            KeyCap(keyCode: 120, label: "F2", width: 1),
            KeyCap(keyCode: 99, label: "F3", width: 1),
            KeyCap(keyCode: 118, label: "F4", width: 1),
            KeyCap(keyCode: 96, label: "F5", width: 1),
            KeyCap(keyCode: 97, label: "F6", width: 1),
            KeyCap(keyCode: 98, label: "F7", width: 1),
            KeyCap(keyCode: 100, label: "F8", width: 1),
            KeyCap(keyCode: 101, label: "F9", width: 1),
            KeyCap(keyCode: 109, label: "F10", width: 1),
            KeyCap(keyCode: 103, label: "F11", width: 1),
            KeyCap(keyCode: 111, label: "F12", width: 1),
        ],
        // 数字行
        [
            KeyCap(keyCode: 50, label: "`", width: 1),
            KeyCap(keyCode: 18, label: "1", width: 1),
            KeyCap(keyCode: 19, label: "2", width: 1),
            KeyCap(keyCode: 20, label: "3", width: 1),
            KeyCap(keyCode: 21, label: "4", width: 1),
            KeyCap(keyCode: 23, label: "5", width: 1),
            KeyCap(keyCode: 22, label: "6", width: 1),
            KeyCap(keyCode: 26, label: "7", width: 1),
            KeyCap(keyCode: 28, label: "8", width: 1),
            KeyCap(keyCode: 25, label: "9", width: 1),
            KeyCap(keyCode: 29, label: "0", width: 1),
            KeyCap(keyCode: 27, label: "-", width: 1),
            KeyCap(keyCode: 24, label: "=", width: 1),
            KeyCap(keyCode: 51, label: "⌫", width: 2),
        ],
        // Q 行
        [
            KeyCap(keyCode: 48, label: "⇥", width: 1.5),
            KeyCap(keyCode: 12, label: "Q", width: 1),
            KeyCap(keyCode: 13, label: "W", width: 1),
            KeyCap(keyCode: 14, label: "E", width: 1),
            KeyCap(keyCode: 15, label: "R", width: 1),
            KeyCap(keyCode: 17, label: "T", width: 1),
            KeyCap(keyCode: 16, label: "Y", width: 1),
            KeyCap(keyCode: 32, label: "U", width: 1),
            KeyCap(keyCode: 34, label: "I", width: 1),
            KeyCap(keyCode: 31, label: "O", width: 1),
            KeyCap(keyCode: 35, label: "P", width: 1),
            KeyCap(keyCode: 33, label: "[", width: 1),
            KeyCap(keyCode: 30, label: "]", width: 1),
            KeyCap(keyCode: 42, label: "\\", width: 1.5),
        ],
        // Home 行
        [
            KeyCap(keyCode: 57, label: "⇪", width: 1.75),
            KeyCap(keyCode: 0, label: "A", width: 1),
            KeyCap(keyCode: 1, label: "S", width: 1),
            KeyCap(keyCode: 2, label: "D", width: 1),
            KeyCap(keyCode: 3, label: "F", width: 1),
            KeyCap(keyCode: 5, label: "G", width: 1),
            KeyCap(keyCode: 4, label: "H", width: 1),
            KeyCap(keyCode: 38, label: "J", width: 1),
            KeyCap(keyCode: 40, label: "K", width: 1),
            KeyCap(keyCode: 37, label: "L", width: 1),
            KeyCap(keyCode: 41, label: ";", width: 1),
            KeyCap(keyCode: 39, label: "'", width: 1),
            KeyCap(keyCode: 36, label: "↩", width: 2.25),
        ],
        // 底字母行
        [
            KeyCap(keyCode: 56, label: "⇧", width: 2.25),
            KeyCap(keyCode: 6, label: "Z", width: 1),
            KeyCap(keyCode: 7, label: "X", width: 1),
            KeyCap(keyCode: 8, label: "C", width: 1),
            KeyCap(keyCode: 9, label: "V", width: 1),
            KeyCap(keyCode: 11, label: "B", width: 1),
            KeyCap(keyCode: 45, label: "N", width: 1),
            KeyCap(keyCode: 46, label: "M", width: 1),
            KeyCap(keyCode: 43, label: ",", width: 1),
            KeyCap(keyCode: 47, label: ".", width: 1),
            KeyCap(keyCode: 44, label: "/", width: 1),
            KeyCap(keyCode: 60, label: "⇧", width: 2.75),
        ],
        // 修饰键 + 空格
        [
            KeyCap(keyCode: 63, label: "fn", width: 1),
            KeyCap(keyCode: 59, label: "⌃", width: 1.25),
            KeyCap(keyCode: 58, label: "⌥", width: 1.25),
            KeyCap(keyCode: 55, label: "⌘", width: 1.25),
            KeyCap(keyCode: 49, label: "空格", width: 6.25),
            KeyCap(keyCode: 55, label: "⌘", width: 1.25),
            KeyCap(keyCode: 61, label: "⌥", width: 1.25),
            KeyCap(keyCode: 59, label: "⌃", width: 1.25),
        ],
        // 方向键
        [
            KeyCap(keyCode: 123, label: "←", width: 1),
            KeyCap(keyCode: 125, label: "↓", width: 1),
            KeyCap(keyCode: 124, label: "→", width: 1),
            KeyCap(keyCode: 126, label: "↑", width: 1),
        ],
    ]

    /// 键码 → 显示标签（用于热键回显）
    static let labelByCode: [Int64: String] = {
        var m: [Int64: String] = [:]
        for row in rows {
            for cap in row { m[cap.keyCode] = cap.label }
        }
        return m
    }()

    static func label(for keyCode: Int64) -> String {
        labelByCode[keyCode] ?? "键\(keyCode)"
    }

    /// 把录制到的组合键渲染成「⌘⇧C」这类标签
    static func hotkeyString(keyCode: Int64, flags: UInt64) -> String {
        var out = ""
        let f = CGEventFlags(rawValue: flags)
        if f.contains(.maskControl) { out += "⌃" }
        if f.contains(.maskAlternate) { out += "⌥" }
        if f.contains(.maskShift) { out += "⇧" }
        if f.contains(.maskCommand) { out += "⌘" }
        out += label(for: keyCode)
        return out
    }
}
