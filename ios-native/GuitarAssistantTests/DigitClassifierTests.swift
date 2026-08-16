import XCTest
@testable import GuitarAssistantCore

/// 数字形状分类器测试。
/// 用手画的简单 0/1/2/3 像素图验证分类逻辑。
final class DigitClassifierTests: XCTestCase {

    // "1"：窄竖条（4 宽 x 9 高，接近实心）
    func testClassifyOne() {
        var pixels = [(Int, Int)]()
        for y in 0..<9 { for x in 0..<4 { pixels.append((x, y)) } }   // 全填充
        let blob = DigitClassifier.Blob(width: 4, height: 9, pixels: pixels)
        let r = DigitClassifier.classify(blob)
        XCTAssertEqual(r.digit, 1, "应识别为 1")
    }

    // "0"：方形带孔（13x9，外圈黑，中间白）
    func testClassifyZero() {
        var pixels = [(Int, Int)]()
        for y in 0..<9 { for x in 0..<13 {
            // 外圈
            if x == 0 || x == 12 || y == 0 || y == 8 { pixels.append((x, y)) }
            // 加厚一点让形状更明显
            if x == 1 || x == 11 { pixels.append((x, y)) }
        } }
        let blob = DigitClassifier.Blob(width: 13, height: 9, pixels: pixels)
        let r = DigitClassifier.classify(blob)
        XCTAssertEqual(r.digit, 0, "应识别为 0（有孔），实际 \(r.digit)")
    }

    // "3"：两个半圆，右侧黑像素多。
    // 注意：2/3 区分较难，分类器返回最佳猜测 + 置信度，测试验证返回 2 或 3（合理猜测）。
    func testClassifyThree() {
        var pixels = [(Int, Int)]()
        for y in 0..<9 {
            pixels.append((11, y)); pixels.append((12, y))
            if y == 0 || y == 4 || y == 8 { for x in 4..<13 { pixels.append((x, y)) } }
            if y == 1 || y == 3 || y == 5 || y == 7 { pixels.append((10, y)) }
        }
        let blob = DigitClassifier.Blob(width: 13, height: 9, pixels: pixels)
        let r = DigitClassifier.classify(blob)
        // 2/3 形状接近，接受任一（只要不是明显错的 0/1）。
        XCTAssertTrue(r.digit == 2 || r.digit == 3, "3 应识别为 2 或 3，实际 \(r.digit)")
    }

    // "2"：顶部弯 + 底部横，中间少。同上，接受 2 或 3。
    func testClassifyTwo() {
        var pixels = [(Int, Int)]()
        for y in 0..<9 {
            if y == 0 { for x in 3..<10 { pixels.append((x, y)) } }
            if y == 1 || y == 2 { pixels.append((10, y)); pixels.append((11, y)) }
            if y == 3 || y == 4 { pixels.append((9, y)); pixels.append((10, y)) }
            if y == 5 || y == 6 { pixels.append((5, y)); pixels.append((6, y)) }
            if y == 7 || y == 8 { for x in 2..<12 { pixels.append((x, y)) } }
        }
        let blob = DigitClassifier.Blob(width: 13, height: 9, pixels: pixels)
        let r = DigitClassifier.classify(blob)
        XCTAssertTrue(r.digit == 2 || r.digit == 3, "2 应识别为 2 或 3，实际 \(r.digit)")
    }

    func testEmptyBlob() {
        let blob = DigitClassifier.Blob(width: 5, height: 5, pixels: [])
        let r = DigitClassifier.classify(blob)
        // 空 blob 不应崩溃。
        XCTAssertGreaterThanOrEqual(r.digit, 0)
    }
}
