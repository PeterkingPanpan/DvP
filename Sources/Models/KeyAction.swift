import Foundation

/// 移动 / 滚动方向
enum Direction: String, Codable, CaseIterable {
    case up, down, left, right

    var label: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        }
    }

    /// 对应的系统方向键虚拟键码
    var arrowKeyCode: Int64 {
        switch self {
        case .up: return 126
        case .down: return 125
        case .left: return 123
        case .right: return 124
        }
    }
}

/// 点击类型
enum ClickType: String, Codable, CaseIterable {
    case leftClick, leftDouble, rightClick, middleClick

    var label: String {
        switch self {
        case .leftClick: return "左键单击"
        case .leftDouble: return "左键双击"
        case .rightClick: return "右键单击"
        case .middleClick: return "中键单击"
        }
    }
}

/// 某个键被映射成的动作（单一动作，无序列宏）
enum KeyAction: Codable, Equatable {
    case move(Direction)            // 光标移动（IJKL）
    case click(ClickType)           // 点击
    case drag                       // 按住拖拽（Space 语义）
    case enter                      // 回车
    case warpCenter                 // 瞬移到屏幕中心
    case arrowKey(Direction)        // 方向键（按住 Shift 变滚轮）
    case scroll(Direction)          // 滚轮
    case hotkey(keyCode: Int64, flags: UInt64)  // 录制的组合键
    case unbound                    // 未绑定（放行不拦截）

    var label: String {
        switch self {
        case .move(let d): return "光标移动 \(d.label)"
        case .click(let t): return t.label
        case .drag: return "按住拖拽"
        case .enter: return "回车"
        case .warpCenter: return "瞬移到屏幕中心"
        case .arrowKey(let d): return "方向键 \(d.label)"
        case .scroll(let d): return "滚轮 \(d.label)"
        case .hotkey(let k, let f): return "快捷键 \(KeyLayout.hotkeyString(keyCode: k, flags: f))"
        case .unbound: return "未绑定"
        }
    }

    // MARK: - Codable（紧凑字符串形式，便于人类阅读 config.json）

    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        let parts = s.split(separator: ":").map(String.init)
        switch parts.first {
        case "move": self = .move(Direction(rawValue: parts[1]) ?? .up)
        case "click": self = .click(ClickType(rawValue: parts[1]) ?? .leftClick)
        case "drag": self = .drag
        case "enter": self = .enter
        case "warpCenter": self = .warpCenter
        case "arrowKey": self = .arrowKey(Direction(rawValue: parts[1]) ?? .up)
        case "scroll": self = .scroll(Direction(rawValue: parts[1]) ?? .up)
        case "hotkey":
            self = .hotkey(keyCode: Int64(parts[1]) ?? 0, flags: UInt64(parts[2]) ?? 0)
        default: self = .unbound
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .move(let d): try c.encode("move:\(d.rawValue)")
        case .click(let t): try c.encode("click:\(t.rawValue)")
        case .drag: try c.encode("drag")
        case .enter: try c.encode("enter")
        case .warpCenter: try c.encode("warpCenter")
        case .arrowKey(let d): try c.encode("arrowKey:\(d.rawValue)")
        case .scroll(let d): try c.encode("scroll:\(d.rawValue)")
        case .hotkey(let k, let f): try c.encode("hotkey:\(k):\(f)")
        case .unbound: try c.encode("unbound")
        }
    }
}

/// 一条键位绑定
struct KeyBinding: Codable, Equatable {
    var keyCode: Int64
    var action: KeyAction
}

/// 速度引擎的可调参数
struct SpeedConfig: Codable, Equatable {
    var baseSpeed: Double = 35
    var shiftMultiplier: Double = 2.0
    var maxSpeed: Double = 3500
    var smoothing: Double = 0.25
    var sigmoidMidpoint: Double = 0.70
    var sigmoidSteepness: Double = 7.0
    var accelerationCap: Double = 30.0
    var negativeInertia: Double = 3.0
}

/// 完整配置（速度 + 键位），Codable 持久化
struct AppConfig: Codable, Equatable {
    var speed: SpeedConfig = SpeedConfig()
    var bindings: [KeyBinding] = []

    static var `default`: AppConfig {
        AppConfig(speed: SpeedConfig(), bindings: Self.defaultBindings)
    }

    /// 与 v0.2 硬编码行为一致的默认键位
    static let defaultBindings: [KeyBinding] = [
        KeyBinding(keyCode: 34, action: .move(.up)),          // I
        KeyBinding(keyCode: 38, action: .move(.left)),        // J
        KeyBinding(keyCode: 40, action: .move(.down)),        // K
        KeyBinding(keyCode: 37, action: .move(.right)),       // L
        KeyBinding(keyCode: 49, action: .drag),               // Space
        KeyBinding(keyCode: 44, action: .click(.leftDouble)), // /
        KeyBinding(keyCode: 45, action: .click(.rightClick)), // N
        KeyBinding(keyCode: 46, action: .click(.middleClick)), // M
        KeyBinding(keyCode: 31, action: .enter),              // O
        KeyBinding(keyCode: 4,  action: .warpCenter),         // H
        KeyBinding(keyCode: 13, action: .arrowKey(.up)),      // W
        KeyBinding(keyCode: 0,  action: .arrowKey(.left)),    // A
        KeyBinding(keyCode: 1,  action: .arrowKey(.down)),    // S
        KeyBinding(keyCode: 2,  action: .arrowKey(.right)),   // D
    ]
}

/// 供下拉框选择的内建动作（扁平列表，避免关联值枚举无法直接枚举）
enum BuiltinAction: String, CaseIterable, Identifiable {
    case moveUp, moveDown, moveLeft, moveRight
    case leftClick, leftDouble, rightClick, middleClick, drag
    case enter, warpCenter
    case arrowUp, arrowDown, arrowLeft, arrowRight
    case scrollUp, scrollDown, scrollLeft, scrollRight
    case unbound

    var id: String { rawValue }

    var label: String {
        switch self {
        case .moveUp: return "光标移动 ↑"
        case .moveDown: return "光标移动 ↓"
        case .moveLeft: return "光标移动 ←"
        case .moveRight: return "光标移动 →"
        case .leftClick: return "左键单击"
        case .leftDouble: return "左键双击"
        case .rightClick: return "右键单击"
        case .middleClick: return "中键单击"
        case .drag: return "按住拖拽"
        case .enter: return "回车"
        case .warpCenter: return "瞬移到屏幕中心"
        case .arrowUp: return "方向键 ↑"
        case .arrowDown: return "方向键 ↓"
        case .arrowLeft: return "方向键 ←"
        case .arrowRight: return "方向键 →"
        case .scrollUp: return "滚轮 上"
        case .scrollDown: return "滚轮 下"
        case .scrollLeft: return "滚轮 左"
        case .scrollRight: return "滚轮 右"
        case .unbound: return "未绑定（放行）"
        }
    }

    var keyAction: KeyAction {
        switch self {
        case .moveUp: return .move(.up)
        case .moveDown: return .move(.down)
        case .moveLeft: return .move(.left)
        case .moveRight: return .move(.right)
        case .leftClick: return .click(.leftClick)
        case .leftDouble: return .click(.leftDouble)
        case .rightClick: return .click(.rightClick)
        case .middleClick: return .click(.middleClick)
        case .drag: return .drag
        case .enter: return .enter
        case .warpCenter: return .warpCenter
        case .arrowUp: return .arrowKey(.up)
        case .arrowDown: return .arrowKey(.down)
        case .arrowLeft: return .arrowKey(.left)
        case .arrowRight: return .arrowKey(.right)
        case .scrollUp: return .scroll(.up)
        case .scrollDown: return .scroll(.down)
        case .scrollLeft: return .scroll(.left)
        case .scrollRight: return .scroll(.right)
        case .unbound: return .unbound
        }
    }

    /// 把一个 KeyAction 映射回内建动作（热键无法映射，返回 nil）
    init?(matching action: KeyAction) {
        switch action {
        case .move(let d):
            switch d {
            case .up: self = .moveUp
            case .down: self = .moveDown
            case .left: self = .moveLeft
            case .right: self = .moveRight
            }
        case .click(let t):
            switch t {
            case .leftClick: self = .leftClick
            case .leftDouble: self = .leftDouble
            case .rightClick: self = .rightClick
            case .middleClick: self = .middleClick
            }
        case .drag: self = .drag
        case .enter: self = .enter
        case .warpCenter: self = .warpCenter
        case .arrowKey(let d):
            switch d {
            case .up: self = .arrowUp
            case .down: self = .arrowDown
            case .left: self = .arrowLeft
            case .right: self = .arrowRight
            }
        case .scroll(let d):
            switch d {
            case .up: self = .scrollUp
            case .down: self = .scrollDown
            case .left: self = .scrollLeft
            case .right: self = .scrollRight
            }
        case .unbound: self = .unbound
        case .hotkey: return nil
        }
    }
}
