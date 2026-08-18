import Foundation

/// mini-pYIN 式音高跟踪器。
///
/// 每帧接收若干音高候选(YIN CMND 的多个谷 + 可信度),维护一组"音高轨迹假设",
/// 按转移代价(音分距离)与候选证据打分,取最优假设输出。
///
/// 相比手工的"中值 + 跳变确认 + 滞回"三件套,它把防八度闪跳、瞬态剔除、
/// 新音快速接管统一在一个评分模型里:
/// - 平滑跟随(小音分变化)零代价 → 读数跟手;
/// - 单帧八度毛刺对在位假设几乎无影响(跳去又跳回代价高);
/// - 持续强证据的新音(换弦)2-3 帧即可接管;
/// - 瞬态乱值可信度低 + 距离远 → 天然被剔除。
public final class PitchTracker {

    public struct Output: Equatable {
        /// 跟踪到的频率(nil = 无声/未锁定)。
        public let frequency: Double?
        /// 0-1 置信度。
        public let confidence: Double
        public init(frequency: Double?, confidence: Double) {
            self.frequency = frequency
            self.confidence = confidence
        }
    }

    private struct Hypothesis {
        var frequency: Double
        var score: Double
    }

    // MARK: - 参数

    /// 平滑跟随的免代价带宽(音分)。
    private let freeBandCents: Double = 40
    /// 八度(±1200 音分附近)的转移代价。
    private let octaveCost: Double = 2.2
    /// 超过此代价的距离视为"不匹配":假设原地保持并付失配惩罚。
    private let matchCeiling: Double = 3.0
    /// 无匹配候选时的失配惩罚(假设原地存活但降权)。
    private let missPenalty: Double = 0.8
    /// 新轨迹的诞生门槛(可信度需超过此值)。
    private let birthThreshold: Double = 0.45
    /// 假设分数衰减(资本按帧折旧,新证据持续注入)。
    private let decay: Double = 0.72
    /// 输出所需的最小资本。
    private let outputFloor: Double = 0.5
    /// 最大并行假设数。
    private let maxHypotheses = 6
    /// 无候选时保持输出的帧数。
    private let holdFrames = 8

    private var hypotheses: [Hypothesis] = []
    private var heldFrequency: Double?
    private var heldCount = 0

    public init() {}

    public func reset() {
        hypotheses.removeAll()
        heldFrequency = nil
        heldCount = 0
    }

    // MARK: - 更新

    public func update(candidates: [PitchCandidate]) -> Output {
        if candidates.isEmpty {
            for i in hypotheses.indices { hypotheses[i].score *= 0.6 }
            hypotheses.removeAll { $0.score < 0.05 }
            heldCount += 1
            if heldCount > holdFrames { heldFrequency = nil }
            let conf = hypotheses.first.map { min(1, $0.score / 2.5) } ?? 0
            return Output(frequency: heldFrequency, confidence: conf)
        }
        heldCount = 0

        var next: [Hypothesis] = []

        // 1) 在位假设:
        //    - 代价可接受的最近候选 → 转移过去(资本 = 折旧 + 证据 - 代价);
        //    - 代价过高(远距/八度单帧) → 原地保持(资本 = 折旧 - 失配惩罚),
        //      与转移变体同台竞争——单帧毛刺拼不过在位资本,持续新证据会接管。
        for h in hypotheses {
            var best: (idx: Int, cost: Double)?
            for (i, c) in candidates.enumerated() {
                let cost = jumpCost(from: h.frequency, to: c.frequency)
                if cost < matchCeiling, best == nil || cost < best!.cost {
                    best = (i, cost)
                }
            }
            if let m = best {
                next.append(Hypothesis(
                    frequency: candidates[m.idx].frequency,
                    score: h.score * decay + candidates[m.idx].probability - m.cost))
            }
            next.append(Hypothesis(frequency: h.frequency,
                                   score: h.score * decay - missPenalty))
        }

        // 2) 诞生新假设:强候选另起轨迹(换弦快速接管)。
        for c in candidates where c.probability > birthThreshold {
            next.append(Hypothesis(frequency: c.frequency,
                                   score: max(0.15, c.probability - 0.3)))
        }

        // 3) 剪枝:按分数保留头部,相近假设合并(留高分)。
        next.sort { $0.score > $1.score }
        var pruned: [Hypothesis] = []
        for h in next {
            if pruned.allSatisfy({ abs(centsBetween($0.frequency, h.frequency)) > 60 }) {
                pruned.append(h)
            }
            if pruned.count >= maxHypotheses { break }
        }
        hypotheses = pruned

        // 4) 输出最优假设。
        guard let best = pruned.first, best.score > outputFloor else {
            return Output(frequency: heldFrequency,
                          confidence: min(1, max(0, (pruned.first?.score ?? 0) / 2.5)))
        }
        heldFrequency = best.frequency
        return Output(frequency: best.frequency,
                      confidence: min(1, best.score / 2.5))
    }

    // MARK: - 转移代价

    /// 音分距离 → 转移代价:
    /// ≤ freeBand 免费(平滑跟随);八度(±1200±80)中等(偶发 octave 毛刺
    /// 不值得跳);其余随距离单调上升,封顶 maxJumpCost。
    private func jumpCost(from a: Double, to: Double) -> Double {
        let cents = abs(centsBetween(a, to))
        if cents <= freeBandCents { return 0 }
        // 八度邻域:允许但需付代价。
        let octaveDist = abs(cents - 1200)
        if octaveDist <= 80 { return octaveCost }
        let normalized = (cents - freeBandCents) / 1200
        return min(matchCeiling - 0.01, normalized * 4)
    }

    private func centsBetween(_ a: Double, _ b: Double) -> Double {
        1200.0 * log2(a / b)
    }
}
