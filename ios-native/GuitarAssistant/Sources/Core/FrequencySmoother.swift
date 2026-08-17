import Foundation

/// 频率平滑器(中值滤波 + 跳变确认)。
///
/// 改进自 Flutter 版 `PitchService._medianFilter`:
/// - 平滑窗口 7,读数稳定。
/// - "换弦跳变"基于**对数(音分)**判定,对高低弦公平。
/// - 大跳变不再当帧生效,而是进入**候选确认**:新频率需连续 `jumpConfirmFrames` 帧
///   稳定出现才真正切换。这同时过滤掉 YIN 偶发的八度错误(f↔2f,1200 音分)——
///   它们通常只持续 1-3 帧;而真实换弦会持续存在,约 0.4s 后正常切换。
public final class FrequencySmoother {
    /// 平滑窗口大小(越大越稳定、越迟钝)。
    public let windowSize: Int
    /// 判定换弦的音分跳变阈值。
    public let stringChangeCents: Double
    /// 大跳变确认所需连续帧数(~10.7 帧/秒,4 帧 ≈ 0.37s)。
    public let jumpConfirmFrames: Int
    /// 候选跳变的"同目标"容差(音分):帧间抖动小于此值计入同一候选。
    public let jumpToleranceCents: Double
    /// 频率上下限(Hz)。
    public let minFrequency: Double
    public let maxFrequency: Double

    private var history: [Double] = []
    private var lastStable: Double = 0
    /// 跳变候选目标与连续命中计数。
    private var candidate: Double = 0
    private var candidateCount: Int = 0

    public init(windowSize: Int = 7,
                stringChangeCents: Double = 250,
                jumpConfirmFrames: Int = 4,
                jumpToleranceCents: Double = 80,
                minFrequency: Double = AppConstants.guitarMinFrequency,
                maxFrequency: Double = AppConstants.guitarMaxFrequency) {
        self.windowSize = windowSize
        self.stringChangeCents = stringChangeCents
        self.jumpConfirmFrames = jumpConfirmFrames
        self.jumpToleranceCents = jumpToleranceCents
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
    }

    /// 重置历史(切换目标弦、开始/停止监听时调用)。
    public func reset() {
        history.removeAll()
        lastStable = 0
        candidate = 0
        candidateCount = 0
    }

    /// 输入一个新频率,返回平滑后的频率(nil 表示无稳定值可用)。
    ///
    /// - 音域外频率:拒绝,返回当前稳定值(保持显示)。
    /// - 相对稳定值跳变 ≤ `stringChangeCents`:正常进入中值窗口。
    /// - 跳变 > `stringChangeCents`:进候选确认——不污染中值窗口、输出保持旧值,
    ///   连续 `jumpConfirmFrames` 帧命中同一候选后切换。
    public func process(_ frequency: Double) -> Double? {
        // 拒绝吉他音域外的频率。
        guard frequency.isFinite, frequency > 0,
              frequency >= minFrequency, frequency <= maxFrequency else {
            return lastStable > 0 ? lastStable : nil
        }

        // 大跳变:候选确认。
        if lastStable > 0 {
            let cents = abs(1200.0 * log2(frequency / lastStable))
            if cents > stringChangeCents {
                if candidate > 0,
                   abs(1200.0 * log2(frequency / candidate)) <= jumpToleranceCents {
                    candidateCount += 1
                } else {
                    candidate = frequency
                    candidateCount = 1
                }
                if candidateCount >= jumpConfirmFrames {
                    // 确认切换:以新频率重建历史。
                    history = [frequency]
                    lastStable = frequency
                    candidate = 0
                    candidateCount = 0
                    return frequency
                }
                // 未确认期间输出旧稳定值(不把跳变帧混入中值窗口)。
                return currentMedian() ?? lastStable
            }
        }

        // 正常路径(小抖动或无历史):中值滤波。
        candidate = 0
        candidateCount = 0
        history.append(frequency)
        if history.count > windowSize {
            history.removeFirst(history.count - windowSize)
        }
        lastStable = Self.median(history)
        return lastStable
    }

    private func currentMedian() -> Double? {
        guard !history.isEmpty else { return nil }
        return Self.median(history)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted[mid]
    }
}

/// 滞回选择器:给"每帧独立重算的离散选择"(音名、最近弦)加粘性。
///
/// 规则:
/// - `hold == true`(当前稳定值仍在保持带内)→ 强制保持,清空候选。
/// - 新值与稳定值不同 → 计入候选;连续 `confirmFrames` 帧一致才切换。
/// - 无稳定值时直接透传(首次出值)。
public struct StickySelector {
    public let confirmFrames: Int
    /// 当前稳定选择(-1 = 无)。
    public private(set) var stable: Int = -1
    private var pending: Int = -1
    private var pendingCount = 0

    public init(confirmFrames: Int = 3) {
        self.confirmFrames = confirmFrames
    }

    public mutating func reset() {
        stable = -1
        pending = -1
        pendingCount = 0
    }

    /// 输入本帧原始选择与"保持带"标志,返回应显示的选择。
    public mutating func update(_ raw: Int, hold: Bool) -> Int {
        if stable >= 0, hold {
            pending = -1
            pendingCount = 0
            return stable
        }
        if stable < 0 {
            // 首次:立即透传并开始观察(连续 confirmFrames 帧一致才定为稳定)。
            observe(raw)
            return raw
        }
        if raw == stable {
            pending = -1
            pendingCount = 0
            return stable
        }
        observe(raw)
        return stable
    }

    private mutating func observe(_ raw: Int) {
        if raw == pending {
            pendingCount += 1
        } else {
            pending = raw
            pendingCount = 1
        }
        if pendingCount >= confirmFrames {
            stable = raw
            pending = -1
            pendingCount = 0
        }
    }
}
