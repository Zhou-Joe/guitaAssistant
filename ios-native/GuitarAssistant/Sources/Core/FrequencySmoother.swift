import Foundation

/// 频率平滑器（中值滤波）。
///
/// 改进自 Flutter 版 `PitchService._medianFilter`：
/// - 平滑窗口由 3 提升至 7，读数更稳定、抖动更小。
/// - "换弦跳变"判定改为基于**对数（音分）**而非绝对频率比例，对高低弦更公平。
/// - 频率范围过滤同样基于音分（相对吉他音域边界）。
public final class FrequencySmoother {
    /// 平滑窗口大小（越大越稳定、越迟钝）。
    public let windowSize: Int
    /// 判定换弦的音分跳变阈值。
    public let stringChangeCents: Double
    /// 频率上下限（Hz）。
    public let minFrequency: Double
    public let maxFrequency: Double

    private var history: [Double] = []
    private var lastStable: Double = 0

    public init(windowSize: Int = 7,
                stringChangeCents: Double = 250,
                minFrequency: Double = AppConstants.guitarMinFrequency,
                maxFrequency: Double = AppConstants.guitarMaxFrequency) {
        self.windowSize = windowSize
        self.stringChangeCents = stringChangeCents
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
    }

    /// 重置历史（切换目标弦、开始/停止监听时调用）。
    public func reset() {
        history.removeAll()
        lastStable = 0
    }

    /// 输入一个新频率，返回平滑后的频率（可能为 nil 表示被拒绝）。
    public func process(_ frequency: Double) -> Double? {
        // 拒绝吉他音域外的频率。
        guard frequency.isFinite, frequency > 0,
              frequency >= minFrequency, frequency <= maxFrequency else {
            return lastStable > 0 ? lastStable : nil
        }

        // 检测换弦：相对上一个稳定频率的音分跳变超阈值则清空历史。
        if lastStable > 0 {
            let cents = abs(1200.0 * log2(frequency / lastStable))
            if cents > stringChangeCents {
                history.removeAll()
            }
        }

        history.append(frequency)
        if history.count > windowSize {
            history.removeFirst(history.count - windowSize)
        }

        let median = Self.median(history)
        lastStable = median
        return median
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted[mid]
    }
}
