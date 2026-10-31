// =========================================================================
// 📄 File: ui/core/SlowPullGesturePolicy.js
// 🌟 动态意图手势策略引擎 (开放调参面板版)
// =========================================================================
.pragma library

// =========================================================================
// ⚙️ 灵动岛物理手感调参面板 (Tuning Board)
// =========================================================================

// 1. 深度与死区
var TRIGGER_DISTANCE = 15.0;      // 🎯 触发需要的下拉物理深度 (默认16px，调小更易触发，调大更需用力)
var DEAD_ZONE = 5.0;              // 🛡️ 静默死区 (默认5px，前 5px 绝对不发生任何形变，调大更防误触形变)

// 2. 速度门限 (单位: 像素/毫秒)
var SPEED_LIMIT_SWIPE = 0.13;     // ❌ 横向飞掠限速 (默认0.65) -> 越小越严苛，鼠标稍快路过就被彻底封杀；调大则允许快速路过时产生形变。
var SPEED_LIMIT_PULL  = 80.0;      // ✅ 垂直下拉限速 (默认5.0)  -> 5.0 相当于 5000px/s，几乎等于“下拉不限速”，怎么快拉都响应。

// 3. 角度容差
var ANGLE_STRICTNESS  = 8.0;      // 📐 意图夹角门限 (默认1.5) -> 下划的垂直位移必须是横向漂移的 1.5 倍（约56度倾角）。
                                  // 如果你发现自己下拉总是歪歪扭扭被拒绝，可以改小到 1.0 (45度)；想要极度严苛防误触，改大到 2.0。

// =========================================================================

function createTracker() {
    return {
        isTracking: false,
        anchorX: 0.0,
        anchorY: 0.0,
        anchorTime: 0.0,
        pullDistance: 0.0,
        hasFired: false,
        isDisqualifiedFast: false
    };
}

function onEnter(tracker) {
    tracker.isTracking = false;
    tracker.hasFired = false;
    tracker.isDisqualifiedFast = false;
    tracker.pullDistance = 0.0;
    tracker.anchorTime = 0.0;
}

function onExit(tracker) {
    tracker.isTracking = false;
    tracker.hasFired = false;
    tracker.isDisqualifiedFast = false;
    tracker.pullDistance = 0.0;
}

// 连续平滑流体力学张力函数
function calculateSmoothPull(effectiveY) {
    if (effectiveY <= 0) return 0.0;
    var maxStretch = 22.0;
    return (effectiveY * maxStretch) / (effectiveY + 18.0);
}

function processMove(tracker, mouseX, mouseY, nowTimestamp, Logger) {
    if (tracker.hasFired || tracker.isDisqualifiedFast) {
        return { state: "IDLE", visualY: 0.0 };
    }

    if (tracker.anchorTime === 0 || !tracker.isTracking) {
        tracker.anchorX = mouseX;
        tracker.anchorY = mouseY;
        tracker.anchorTime = nowTimestamp;
        tracker.isTracking = true;
        return { state: "IDLE", visualY: 0.0 };
    }

    var totalDt = Math.max(1, nowTimestamp - tracker.anchorTime);
    var deltaX = Math.abs(mouseX - tracker.anchorX);
    var deltaY = mouseY - tracker.anchorY;

    // 1. 向上反推 或 纯横向平移，直接取消手势
    if (deltaY < -2 || (deltaX > 15 && deltaY < deltaX * 0.6)) {
        return { state: "ABORT", visualY: 0.0 };
    }

    // 2. 暗中测速，提前狙杀
    var totalDistance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
    var avgSpeed = totalDistance / totalDt; // px/ms

    // 判定是否为垂直下划意图
    var isSteepVertical = (deltaY > deltaX * ANGLE_STRICTNESS);
    
    // 应用调参面板的限速规则
    var currentSpeedLimit = isSteepVertical ? SPEED_LIMIT_PULL : SPEED_LIMIT_SWIPE;

    // 熔断判定距离 (2.5px) < 视觉形变死区 (DEAD_ZONE)，确保在视觉变形前物理熔断
    if (totalDistance > 2.5 && avgSpeed > currentSpeedLimit) {
        if (Logger) {
            Logger.jitter("FAST_REJECT", "暗中测速拦截飞掠", avgSpeed.toFixed(3), currentSpeedLimit);
        }
        tracker.isDisqualifiedFast = true;
        tracker.isTracking = false;
        tracker.pullDistance = 0.0;
        return { state: "ABORT", visualY: 0.0 };
    }

    // 3. 突破静默死区后，执行流体拉伸
    if (deltaY > DEAD_ZONE) {
        var effectiveY = deltaY - DEAD_ZONE;
        var visualPull = calculateSmoothPull(effectiveY);
        
        tracker.pullDistance = visualPull;

        if (visualPull >= TRIGGER_DISTANCE) {
            tracker.hasFired = true;
            tracker.isTracking = false;
            return { state: "TRIGGER", visualY: visualPull };
        }

        return { state: "PULL", visualY: visualPull };
    }

    return { state: "IDLE", visualY: 0.0 };
}