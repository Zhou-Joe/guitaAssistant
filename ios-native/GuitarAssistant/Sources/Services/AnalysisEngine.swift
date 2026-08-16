import Foundation
import AVFoundation

/// 分析结果（UI 层使用）。对应 Flutter `AnalysisResult`，用真实 DSP 填充。
struct AnalysisResult {
    let waveform: [Double]
    let expectedBeats: [Double]
    let actualBeats: [Double]
    let perBeat: [(offset: Double, accuracy: BeatAccuracy)]
    let stats: TimingStats
}

struct TimingStats {
    let consistency: Double
    let avgDeviation: Double
    let accuracy: Double
    let onBeatCount: Int
    let totalBeats: Int
}

/// 音频分析引擎：读取音频文件 → 委托 `RhythmAnalyzer`（Core，纯 DSP）做分析。
/// 文件读取与 UI 类型在此层，纯算法可独立单元测试。
final class AnalysisEngine {

    struct AnalyzeConfig {
        var rhythm: RhythmAnalyzer.Config = .init()
        var targetBPM: Int = 100
    }

    private let analyzer = RhythmAnalyzer()

    /// 分析音频文件。
    func analyze(url: URL, targetBPM: Int, config: AnalyzeConfig = AnalyzeConfig()) -> AnalysisResult? {
        guard let (samples, sampleRate) = readPCM(url: url) else { return nil }
        let result = analyzer.analyze(samples: samples, sampleRate: sampleRate,
                                      targetBPM: targetBPM, config: config.rhythm)
        let stats = analyzer.computeStats(perBeat: result.perBeat)
        return AnalysisResult(waveform: result.waveform,
                              expectedBeats: result.expectedBeats,
                              actualBeats: result.actualBeats,
                              perBeat: result.perBeat,
                              stats: TimingStats(consistency: stats.consistency,
                                                 avgDeviation: stats.avgDeviation,
                                                 accuracy: stats.accuracy,
                                                 onBeatCount: stats.onBeatCount,
                                                 totalBeats: stats.totalBeats))
    }

    // MARK: - 读 PCM（混缩为单声道 Float）

    private func readPCM(url: URL) -> (samples: [Float], sampleRate: Double)? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        do { try file.read(into: buffer) } catch { return nil }

        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        guard let data = buffer.floatChannelData else { return nil }
        var mono = [Float](repeating: 0, count: Int(buffer.frameLength))
        for ch in 0..<channelCount {
            let chData = data[ch]
            for i in 0..<Int(buffer.frameLength) {
                mono[i] += chData[i] / Float(channelCount)
            }
        }
        return (mono, sampleRate)
    }
}
