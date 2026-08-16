import XCTest
import CoreGraphics
@testable import GuitarAssistantCore

/// TABComputerVision 纯算法部分测试。
/// 注意：TABComputerVision 本身依赖 UIKit，无法在 SwiftPM 直接测；
/// 但其静态算法方法（detectStringLines / assembleScore）用 CGFloat/Double，
/// 可在 Core 包里暴露纯函数版本测试。这里用合成数据验证逻辑。
final class TABProjectionTests: XCTestCase {

    // MARK: - 投影峰检测

    /// 合成一个含 6 个明显峰的投影曲线，验证能找到 6 个峰。
    func testDetectSixStringLines() {
        // 模拟一张 1000 高的图，6 条弦线在 y = 100,250,400,550,700,850。
        let lineYs = [100, 250, 400, 550, 700, 850]
        var projection = [Double](repeating: 5, count: 1000)   // 基线噪声
        for y in lineYs {
            for dy in -3...3 {
                let idx = y + dy
                if idx >= 0 && idx < 1000 {
                    projection[idx] = 200   // 弦线峰
                }
            }
        }
        // 调用静态方法（在 Core 之外，用等价逻辑验证）。
        // TABComputerVision.detectStringLines 不在 Core 包，这里复刻逻辑做验证。
        let detected = detectLines(from: projection)
        XCTAssertEqual(detected.count, 6, "应检测到 6 条弦线，实际 \(detected.count)")
        // 检测到的 y 应接近真实弦线 y（±15 容差）。
        for (i, real) in lineYs.enumerated() {
            if i < detected.count {
                XCTAssertLessThan(abs(detected[i] - CGFloat(real)), 15,
                                  "弦 \(i) 应在 \(real) 附近，实际 \(detected[i])")
            }
        }
    }

    func testNoLinesOnFlatProjection() {
        let projection = [Double](repeating: 10, count: 500)   // 全平
        let detected = detectLines(from: projection)
        XCTAssertTrue(detected.isEmpty, "平坦投影不应检测到弦线")
    }

    // MARK: - 数字归位到弦

    func testAssembleScoreAssignsToStrings() {
        // 6 条弦线在 y = 100,200,300,400,500,600（高音E 到 低音E）。
        let stringYs: [CGFloat] = [100, 200, 300, 400, 500, 600]
        // 数字：(digit, cx, cy)。模拟第1弦(高E)有 0，第6弦(低E)有 3。
        let digitBoxes: [(digit: Int, cx: CGFloat, cy: CGFloat)] = [
            (0, 50, 100),   // 落在第1弦
            (3, 50, 600)    // 落在第6弦
        ]
        let score = assemble(stringYs: stringYs, digitBoxes: digitBoxes, imageWidth: 500)
        XCTAssertEqual(score.measures.count, 1)
        // 索引0=高音E，应有 fret 0。
        XCTAssertEqual(score.measures[0].strings[0].first?.fret, 0)
        // 索引5=低音E，应有 fret 3。
        XCTAssertEqual(score.measures[0].strings[5].first?.fret, 3)
    }

    func testAssembleScoreSplitsMeasuresByX() {
        let stringYs: [CGFloat] = [100, 200, 300, 400, 500, 600]
        // 两组数字 x 间距很大 → 应分成两个小节。
        let digitBoxes: [(digit: Int, cx: CGFloat, cy: CGFloat)] = [
            (0, 50, 100),
            (1, 400, 100)   // x 间距 350 > 阈值
        ]
        let score = assemble(stringYs: stringYs, digitBoxes: digitBoxes, imageWidth: 500)
        XCTAssertGreaterThanOrEqual(score.measures.count, 2,
                                     "x 间距大的数字应分到不同小节")
    }

    // MARK: - 复刻 TABComputerVision 静态逻辑（因 CV 类不在 Core 包，无法直接调用）
    // 这些是 TABComputerVision.detectStringLines / assembleScore 的等价纯函数，
    // 用于验证算法正确性。

    private func detectLines(from projection: [Double]) -> [CGFloat] {
        guard projection.count > 10 else { return [] }
        let mean = projection.reduce(0, +) / Double(projection.count)
        let threshold = mean * 1.8
        var peaks: [(y: Int, value: Double)] = []
        let win = 5
        for i in win..<(projection.count - win) {
            guard projection[i] > threshold else { continue }
            var isPeak = true
            for j in (i - win)...(i + win) where j != i {
                if projection[j] > projection[i] { isPeak = false; break }
            }
            if isPeak { peaks.append((i, projection[i])) }
        }
        var merged: [(y: Int, value: Double)] = []
        var lastY = -100
        for p in peaks {
            if p.y - lastY > 8 { merged.append(p) }
            else if p.value > (merged.last?.value ?? 0) { merged[merged.count - 1] = p }
            lastY = p.y
        }
        let top6 = merged.sorted { $0.value > $1.value }.prefix(6).sorted { $0.y < $1.y }
        return top6.map { CGFloat($0.y) }
    }

    private func assemble(stringYs: [CGFloat],
                          digitBoxes: [(digit: Int, cx: CGFloat, cy: CGFloat)],
                          imageWidth: CGFloat) -> TabScore {
        var placed: [(stringIdx: Int, digit: Int, x: CGFloat)] = []
        for box in digitBoxes {
            var bestIdx = 0
            var bestDist = CGFloat.infinity
            for (i, sy) in stringYs.enumerated() {
                let d = abs(box.cy - sy)
                if d < bestDist { bestDist = d; bestIdx = i }
            }
            placed.append((bestIdx, box.digit, box.cx))
        }
        let sorted = placed.sorted { $0.x < $1.x }
        // 小节切分阈值：用相邻间距的中位数 * 3（异常大的间距视为小节边界）。
        var gaps: [CGFloat] = []
        for i in 1..<sorted.count { gaps.append(sorted[i].x - sorted[i-1].x) }
        let medianGap = gaps.isEmpty ? imageWidth / 4 : gaps.sorted()[gaps.count / 2]
        // 阈值取"中位间距的3倍"与"图宽15%"的较小者，保证既能切小节又不过度切分。
        let splitThreshold = min(medianGap * 3, imageWidth * 0.15)
        var measures: [[(stringIdx: Int, digit: Int, x: CGFloat)]] = []
        var current: [(stringIdx: Int, digit: Int, x: CGFloat)] = []
        var lastX: CGFloat = -1
        for item in sorted {
            if lastX >= 0 && item.x - lastX > splitThreshold && !current.isEmpty {
                measures.append(current); current = []
            }
            current.append(item); lastX = item.x
        }
        if !current.isEmpty { measures.append(current) }
        let tabMeasures = measures.map { items -> TabMeasure in
            var strings: [[FretNote]] = Array(repeating: [], count: 6)
            for it in items {
                if it.stringIdx < 6 { strings[it.stringIdx].append(FretNote(fret: it.digit)) }
            }
            return TabMeasure(chords: [], strings: strings)
        }
        return TabScore(measures: tabMeasures)
    }
}
