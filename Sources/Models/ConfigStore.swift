import Foundation
import Combine

/// 配置的唯一持有者：可观察、持久化到 Application Support
final class ConfigStore: ObservableObject {

    static let shared = ConfigStore()

    @Published var speed: SpeedConfig {
        didSet { persist() }
    }

    @Published var bindings: [KeyBinding] {
        didSet { persist(); rebuild() }
    }

    /// 键码 → 动作（供 InputManager 每帧 O(1) 查询）
    private(set) var keyMap: [Int64: KeyAction] = [:]

    /// 持久化防抖任务（拖动滑块时不落盘，停顿后才写）
    private var persistWorkItem: DispatchWorkItem?

    private init() {
        let cfg = Self.load()
        speed = cfg.speed
        bindings = cfg.bindings
        rebuild()
    }

    // MARK: - 查询 / 修改

    func action(for keyCode: Int64) -> KeyAction? {
        keyMap[keyCode]
    }

    func setAction(_ action: KeyAction, for keyCode: Int64) {
        // 未绑定 = 从映射表中移除，nil 即未绑定（UI 据此渲染中性键帽）
        if action == .unbound {
            bindings.removeAll { $0.keyCode == keyCode }
            return
        }
        if let i = bindings.firstIndex(where: { $0.keyCode == keyCode }) {
            bindings[i].action = action
        } else {
            bindings.append(KeyBinding(keyCode: keyCode, action: action))
        }
    }

    func clearAction(for keyCode: Int64) {
        setAction(.unbound, for: keyCode)
    }

    func resetAll() {
        bindings = AppConfig.defaultBindings
        speed = SpeedConfig()
    }

    // MARK: - 私有

    private func rebuild() {
        keyMap = Dictionary(bindings.map { ($0.keyCode, $0.action) },
                            uniquingKeysWith: { _, new in new })
    }

    private static var configURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DvP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    /// 防抖写盘：高频变更（如拖动滑块）只在下一次停顿后落盘，避免卡顿
    private func persist() {
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeToDisk()
        }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func writeToDisk() {
        let cfg = AppConfig(speed: speed, bindings: bindings)
        do {
            let data = try JSONEncoder().encode(cfg)
            try data.write(to: Self.configURL, options: .atomic)
        } catch {
            // 持久化失败不致命（首次运行、目录权限等）
        }
    }

    /// 立即写盘（退出前调用，防抖窗口内的改动不丢）
    func flush() {
        persistWorkItem?.cancel()
        persistWorkItem = nil
        writeToDisk()
    }

    private static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
              let cfg = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return .default }
        return cfg
    }
}
