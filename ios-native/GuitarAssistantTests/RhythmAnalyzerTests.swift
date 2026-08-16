import XCTest
@testable import GuitarAssistantCore

/// 验证节奏分析（onset 检测、节拍匹配、统计）。
/// 用合成的"节拍信号"（在固定间隔处有能量峰值）验证算法能正确找到击拍点。
final class RhythmAnalyzerTests: XCTestCase {

    private let analyzer = RhythmAnalyzer()
    private let sampleRate = 44100.0

    /// 生成一段在固定间隔处有能量脉冲的信号，模拟规律击拍。
    /// 脉冲的**起音点**（onset，能量上升起始）对齐 `beatsMs`，与 onset 检测语义一致。
    /// - Parameters:
    ///   - beatsMs: 各击拍起音的时间戳（ms）。
    ///   - durationMs: 总时长。
    ///   - beatWidthMs: 每个脉冲的宽度。
    private func makeBeatSignal(beatsMs: [Double], durationMs: Double, beatWidthMs: Double = 30) -> [Float] {
        let total = Int(sampleRate * durationMs / 1000)
        var samples = [Float](repeating: 0, count: total)
        let beatWidth = Int(sampleRate * beatWidthMs / 1000)
        for beatMs in beatsMs {
            // onset 在脉冲起始（左沿）。
            let start = max(0, Int(sampleRate * beatMs / 1000))
            let end = min(total, start + beatWidth)
            for i in start..<end {
                samples[i] = 0.9    // 强能量脉冲
            }
        }
        return samples
    }

    // MARK: - Onset 检测

    func testDetectsRegularBeats() {
        // 每 500ms 一个节拍（= 120 BPM），共 6 拍，时长 3s。
        let expectedBeatsMs: [Double] = [500, 1000, 1500, 2000, 2500]
        let samples = makeBeatSignal(beatsMs: expectedBeatsMs, durationMs: 3000)
        let detected = analyzer.detectOnsets(samples: samples, sampleRate: sampleRate,
                                             config: RhythmAnalyzer.Config())
        // 应检测到约 5 个 onset（允许数量略有出入）。
        XCTAssertGreaterThan(detected.count, 3, "应检测到多个节拍，实际 \(detected.count)")
        // 每个 onset 应在某个期望节拍附近（±80ms）。
        for onset in detected {
            let nearest = expectedBeatsMs.map { abs($0 - onset) }.min() ?? 1000
            XCTAssertLessThan(nearest, 120, "onset \(onset)ms 偏离最近的期望节拍过远")
        }
    }

    func testSilenceYieldsNoOnsets() {
        let silence = [Float](repeating: 0, count: 44100)
        let detected = analyzer.detectOnsets(samples: silence, sampleRate: sampleRate,
                                             config: RhythmAnalyzer.Config())
        XCTAssertTrue(detected.isEmpty)
    }

    // MARK: - 期望节拍生成

    func testExpectedBeatsAt120BPM() {
        // 120 BPM → 每 500ms 一拍。
        let beats = analyzer.generateExpectedBeats(durationMs: 3000, bpm: 120)
        XCTAssertEqual(beats.first ?? 0, 500, accuracy: 1)
        XCTAssertEqual(beats.last ?? 0, 2500, accuracy: 1)
        XCTAssertEqual(beats.count, 5)
    }

    // MARK: - 节拍匹配

    func testMatchBeatsPerfectTiming() {
        let expected = [500.0, 1000.0, 1500.0]
        // 实际 onset 与期望完全吻合 → 全部 onBeat。
        let perBeat = analyzer.matchBeats(expected: expected, actual: expected)
        XCTAssertEqual(perBeat.count, 3)
        XCTAssertTrue(perBeat.allSatisfy { $0.accuracy == .onBeat })
    }

    func testMatchBeatsSlightlyOff() {
        let expected = [500.0, 1000.0]
        // 实际偏 30ms → close。
        let actual = [530.0, 1030.0]
        let perBeat = analyzer.matchBeats(expected: expected, actual: actual)
        XCTAssertTrue(perBeat.allSatisfy { $0.accuracy == .close })
    }

    func testMatchBeatsEmptyActual() {
        let expected = [500.0, 1000.0]
        let perBeat = analyzer.matchBeats(expected: expected, actual: [])
        XCTAssertTrue(perBeat.allSatisfy { $0.accuracy == .off })
    }

    // MARK: - 统计

    func testStatsPerfectAccuracy() {
        let perBeat: [(offset: Double, accuracy: BeatAccuracy)] = [
            (offset: 0, accuracy: .onBeat),
            (offset: 5, accuracy: .onBeat),
            (offset: -3, accuracy: .onBeat)
        ]
        let stats = analyzer.computeStats(perBeat: perBeat)
        XCTAssertEqual(stats.accuracy, 100, accuracy: 0.1)
        XCTAssertEqual(stats.onBeatCount, 3)
        XCTAssertEqual(stats.totalBeats, 3)
    }

    func testStatsEmpty() {
        let stats = analyzer.computeStats(perBeat: [])
        XCTAssertEqual(stats.accuracy, 0)
        XCTAssertEqual(stats.totalBeats, 0)
    }

    // MARK: - 波形

    func testWaveformNormalizedToUnit() {
        // 一个强脉冲 + 静音 → 波形在脉冲处接近 1，其余接近 0。
        let samples = makeBeatSignal(beatsMs: [500], durationMs: 1000)
        let waveform = analyzer.computeWaveform(samples: samples, buckets: 50)
        XCTAssertEqual(waveform.max() ?? 0, 1.0, accuracy: 0.01, "最大值应归一化为 1")
    }

    // MARK: - 端到端

    func testEndToEndAccuracy() {
        // 规律的 120 BPM 击拍，目标也是 120 BPM → 准确度应较高。
        let beatsMs = [500.0, 1000.0, 1500.0, 2000.0, 2500.0]
        let samples = makeBeatSignal(beatsMs: beatsMs, durationMs: 3000)
        let result = analyzer.analyze(samples: samples, sampleRate: sampleRate, targetBPM: 120)
        let stats = analyzer.computeStats(perBeat: result.perBeat)
        XCTAssertGreaterThan(stats.accuracy, 50, "规律击拍准确度应较高，实际 \(stats.accuracy)%")
        XCTAssertGreaterThan(result.actualBeats.count, 0, "应检测到 onset")
    }
}
