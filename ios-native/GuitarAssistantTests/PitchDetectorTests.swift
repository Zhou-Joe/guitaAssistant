import XCTest
@testable import GuitarAssistantCore

/// 用合成正弦波验证 YIN 音高检测器。
/// 重点：确认 Flutter 版"低音 E2 无法检测"的根因（buffer 太小）已被修复。
final class PitchDetectorTests: XCTestCase {

    /// 生成指定频率的合成正弦波采样（含少量泛音，更接近真实吉他音色）。
    private func generateSineWave(frequency: Double, sampleRate: Double,
                                  count: Int, harmonics: Int = 3) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var s = 0.0
            // 基频 + 若干递减泛音
            for h in 1...harmonics {
                s += sin(twoPi * frequency * Double(h) * t) / Double(h)
            }
            samples[i] = Float(s / Double(harmonics + 1))
        }
        return samples
    }

    // MARK: - 单弦检测（覆盖全部 6 根弦）

    func testDetectsLowE2() {
        // 低音 E2：Flutter 版因 buffer=1024 无法检测；本测试验证修复。
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 82.41, sampleRate: 44100, count: 4096)
        let freq = detector.detectFrequency(samples: samples)
        XCTAssertNotNil(freq, "E2 应能被检测")
        if let freq {
            XCTAssertEqual(freq, 82.41, accuracy: 1.0, "E2 频率应接近 82.41Hz，实际 \(freq)")
        }
    }

    func testDetectsA2() {
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 110.0, sampleRate: 44100, count: 4096)
        let freq = detector.detectFrequency(samples: samples)
        XCTAssertNotNil(freq)
        if let freq { XCTAssertEqual(freq, 110.0, accuracy: 1.0, "实际 \(freq)") }
    }

    func testDetectsD3() {
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 146.83, sampleRate: 44100, count: 4096)
        let freq = detector.detectFrequency(samples: samples)
        XCTAssertNotNil(freq)
        if let freq { XCTAssertEqual(freq, 146.83, accuracy: 1.0, "实际 \(freq)") }
    }

    func testDetectsG3() {
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 196.0, sampleRate: 44100, count: 4096)
        let freq = detector.detectFrequency(samples: samples)
        XCTAssertNotNil(freq)
        if let freq { XCTAssertEqual(freq, 196.0, accuracy: 1.0, "实际 \(freq)") }
    }

    func testDetectsB3() {
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 246.94, sampleRate: 44100, count: 4096)
        let freq = detector.detectFrequency(samples: samples)
        XCTAssertNotNil(freq)
        if let freq { XCTAssertEqual(freq, 246.94, accuracy: 1.0, "实际 \(freq)") }
    }

    func testDetectsHighE4() {
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 329.63, sampleRate: 44100, count: 4096)
        let freq = detector.detectFrequency(samples: samples)
        XCTAssertNotNil(freq)
        if let freq { XCTAssertEqual(freq, 329.63, accuracy: 1.0, "实际 \(freq)") }
    }

    // MARK: - 偏音检测

    func testFlatNoteReportsNegativeCents() {
        let detector = PitchDetector()
        // 偏低 50 音分
        let flatFreq = 82.41 * pow(2.0, -50.0 / 1200.0)
        let samples = generateSineWave(frequency: flatFreq, sampleRate: 44100, count: 4096)
        let result = detector.detect(samples: samples, targetStringIndex: 0)
        XCTAssertNotNil(result.frequency)
        // 相对 E2 的 cents 应约为 -50（允许误差）
        XCTAssertLessThan(result.cents, -10, "偏低应报负音分，实际 \(result.cents)")
    }

    func testSharpNoteReportsPositiveCents() {
        let detector = PitchDetector()
        let sharpFreq = 196.0 * pow(2.0, 30.0 / 1200.0)
        let samples = generateSineWave(frequency: sharpFreq, sampleRate: 44100, count: 4096)
        let result = detector.detect(samples: samples, targetStringIndex: 3)
        XCTAssertNotNil(result.frequency)
        XCTAssertGreaterThan(result.cents, 10, "偏高应报正音分，实际 \(result.cents)")
    }

    func testInTuneReportsInTune() {
        let detector = PitchDetector()
        let samples = generateSineWave(frequency: 110.0, sampleRate: 44100, count: 4096)
        let result = detector.detect(samples: samples, targetStringIndex: 1)
        XCTAssertTrue(result.isInTune, "标准 A2 应判定为准音，cents=\(result.cents)")
    }

    // MARK: - 最近弦判断

    func testNearestStringIndexUsesLogDistance() {
        let detector = PitchDetector()
        // 频率接近 D3（index 2）
        XCTAssertEqual(detector.nearestStringIndex(for: 150.0), 2)
        // 接近高音 E4（index 5）
        XCTAssertEqual(detector.nearestStringIndex(for: 320.0), 5)
        // 接近低音 E2（index 0）
        XCTAssertEqual(detector.nearestStringIndex(for: 85.0), 0)
    }

    // MARK: - 频率转音名

    func testFrequencyToNote() {
        let detector = PitchDetector()
        let (noteA4, centsA4) = detector.frequencyToNote(440.0)
        XCTAssertEqual(noteA4, "A")
        XCTAssertEqual(centsA4, 0, accuracy: 0.5)

        let (noteE, _) = detector.frequencyToNote(82.41)
        XCTAssertEqual(noteE, "E")
    }

    // MARK: - 鲁棒性

    func testSilenceReturnsNil() {
        let detector = PitchDetector()
        let silence = [Float](repeating: 0, count: 4096)
        XCTAssertNil(detector.detectFrequency(samples: silence))
    }

    func testInsufficientSamplesReturnsNil() {
        let detector = PitchDetector()
        let short = generateSineWave(frequency: 110, sampleRate: 44100, count: 256)
        XCTAssertNil(detector.detectFrequency(samples: short))
    }

    // MARK: - 平滑器

    func testSmootherRejectsOutOfRange() {
        let smoother = FrequencySmoother()
        XCTAssertNil(smoother.process(50.0))   // 低于吉他音域
        XCTAssertNil(smoother.process(500.0))  // 高于吉他音域
    }

    func testSmootherReturnsStableMedian() {
        let smoother = FrequencySmoother(windowSize: 5)
        // 围绕 110 抖动，应返回接近 110 的稳定值
        let values: [Double] = [109.5, 110.2, 110.0, 109.8, 110.5]
        var last: Double?
        for v in values { last = smoother.process(v) }
        XCTAssertNotNil(last)
        if let last { XCTAssertEqual(last, 110.0, accuracy: 0.5, "实际 \(last)") }
    }
}
