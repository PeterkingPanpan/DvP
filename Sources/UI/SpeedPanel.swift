import SwiftUI
import AppKit

/// 速度条：一个主速度滑块 + 可展开的「加速手感」参数
struct SpeedBar: View {
    @ObservedObject private var store = ConfigStore.shared
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text("速度")
                    .frame(width: 36, alignment: .leading)
                Slider(value: $store.speed.baseSpeed, in: 5...200, step: 1)
                    .help("光标移动的基础速度（像素/秒）")
                Text("\(Int(store.speed.baseSpeed))")
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }

            // 整行可点（不只是小三角）
            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                    Text("高级")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAdvanced {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("按住方向键越久，光标越快——轻触精确、长按飞掠。下面调它的手感。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        param("最快速度", "光标能达到的最快速度（像素/秒）",
                              $store.speed.maxSpeed, 500...8000, 50)
                        param("加速键倍数", "按住 ; 时，速度在此基础上翻几倍",
                              $store.speed.shiftMultiplier, 1...5, 0.1)
                        param("何时开始加速", "按住方向键多久后开始变快（秒），越小越早加速",
                              $store.speed.sigmoidMidpoint, 0.1...2, 0.05)
                        param("加速有多猛", "加速来得有多突然，越大越突兀",
                              $store.speed.sigmoidSteepness, 1...20, 0.5)
                        param("加速倍率上限", "长时间按住能达到的最快倍速",
                              $store.speed.accelerationCap, 2...60, 1)
                        param("跟手程度", "越小光标越跟手，越大越顺滑（有缓冲感）",
                              $store.speed.smoothing, 0.05...1, 0.05)
                        param("轻推助推感", "轻敲一下的瞬间冲刺感，0 表示关闭",
                              $store.speed.negativeInertia, 0...10, 0.5)

                        CurvePreview(speed: store.speed)
                            .frame(height: 90)
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(12)
    }

    private func param(_ name: String, _ tip: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(fmt(value.wrappedValue, step: step))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .help(tip)
    }

    private func fmt(_ v: Double, step: Double) -> String {
        let d = step < 0.05 ? 2 : (step < 0.5 ? 1 : 0)
        return String(format: "%.\(d)f", v)
    }
}

/// 加速曲线实时预览
struct CurvePreview: View {
    let speed: SpeedConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("加速曲线（横 = 按住时长，纵 = 速度）")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Canvas { context, size in
                var path = Path()
                let tMax = 2.5
                let steps = 200
                for i in 0...steps {
                    let t = tMax * Double(i) / Double(steps)
                    let ramp = CursorEngine.sigmoidRamp(
                        t: t,
                        midpoint: speed.sigmoidMidpoint,
                        steepness: speed.sigmoidSteepness,
                        cap: speed.accelerationCap
                    )
                    let x = CGFloat(t / tMax) * size.width
                    let norm = (ramp - 1.0) / max(speed.accelerationCap - 1.0, 1)
                    let y = size.height - CGFloat(norm) * size.height * 0.9 - size.height * 0.05
                    let point = CGPoint(x: x, y: y)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(.accentColor), lineWidth: 2)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
