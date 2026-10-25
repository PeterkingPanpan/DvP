import Foundation

/// 纯数学：给定方向按键状态和 deltaTime，返回光标应移动的像素数
/// 速度模型借鉴 ThinkPad TrackPoint 的三段设计：
///   Sigmoid 力-速曲线 + 负惯性助推 + 反向急停
struct CursorEngine {

    // MARK: - 可调参数（由 ConfigStore 每帧注入）

    var baseSpeed: Double = 35
    var shiftMultiplier: Double = 2.0
    var maxSpeed: Double = 3500
    var smoothing: Double = 0.25
    var sigmoidMidpoint: Double = 0.70
    var sigmoidSteepness: Double = 7.0
    var accelerationCap: Double = 30.0
    var negativeInertia: Double = 3.0

    // MARK: - 私有常量

    /// 负惯性导数上限，防止第一帧爆炸
    private let maxDerivative: Double = 50.0
    /// 松手后的摩擦衰减系数（每帧）
    private let friction: Double = 0.82

    // MARK: - 内部状态

    private var velocityX: Double = 0
    private var velocityY: Double = 0
    private var holdDurations: [Direction: TimeInterval] = [:]
    private var previousRampX: Double
    private var previousRampY: Double

    init() {
        // 修复首帧负惯性爆炸：初始 ramp 应是 t=0 处的值（≈1.0），而非 0
        let r = Self.sigmoidRamp(t: 0, midpoint: sigmoidMidpoint,
                                 steepness: sigmoidSteepness, cap: accelerationCap)
        previousRampX = r
        previousRampY = r
    }

    // MARK: - 每帧调用

    mutating func update(
        moveUp: Bool, moveDown: Bool, moveLeft: Bool, moveRight: Bool,
        speedKeyHeld: Bool,
        deltaTime: TimeInterval
    ) -> (dx: Double, dy: Double) {

        // 0. 急停（FPS 反键）：按反向的方向键立刻清零该轴速度
        if velocityX > 0, moveLeft { velocityX = 0 }
        if velocityX < 0, moveRight { velocityX = 0 }
        if velocityY > 0, moveUp { velocityY = 0 }
        if velocityY < 0, moveDown { velocityY = 0 }

        // 1. 更新每个方向的持有时长
        let held: [Direction: Bool] = [
            .up: moveUp, .down: moveDown, .left: moveLeft, .right: moveRight,
        ]
        for dir in Direction.allCases {
            if held[dir] == true {
                holdDurations[dir, default: 0] += deltaTime
            } else {
                holdDurations[dir] = 0
            }
        }

        // 2. 目标速度 — Sigmoid 力-速映射 + 负惯性
        var targetVX: Double = 0
        var targetVY: Double = 0
        let speed = speedKeyHeld ? baseSpeed * shiftMultiplier : baseSpeed

        let tX = max(holdDurations[.left, default: 0], holdDurations[.right, default: 0])
        let rampX = Self.sigmoidRamp(t: tX, midpoint: sigmoidMidpoint,
                                     steepness: sigmoidSteepness, cap: accelerationCap)
        if moveLeft { targetVX -= speed * rampX }
        if moveRight { targetVX += speed * rampX }

        let tY = max(holdDurations[.up, default: 0], holdDurations[.down, default: 0])
        let rampY = Self.sigmoidRamp(t: tY, midpoint: sigmoidMidpoint,
                                     steepness: sigmoidSteepness, cap: accelerationCap)
        if moveUp { targetVY -= speed * rampY }
        if moveDown { targetVY += speed * rampY }

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
        previousRampX = Self.sigmoidRamp(t: 0, midpoint: sigmoidMidpoint,
                                         steepness: sigmoidSteepness, cap: accelerationCap)
        previousRampY = previousRampX
    }

    /// 撞到屏幕边缘时调用——立即杀掉该方向的残留速度
    mutating func killVelocity(x: Bool, y: Bool) {
        if x { velocityX = 0 }
        if y { velocityY = 0 }
    }

    // MARK: - Sigmoid

    /// Sigmoid ramp：t=0 → ≈1x，t→∞ → cap
    static func sigmoidRamp(t: TimeInterval, midpoint: Double, steepness: Double, cap: Double) -> Double {
        let x = steepness * (t - midpoint)
        let s = 1.0 / (1.0 + exp(-x))  // 0…1
        return 1.0 + (cap - 1.0) * s
    }

    // MARK: - Helpers

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }
}
