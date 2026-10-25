import SwiftUI
import AppKit

/// 可视化键盘：完整 QWERTY 布局，可点击选键，实时高亮按下的键
struct KeyboardView: View {
    @ObservedObject private var store = ConfigStore.shared
    @ObservedObject private var input = InputManager.shared
    @Binding var selectedKey: Int64?

    var body: some View {
        VStack(spacing: KeyLayout.spacing) {
            ForEach(KeyLayout.rows.indices, id: \.self) { rowIndex in
                HStack(spacing: KeyLayout.spacing) {
                    ForEach(Array(KeyLayout.rows[rowIndex].enumerated()), id: \.offset) { _, cap in
                        let reserved = KeyLayout.reservedKeyCodes.contains(cap.keyCode)
                        KeyCapView(
                            cap: cap,
                            action: store.action(for: cap.keyCode),
                            isReserved: reserved,
                            isSelected: selectedKey == cap.keyCode,
                            isPressed: input.heldKeys.contains(cap.keyCode)
                        )
                        .onTapGesture {
                            guard !reserved else { return }
                            selectedKey = (selectedKey == cap.keyCode) ? nil : cap.keyCode
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

private struct KeyCapView: View {
    let cap: KeyCap
    let action: KeyAction?
    let isReserved: Bool
    let isSelected: Bool
    let isPressed: Bool

    var body: some View {
        Text(cap.label)
            .font(.system(size: cap.label.count > 1 ? 9 : 13, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: KeyLayout.unit * cap.width, height: KeyLayout.keyHeight)
            .background(fill)
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(border, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            .help(tooltip)
    }

    /// 单一强调色，用透明度区分状态：绑定 < 选中 < 按下
    private var fill: Color {
        if isPressed { return .accentColor.opacity(0.6) }
        if isReserved { return Color.gray.opacity(0.3) }
        if isSelected { return .accentColor.opacity(0.38) }
        if isBound { return .accentColor.opacity(0.22) }
        return Color(nsColor: .controlColor)
    }

    private var border: Color {
        isSelected ? .accentColor : Color.gray.opacity(0.4)
    }

    private var isBound: Bool {
        guard let action else { return false }
        return action != .unbound
    }

    private var tooltip: String {
        if isReserved { return "\(cap.label) — 系统键（模式切换 / 加速）" }
        return "\(cap.label)：\(action?.label ?? "未绑定")"
    }
}
