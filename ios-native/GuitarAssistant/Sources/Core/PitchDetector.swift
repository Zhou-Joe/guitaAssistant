import Foundation
import Accelerate

/// 单帧的音高候选(来自 YIN CMND 的多个谷)。
public struct PitchCandidate: Equatable {
    public let frequency: Double
    /// 0-1 可信度(谷越深越接近 1)。
    public let probability: Double
    public init(frequency: Double, probability: Double) {
        self.frequency = frequency
        self.probability = probability
    }
}

/// 音高检测结果。
public struct PitchResult: Equatable {
    /// 检测到的基频（Hz）；无法检测时为 nil。
    public let frequency: Double?
    /// 对应音名（如 "E2"）。
    public let noteName: String
    /// 相对最近音（或目标弦）的音分偏差，范围约 ±50。
    public let cents: Double
    /// 是否准音。
    public let isInTune: Bool
    /// 最近弦索引（0=低音 E2 ... 5=高音 E4）。
    public let nearestStringIndex: Int
    /// YIN 清晰度（d'(τ) 谷值，越低越可信；1 = 不可信）。
    public let clarity: Double

    public init(frequency: Double?, noteName: String, cents: Double,
                isInTune: Bool, nearestStringIndex: Int, clarity: Double = 1) {
        self.frequency = frequency
        self.noteName = noteName
        self.cents = cents
        self.isInTune = isInTune
        self.nearestStringIndex = nearestStringIndex
        self.clarity = clarity
    }
}

/// 基于 YIN 算法的音高检测器（核心算法，无 UI 依赖）。
///
/// 相比 Flutter 版（`lib/services/pitch_service.dart`）的两项关键改进：
///
/// 1. **缓冲区提升至 4096**（原 1024）。低音 E2≈82.4Hz，单周期约 535 采样点。
///    原 buffer 的 YIN 差分函数内层缓冲只有 512，`maxTau(≈630) >= yinBufferSize(512)`
///    命中保护逻辑直接返回 0，**低音弦根本无法检测**。提升至 4096 后低音弦可包含
///    约 7 个完整周期，YIN 可靠工作。
///
/// 2. **用对数（音分）差判断最近弦**（原为绝对频率差），使高低弦判定更公平；
///    且整段计算在后台线程执行，不阻塞 UI（Flutter 版在音频回调线程同步执行）。
///
/// 差分函数目前为清晰的直接实现（O(n²)）。对于本场景（halfSize=2048、maxTau≈630，
/// 内层总计算量约 2M 乘加/帧，在 `userInteractive` 后台线程亚毫秒级），性能已完全
/// 足够，且数值精确无误差。后续如需进一步加速，可在此基础上叠加 FFT 互相关加速，
/// 并用本文件的合成信号单元测试做交叉验证。
public final class PitchDetector {

    /// 采样率（Hz）。
    public let sampleRate: Double
    /// YIN 阈值。
    public let yinThreshold: Double
    /// 搜索范围下限 tau（对应高频上限）。
    public let minTau: Int
    /// 搜索范围上限 tau（对应低频下限）。
    public let maxTau: Int
    /// 准音容差（cents）。
    public let tolerance: Double
    /// 单次检测使用的缓冲区大小。
    public let bufferSize: Int
    /// 半缓冲（YIN 差分函数的窗口/输出长度）。
    public let halfBufferSize: Int

    /// 创建检测器。
    /// - Parameters:
    ///   - sampleRate: 采样率。
    ///   - bufferSize: 用于单次检测的采样点数，需为 2 的幂。默认 4096。
    ///   - minFrequency: 搜索频率上限（Hz），默认吉他高音 E4 以上留余量。
    ///   - maxFrequency: 搜索频率下限（Hz），默认吉他低音 E2 以下留余量。
    ///   - yinThreshold: YIN 绝对阈值。
    ///   - tolerance: 准音容差（cents）。
    public init(sampleRate: Double = AppConstants.sampleRate,
                bufferSize: Int = AppConstants.tunerBufferSize,
                minFrequency: Double = AppConstants.guitarMaxFrequency,
                maxFrequency: Double = AppConstants.guitarMinFrequency,
                yinThreshold: Double = AppConstants.yinThreshold,
                tolerance: Double = AppConstants.defaultTunerTolerance) {
        precondition(bufferSize > 0 && (bufferSize & (bufferSize - 1)) == 0,
                     "bufferSize 必须是 2 的幂")
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.halfBufferSize = bufferSize / 2
        self.yinThreshold = yinThreshold
        self.tolerance = tolerance
        self.minTau = max(1, Int(sampleRate / minFrequency))
        self.maxTau = min(halfBufferSize, Int(sampleRate / maxFrequency))
    }

    // MARK: - 公开接口

    /// 对一帧采样做音高检测，返回原始频率（不含平滑）。
    /// - Parameter samples: Float32 单声道采样，长度应 >= bufferSize。
    /// - Returns: 检测到的频率；无法检测返回 nil。
    public func detectFrequency(samples: [Float]) -> Double? {
        detectWithClarity(samples: samples)?.frequency
    }

    /// 提取多音高候选(pYIN 式):带通预滤波后取 CMND 的所有显著谷。
    /// 返回按可信度降序(≤5 个)。无候选返回空(静音/噪声)。
    public func detectCandidates(samples: [Float]) -> [PitchCandidate] {
        let n = halfBufferSize
        guard samples.count >= bufferSize else { return [] }
        guard maxTau < n else { return [] }

        // 带通预滤波(滤波器逐窗口重建,窗口头部有暂态,对周期检测影响可忽略)。
        var hp = BiquadFilter.highPass(sampleRate: sampleRate, fc: 65)
        var lp = BiquadFilter.lowPass(sampleRate: sampleRate, fc: 700)
        var frameD = [Double](repeating: 0, count: bufferSize)
        for i in 0..<bufferSize {
            frameD[i] = lp.process(hp.process(Double(samples[i])))
        }

        var difference = [Double](repeating: 0, count: n)
        differenceFunction(frame: frameD, halfSize: n, output: &difference)
        var cumulative = [Double](repeating: 0, count: n)
        cumulativeMeanNormalizedDifference(difference: difference, output: &cumulative)

        // 收集 [minTau, maxTau) 内的局部极小谷,深度决定可信度。
        var candidates: [PitchCandidate] = []
        var tau = minTau + 1
        while tau < maxTau - 1 {
            let v = cumulative[tau]
            if v < 0.45, v <= cumulative[tau - 1], v <= cumulative[tau + 1] {
                let refined = parabolicInterpolation(cumulative: cumulative, tau: tau)
                let freq = sampleRate / refined
                if freq.isFinite, freq > 0 {
                    let probability = min(1, max(0, (0.45 - v) / 0.35))
                    candidates.append(PitchCandidate(frequency: freq, probability: probability))
                }
                tau += 2
            } else {
                tau += 1
            }
        }
        candidates.sort { $0.probability > $1.probability }
        return Array(candidates.prefix(5))
    }

    /// 带清晰度的检测：返回 (频率, clarity)。clarity = YIN d'(τ) 谷值，
    /// 越低越可信（周期性强）；接近 1 表示不可信。
    public func detectWithClarity(samples: [Float]) -> (frequency: Double, clarity: Double)? {
        let n = halfBufferSize
        guard samples.count >= bufferSize else { return nil }
        guard maxTau < n else { return nil }

        // 取前 bufferSize 个点(转 Double,统一走双精度差分)。
        var frameD = [Double](repeating: 0, count: bufferSize)
        vDSP.convertElements(of: samples.prefix(bufferSize), to: &frameD)

        // 1) 差分函数 d(τ)
        var difference = [Double](repeating: 0, count: n)
        differenceFunction(frame: frameD, halfSize: n, output: &difference)

        // 2) 累积均值归一化 d'(τ)
        var cumulative = [Double](repeating: 0, count: n)
        cumulativeMeanNormalizedDifference(difference: difference, output: &cumulative)

        // 3) 绝对阈值：在 [minTau, maxTau) 内找首个低于阈值的 tau，再取局部最小。
        guard let bestTau = absoluteThreshold(cumulative: cumulative), bestTau > 0 else {
            return nil
        }

        // 4) 抛物线插值，提升亚采样精度。
        let interpolatedTau = parabolicInterpolation(cumulative: cumulative, tau: bestTau)

        let frequency = sampleRate / interpolatedTau
        guard frequency.isFinite, frequency > 0 else { return nil }
        return (frequency, min(1, max(0, cumulative[bestTau])))
    }

    /// 对一帧采样做完整检测（频率 + 音名/音分/准音/最近弦）。
    /// - Parameter targetStringIndex: 可选手动选定弦索引；非空时音分相对该弦计算。
    public func detect(samples: [Float], targetStringIndex: Int? = nil) -> PitchResult {
        guard let detected = detectWithClarity(samples: samples),
              detected.frequency.isFinite, detected.frequency > 0 else {
            return PitchResult(frequency: nil, noteName: "—", cents: 0,
                               isInTune: false, nearestStringIndex: -1)
        }
        let frequency = detected.frequency

        let nearest = nearestStringIndex(for: frequency, override: targetStringIndex)
        let noteName: String
        let cents: Double

        if let target = targetStringIndex,
           target >= 0, target < AppConstants.guitarStringFrequencies.count {
            // 手动模式：音分相对目标弦频率（带越界保护）。
            let targetFreq = AppConstants.guitarStringFrequencies[target]
            cents = 1200.0 * log2(frequency / targetFreq)
            noteName = AppConstants.guitarStringNotes[target]
        } else {
            // 自动模式：相对最近的十二平均律音。
            let (note, noteCents) = frequencyToNote(frequency)
            noteName = note
            cents = noteCents
        }

        let isInTune = abs(cents) <= tolerance
        return PitchResult(frequency: frequency, noteName: noteName, cents: cents,
                           isInTune: isInTune, nearestStringIndex: nearest,
                           clarity: detected.clarity)
    }

    // MARK: - 候选(供 pYIN 式跟踪器)

// MARK: - RBJ 双二阶带通(65-700Hz,吉他基频带)

/// RBJ cookbook 双二阶滤波器。
struct BiquadFilter {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    static func highPass(sampleRate: Double, fc: Double) -> BiquadFilter {
        var f = BiquadFilter()
        let w0 = 2 * Double.pi * fc / sampleRate
        let alpha = sin(w0) / (2 * 0.707)
        f.setCoefficients(
            b0n: (1 + cos(w0)) / 2, b1n: -(1 + cos(w0)), b2n: (1 + cos(w0)) / 2,
            a0n: 1 + alpha, a1n: -2 * cos(w0), a2n: 1 - alpha)
        return f
    }

    static func lowPass(sampleRate: Double, fc: Double) -> BiquadFilter {
        var f = BiquadFilter()
        let w0 = 2 * Double.pi * fc / sampleRate
        let alpha = sin(w0) / (2 * 0.707)
        f.setCoefficients(
            b0n: (1 - cos(w0)) / 2, b1n: 1 - cos(w0), b2n: (1 - cos(w0)) / 2,
            a0n: 1 + alpha, a1n: -2 * cos(w0), a2n: 1 - alpha)
        return f
    }

    private mutating func setCoefficients(b0n: Double, b1n: Double, b2n: Double,
                                          a0n: Double, a1n: Double, a2n: Double) {
        b0 = b0n / a0n; b1 = b1n / a0n; b2 = b2n / a0n
        a1 = a1n / a0n; a2 = a2n / a0n
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }
}

// MARK: - YIN 步骤

    /// 差分函数 d(τ) = Σ_{j=0}^{halfSize-τ-1} (x[j] - x[j+τ])²，τ = 0..halfSize-1。
    /// 窗口随 τ 递减（de Cheveigné & Kawahara 2002 原始形式之一），计算量约 halfSize²/2。
    private func differenceFunction(frame: [Double], halfSize: Int, output: inout [Double]) {
        for tau in 0..<halfSize {
            var sum: Double = 0
            let limit = halfSize - tau
            for j in 0..<limit {
                let delta = frame[j] - frame[j + tau]
                sum += delta * delta
            }
            output[tau] = sum
        }
    }

    /// 累积均值归一化差分函数 d'(τ)。
    private func cumulativeMeanNormalizedDifference(difference: [Double], output: inout [Double]) {
        output[0] = 1.0
        var runningSum: Double = 0
        let n = difference.count
        for tau in 1..<n {
            runningSum += difference[tau]
            if runningSum == 0 {
                output[tau] = 1.0
            } else {
                output[tau] = difference[tau] * Double(tau) / runningSum
            }
        }
    }

    /// 绝对阈值法：在 [minTau, maxTau) 内找首个低于阈值的谷，并取其局部最小。
    /// 找不到则取该范围内的全局最小值（但需低于 0.5 才算可信）。
    private func absoluteThreshold(cumulative: [Double]) -> Int? {
        var bestTau = -1

        var tau = minTau
        while tau < maxTau {
            if cumulative[tau] < yinThreshold {
                // 找到候选，继续找局部最小。
                while tau + 1 < maxTau && cumulative[tau + 1] < cumulative[tau] {
                    tau += 1
                }
                bestTau = tau
                break
            }
            tau += 1
        }

        if bestTau == -1 {
            // 未找到低于阈值的谷：取全局最小，但要求其清晰度可接受（< 0.3）。
            // （旧值 0.5 过宽松——尾音衰减期的噪声帧会从这里漏出幽灵频率。）
            var minVal = Double.infinity
            for t in minTau..<maxTau {
                if cumulative[t] < minVal {
                    minVal = cumulative[t]
                    bestTau = t
                }
            }
            if bestTau <= 0 || minVal > 0.3 {
                return nil
            }
        }
        return bestTau
    }

    /// 抛物线插值，亚采样精度。
    private func parabolicInterpolation(cumulative: [Double], tau: Int) -> Double {
        guard tau >= 1, tau < cumulative.count - 1 else { return Double(tau) }
        let s0 = cumulative[tau - 1]
        let s1 = cumulative[tau]
        let s2 = cumulative[tau + 1]
        let denom = 2 * s1 - s2 - s0
        guard abs(denom) > 1e-6 else { return Double(tau) }
        let adjustment = (s2 - s0) / (2 * denom)
        // 限制插值范围在 ±1 内。
        return Double(tau) + max(-1, min(1, adjustment))
    }

    // MARK: - 频率 <-> 音名

    /// 频率转音名与音分（基于 A4=440Hz 等比律）。
    /// `semitones` 为相对 A4 的半音数；A 在十二音中的索引为 9。
    public func frequencyToNote(_ frequency: Double) -> (note: String, cents: Double) {
        let a4 = 440.0
        let semitones = 12.0 * log2(frequency / a4)
        let rounded = semitones.rounded()
        let cents = (semitones - rounded) * 100.0
        return (Self.noteName(forSemitoneIndex: Int(rounded)), cents)
    }

    /// 半音索引（相对 A4，可为负）→ 音名（如 "E"、"A#"）。
    public static func noteName(forSemitoneIndex index: Int) -> String {
        let noteIndex = ((index + 9) % 12 + 12) % 12
        return AppConstants.noteNames[noteIndex]
    }

    /// 计算频率对应的最近弦索引。
    /// 改进：用对数（音分）差而非绝对频率差，使高低弦判定更公平。
    public func nearestStringIndex(for frequency: Double, override: Int? = nil) -> Int {
        if let override { return override }
        var nearest = 0
        var minCents = Double.infinity
        for (i, targetFreq) in AppConstants.guitarStringFrequencies.enumerated() {
            let cents = abs(1200.0 * log2(frequency / targetFreq))
            if cents < minCents {
                minCents = cents
                nearest = i
            }
        }
        return nearest
    }
}
