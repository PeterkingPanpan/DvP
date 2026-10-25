import SwiftUI
import AppKit

/// 录制单个组合键（含修饰键），回调返回 keyCode + flags
struct HotkeyRecorder: View {
    var onRecord: (Int64, UInt64) -> Void

    @State private var recording = false
    @State private var recorded: (keyCode: Int64, flags: UInt64)?
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text(recorded.map { KeyLayout.hotkeyString(keyCode: $0.keyCode, flags: $0.flags) } ?? "未录制")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(recorded == nil ? .secondary : .primary)
                .frame(minWidth: 80, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button(recording ? "请按键…(Esc 取消)" : "录制快捷键") {
                recording ? cancel() : begin()
            }
        }
        .onDisappear { stop() }
    }

    private func begin() {
        recorded = nil
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = Int64(event.keyCode)
            let mods = event.modifierFlags.intersection([.shift, .control, .option, .command])
            // Esc 单独按下 = 取消
            if keyCode == 53 && mods.isEmpty {
                cancel()
                return nil
            }
            let flags = UInt64(mods.rawValue)
            recorded = (keyCode, flags)
            stop()
            onRecord(keyCode, flags)
            return nil
        }
    }

    private func cancel() {
        stop()
    }

    private func stop() {
        recording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
