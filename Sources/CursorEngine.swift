import Foundation

/// 纯数学：给定按住的键和 deltaTime，返回光标应该移动的像素数
struct CursorEngine {

    // MARK: - 可调参数

    var baseSpeed: Double = 200       // 像素/秒（原来 400）
    var shiftMultiplier: Double = 2.5 // 按住加速键时速度倍率（原来 3.0）
    var maxSpeed: Double = 1600       // 速度上限 像素/秒（原来 3000）
    var smoothing: Double = 0.30      // lerp 因子（0=无惯性, 1=不移动）
    var accelerationRamp: Double = 1.8 // 按住越久越快（原来 2.5）

    // MARK: - 内部状态

    private var velocityX: Double = 0
    private var velocityY: Double = 0
    private var holdDurations: [Int64: TimeInterval] = [:]

    // MARK: - 每帧调用

    mutating func update(
        heldKeys: Set<Int64>,
        speedKeyHeld: Bool,
        deltaTime: TimeInterval
    ) -> (dx: Double, dy: Double) {

        // 1. 更新每个键的持有时长
        let cursorKeys: [Int64] = [34, 38, 40, 37] // I, J, K, L
        for key in cursorKeys {
            if heldKeys.contains(key) {
                holdDurations[key, default: 0] += deltaTime
            } else {
                holdDurations[key] = 0
            }
        }

        // 2. 计算目标速度
        var targetVX: Double = 0
        var targetVY: Double = 0
        let speed = speedKeyHeld ? baseSpeed * shiftMultiplier : baseSpeed

        for key in heldKeys {
            let ramp = min(1.0 + holdDurations[key, default: 0] * accelerationRamp, 3.0)
            switch key {
            case 34: targetVY -= speed * ramp // I = 上
            case 38: targetVX -= speed * ramp // J = 左
            case 40: targetVY += speed * ramp // K = 下
            case 37: targetVX += speed * ramp // L = 右
            default: break
            }
        }

        // 3. 无按键时摩擦减速
        if targetVX == 0 { velocityX *= 0.82 }
        if targetVY == 0 { velocityY *= 0.82 }

        // 4. 平滑过渡到目标速度
        velocityX = lerp(velocityX, targetVX, smoothing)
        velocityY = lerp(velocityY, targetVY, smoothing)

        // 5. 限幅
        velocityX = clamp(velocityX, -maxSpeed, maxSpeed)
        velocityY = clamp(velocityY, -maxSpeed, maxSpeed)

        // 6. 位移 = 速度 × 时间
        return (velocityX * deltaTime, velocityY * deltaTime)
    }

    /// 松手时全部停止（模式切换时调用）
    mutating func reset() {
        velocityX = 0
        velocityY = 0
        holdDurations.removeAll()
    }

    // MARK: - Helpers

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }
}
