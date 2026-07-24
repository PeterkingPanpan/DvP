import Foundation

/// 纯数学：给定按住的键和 deltaTime，返回光标应该移动的像素数
/// 速度模型借鉴 ThinkPad TrackPoint 的三段设计：
///   Sigmoid 力-速曲线 + 负惯性助推 + 反向急停
struct CursorEngine {

    // MARK: - 方向键 key code

    private enum Key {
        static let i: Int64 = 34  // 上
        static let j: Int64 = 38  // 左
        static let k: Int64 = 40  // 下
        static let l: Int64 = 37  // 右
        static let all: [Int64] = [34, 38, 40, 37]
    }

    // MARK: - 可调参数

    /// 轻触起步速度（像素/秒）
    var baseSpeed: Double = 35
    /// 按住 ; 加速键时的速度倍率
    var shiftMultiplier: Double = 2.0
    /// 速度上限（像素/秒）
    var maxSpeed: Double = 3500
    /// 速度平滑 lerp 因子（0 = 零惯性, 1 = 不移动）
    var smoothing: Double = 0.25

    /// Sigmoid 拐点（秒）— 小于此值为精度区，大于此值进入高速区
    var sigmoidMidpoint: Double = 0.70
    /// Sigmoid 陡度 — 越高过渡越突兀
    var sigmoidSteepness: Double = 7.0
    /// 加速倍率上限 — 长时间按住后的 ramp 倍数
    var accelerationCap: Double = 30.0

    /// 负惯性因子 — 力度变化（导数）的放大系数。TrackPoint 默认 6，0 = 关闭
    var negativeInertia: Double = 3.0

    // MARK: - 私有常量

    /// 负惯性导数上限，防止第一帧爆炸
    private let maxDerivative: Double = 50.0
    /// 松手后的摩擦衰减系数（每帧）
    private let friction: Double = 0.82

    // MARK: - 内部状态

    private var velocityX: Double = 0
    private var velocityY: Double = 0
    private var holdDurations: [Int64: TimeInterval] = [:]
    private var previousRampX: Double = 0
    private var previousRampY: Double = 0

    // MARK: - 每帧调用

    mutating func update(
        heldKeys: Set<Int64>,
        speedKeyHeld: Bool,
        deltaTime: TimeInterval
    ) -> (dx: Double, dy: Double) {

        // 0. 急停（FPS 反键）：按反向的方向键立刻清零该轴速度
        if velocityX > 0, heldKeys.contains(Key.j) { velocityX = 0 }
        if velocityX < 0, heldKeys.contains(Key.l) { velocityX = 0 }
        if velocityY > 0, heldKeys.contains(Key.i) { velocityY = 0 }
        if velocityY < 0, heldKeys.contains(Key.k) { velocityY = 0 }

        // 1. 更新每个方向键的持有时长
        for key in Key.all {
            if heldKeys.contains(key) {
                holdDurations[key, default: 0] += deltaTime
            } else {
                holdDurations[key] = 0
            }
        }

        // 2. 计算目标速度 — Sigmoid 力-速映射 + 负惯性
        var targetVX: Double = 0
        var targetVY: Double = 0
        let speed = speedKeyHeld ? baseSpeed * shiftMultiplier : baseSpeed

        // X 轴：J(左) / L(右)
        let tX = max(
            holdDurations[Key.j, default: 0],
            holdDurations[Key.l, default: 0]
        )
        let rampX = sigmoidRamp(t: tX)
        if heldKeys.contains(Key.j) { targetVX -= speed * rampX }
        if heldKeys.contains(Key.l) { targetVX += speed * rampX }

        // Y 轴：I(上) / K(下)
        let tY = max(
            holdDurations[Key.i, default: 0],
            holdDurations[Key.k, default: 0]
        )
        let rampY = sigmoidRamp(t: tY)
        if heldKeys.contains(Key.i) { targetVY -= speed * rampY }
        if heldKeys.contains(Key.k) { targetVY += speed * rampY }

        // 负惯性：力度变化越快，助推越大。助推方向与目标速度同向。
        let dRampX = (rampX - previousRampX) / deltaTime
        let dRampY = (rampY - previousRampY) / deltaTime
        if targetVX != 0 {
            let boost = speed * min(dRampX, maxDerivative) * negativeInertia
            targetVX += targetVX > 0 ? boost : -boost
        }
        if targetVY != 0 {
            let boost = speed * min(dRampY, maxDerivative) * negativeInertia
            targetVY += targetVY > 0 ? boost : -boost
        }
        previousRampX = rampX
        previousRampY = rampY

        // 3. 无按键时摩擦减速
        if targetVX == 0 { velocityX *= friction }
        if targetVY == 0 { velocityY *= friction }

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
        previousRampX = 0
        previousRampY = 0
    }

    /// 撞到屏幕边缘时调用——立即杀掉该方向的残留速度
    mutating func killVelocity(x: Bool, y: Bool) {
        if x { velocityX = 0 }
        if y { velocityY = 0 }
    }

    // MARK: - Helpers

    /// Sigmoid：t=0 → ≈1x，t→∞ → accelerationCap
    private func sigmoidRamp(t: TimeInterval) -> Double {
        let x = sigmoidSteepness * (t - sigmoidMidpoint)
        let s = 1.0 / (1.0 + exp(-x))  // 0…1
        return 1.0 + (accelerationCap - 1.0) * s
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }
}
