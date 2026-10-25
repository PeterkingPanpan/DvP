import SwiftUI
import AppKit

/// 配置主窗口：大键盘 + 下方速度条 + 右侧键位编辑
struct ConfigWindow: View {
    @ObservedObject private var store = ConfigStore.shared
    @State private var selectedKey: Int64?
    @State private var isTrusted = PermissionManager.isTrusted

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 左侧：大键盘 + 速度条
                VStack(spacing: 0) {
                    KeyboardView(selectedKey: $selectedKey)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    SpeedBar()
                }

                // 右侧：键位编辑（选中键时显示）
                Divider()
                KeyEditorPanel(selectedKey: $selectedKey)
                    .frame(width: 260)
            }
            Divider()
            footer
        }
        .frame(minWidth: 1100, minHeight: 680)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            isTrusted = PermissionManager.isTrusted
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !isTrusted {
                Label("未授权辅助功能权限", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("去授权") { PermissionManager.requestPermission() }
                    .font(.caption)
            }
            Spacer()
            Button("恢复默认") { store.resetAll() }
                .font(.caption)
        }
        .padding(8)
    }
}

/// 右侧面板：选中键的编辑器
struct KeyEditorPanel: View {
    @ObservedObject private var store = ConfigStore.shared
    @Binding var selectedKey: Int64?

    var body: some View {
        VStack(spacing: 0) {
            if let key = selectedKey {
                keyEditor(key: key)
            } else {
                emptyHint
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text("点击键盘上的键\n设置它的动作")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func keyEditor(key: Int64) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(KeyLayout.label(for: key))
                .font(.largeTitle.bold())

            Text("当前：\(store.action(for: key)?.label ?? "未绑定")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { BuiltinAction(matching: store.action(for: key) ?? .unbound) ?? .unbound },
                set: { store.setAction($0.keyAction, for: key) }
            )) {
                ForEach(BuiltinAction.allCases) { b in
                    Text(b.label).tag(b)
                }
            }
            .labelsHidden()

            Divider()

            Text("或录制一个快捷键")
                .font(.caption)
                .foregroundStyle(.secondary)
            HotkeyRecorder { keyCode, flags in
                store.setAction(.hotkey(keyCode: keyCode, flags: flags), for: key)
            }

            Button("清除绑定") {
                store.clearAction(for: key)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
