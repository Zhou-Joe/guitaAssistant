import Foundation
import Accelerate

/// 节拍命中分类。
public enum BeatAccuracy: Int, Equatable {
    case onBeat     // |offset| <= 20ms
    case close      // |offset| <= 60ms
    case off        // 其它
}

/// 节奏分析结果。
public struct RhythmResult: Equatable {
    /// 归一化振幅包络（用于波形图）。
    public let waveform: [Double]
    /// 期望节拍时间戳（ms）。
    public let expectedBeats: [Double]
    /// 实际 onset 时间戳（ms）。
    public let actualBeats: [Double]
    /// 每拍精度（offset ms + 分类）。
    public let perBeat: [(offset: Double, accuracy: BeatAccuracy)]

    public static func == (lhs: RhythmResult, rhs: RhythmResult) -> Bool {
        lhs.waveform == rhs.waveform
        && lhs.expectedBeats == rhs.expectedBeats
        && lhs.actualBeats == rhs.actualBeats
    }
}

/// 聚合节奏统计。
public struct RhythmStats: Equatable {
    public let consistency: Double      // 节奏一致性 %
    public let avgDeviation: Double     // 平均偏离 ms
    public let accuracy: Double         // 命中精度 %
    public let onBeatCount: Int
    public let totalBeats: Int
}

/// 纯 DSP 节奏分析（无 UI / 无 AVFoundation 依赖，可单元测试）。
public struct RhythmAnalyzer {

    public struct Config {
        public var waveformBuckets: Int = 200
        public var onsetFrameMs: Double = 20
        public var onsetSmoothFrames: Int = 5
        public var onsetThreshold: Double = 0.25
        public var minOnsetIntervalMs: Double = 100

        public init() {}
    }

    public init() {}

    /// 对一帧采样做完整节奏分析。
    public func analyze(samples: [Float], sampleRate: Double, targetBPM: Int,
                        config: Config = Config()) -> RhythmResult {
        let waveform = computeWaveform(samples: samples, buckets: config.waveformBuckets)
        let actualBeats = detectOnsets(samples: samples, sampleRate: sampleRate, config: config)
        let expectedBeats = generateExpectedBeats(durationMs: Double(samples.count) / sampleRate * 1000,
                                                   bpm: targetBPM)
        let perBeat = matchBeats(expected: expectedBeats, actual: actualBeats)
        return RhythmResult(waveform: waveform, expectedBeats: expectedBeats,
                            actualBeats: actualBeats, perBeat: perBeat)
    }

    public func computeStats(perBeat: [(offset: Double, accuracy: BeatAccuracy)],
                             bpm: Int = 100) -> RhythmStats {
        guard !perBeat.isEmpty else {
            return RhythmStats(consistency: 0, avgDeviation: 0, accuracy: 0, onBeatCount: 0, totalBeats: 0)
        }
        let total = perBeat.count
        let onBeat = perBeat.filter { $0.accuracy == .onBeat }.count
        let avgAbs = perBeat.map { abs($0.offset) }.reduce(0, +) / Double(total)
        // 按目标 BPM 的拍间隔归一化（替代原来硬编码 600ms）。
        let interval = 60000.0 / Double(max(1, bpm))
        let consistency = max(0, 100 - avgAbs / interval * 100)
        let accuracy = Double(onBeat) / Double(total) * 100
        return RhythmStats(consistency: consistency, avgDeviation: avgAbs,
                           accuracy: accuracy, onBeatCount: onBeat, totalBeats: total)
    }

    // MARK: - 波形包络

    public func computeWaveform(samples: [Float], buckets: Int) -> [Double] {
        guard !samples.isEmpty else { return [] }
        let bucketSize = max(1, samples.count / buckets)
        var result = [Double](repeating: 0, count: buckets)
        var maxRms: Double = 1e-9
        for i in 0..<buckets {
            let start = i * bucketSize
            let end = min((i + 1) * bucketSize, samples.count)
            guard start < end else { continue }
            let chunk = Array(samples[start..<end])
            let sumSq = vDSP.sumOfSquares(chunk)
            let rms = sqrt(Double(sumSq) / Double(end - start))
            result[i] = rms
            if rms > maxRms { maxRms = rms }
        }
        for i in 0..<buckets { result[i] /= maxRms }
        return result
    }

    // MARK: - Onset 检测（时域能量包络峰值法）

    public func detectOnsets(samples: [Float], sampleRate: Double, config: Config) -> [Double] {
        guard samples.count > 0 else { return [] }
        let frameLen = max(1, Int(sampleRate * config.onsetFrameMs / 1000))
        let frameCount = samples.count / frameLen
        guard frameCount > 2 else { return [] }
        var energy = [Double](repeating: 0, count: frameCount)
        var maxE: Double = 1e-9
        for f in 0..<frameCount {
            let start = f * frameLen
            let chunk = Array(samples[start..<(start + frameLen)])
            let sumSq = vDSP.sumOfSquares(chunk)
            let rms = sqrt(Double(sumSq) / Double(frameLen))
            energy[f] = rms
            if rms > maxE { maxE = rms }
        }
        for i in 0..<frameCount { energy[i] /= maxE }
        let smoothed = movingAverage(energy, window: config.onsetSmoothFrames)

        let threshold = config.onsetThreshold
        let win = 3
        var onsets = [Double]()
        var lastOnsetMs: Double = -1
        for i in win..<(frameCount - win) {
            guard smoothed[i] > threshold else { continue }
            var isPeak = true
            for j in (i - win)...(i + win) where j != i {
                if smoothed[j] > smoothed[i] { isPeak = false; break }
            }
            guard isPeak else { continue }
            let timeMs = Double(i) * config.onsetFrameMs
            if lastOnsetMs < 0 || (timeMs - lastOnsetMs) >= config.minOnsetIntervalMs {
                onsets.append(timeMs)
                lastOnsetMs = timeMs
            }
        }
        return onsets
    }

    private func movingAverage(_ input: [Double], window: Int) -> [Double] {
        guard window > 1, input.count > window else { return input }
        var output = [Double](repeating: 0, count: input.count)
        let half = window / 2
        for i in 0..<input.count {
            var sum = 0.0
            var count = 0
            for j in max(0, i - half)...min(input.count - 1, i + half) {
                sum += input[j]
                count += 1
            }
            output[i] = sum / Double(count)
        }
        return output
    }

    // MARK: - 节拍匹配

    public func generateExpectedBeats(durationMs: Double, bpm: Int) -> [Double] {
        let interval = 60_000.0 / Double(bpm)
        var beats = [Double]()
        var t = interval
        while t < durationMs {
            beats.append(t)
            t += interval
        }
        return beats
    }

    public func matchBeats(expected: [Double], actual: [Double]) -> [(offset: Double, accuracy: BeatAccuracy)] {
        guard !actual.isEmpty else {
            // 无实际拍点时，offset 设为期望拍间隔（表示完全偏离），accuracy .off。
            return expected.map { _ in (offset: 999.0, accuracy: BeatAccuracy.off) }
        }
        return expected.map { exp in
            var best = actual[0]
            var bestDiff = abs(best - exp)
            for a in actual {
                let d = abs(a - exp)
                if d < bestDiff { bestDiff = d; best = a }
            }
            let offset = best - exp
            let acc: BeatAccuracy = {
                let ad = abs(offset)
                if ad <= 20 { return .onBeat }
                if ad <= 60 { return .close }
                return .off
            }()
            return (offset: offset, accuracy: acc)
        }
    }
}
