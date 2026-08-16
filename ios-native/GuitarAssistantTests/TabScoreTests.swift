import XCTest
@testable import GuitarAssistantCore

/// TabScore 数据模型单元测试（编解码、ASCII TAB 导出）。
final class TabScoreTests: XCTestCase {

    // MARK: - 编解码往返

    func testCodableRoundTrip() throws {
        let score = TabScore(
            title: "Test Song",
            bpm: 120,
            measures: [
                TabMeasure(chords: ["C", "Am"], strings: [
                    [FretNote(fret: 0)], [], [FretNote(fret: 2)],
                    [], [FretNote(fret: 3)], []
                ]),
                TabMeasure(chords: ["F"], strings: [
                    [], [FretNote(fret: 1)], [],
                    [FretNote(fret: 3, technique: .hammerOn)],
                    [], [FretNote(fret: 1)]
                ])
            ]
        )
        let json = try score.toJSON()
        let decoded = try TabScore.fromJSON(json)
        XCTAssertEqual(score, decoded, "编解码往返应保持数据一致")
    }

    func testDecodingMinimalJSON() throws {
        // AI 返回的最简结构。
        let json = #"{"measures":[{"chords":["G"],"strings":[[{"fret":3,"technique":"normal"}],[],[],[],[],[]]}]}"#
        let score = try TabScore.fromJSON(json)
        XCTAssertEqual(score.measures.count, 1)
        XCTAssertEqual(score.measures[0].chords, ["G"])
        XCTAssertEqual(score.measures[0].strings[0].first?.fret, 3)
    }

    func testDecodingEmptyStringsTolerated() throws {
        // 某些弦无音符（空数组）应被接受。
        let json = #"{"measures":[{"chords":[],"strings":[[],[],[],[],[],[]]}]}"#
        let score = try TabScore.fromJSON(json)
        XCTAssertTrue(score.measures[0].isEmpty)
    }

    // MARK: - ASCII TAB 导出

    func testAsciiTabHasSixStringLines() {
        let score = TabScore(measures: [TabMeasure(chords: [], strings: Array(repeating: [], count: 6))])
        let tab = score.toAsciiTab()
        let lines = tab.split(separator: "\n")
        XCTAssertEqual(lines.count, 6, "应输出 6 行（每根弦一行）")
        XCTAssertTrue(lines[0].hasPrefix("e|"), "第一行应以高音 E 开头")
        XCTAssertTrue(lines[5].hasPrefix("E|"), "最后一行应以低音 E 开头")
    }

    func testAsciiTabContainsFretNumbers() {
        let score = TabScore(measures: [
            TabMeasure(chords: ["C"], strings: [
                [FretNote(fret: 0)], [], [FretNote(fret: 2)],
                [], [FretNote(fret: 3)], []
            ])
        ])
        let tab = score.toAsciiTab()
        XCTAssertTrue(tab.contains("0"), "应包含空弦 0")
        XCTAssertTrue(tab.contains("2"), "应包含品位 2")
        XCTAssertTrue(tab.contains("3"), "应包含品位 3")
        XCTAssertTrue(tab.contains("C"), "应包含和弦名 C")
    }

    func testAsciiTabMeasureSeparators() {
        let score = TabScore(measures: [
            TabMeasure(chords: [], strings: Array(repeating: [FretNote(fret: 0)], count: 6)),
            TabMeasure(chords: [], strings: Array(repeating: [FretNote(fret: 1)], count: 6))
        ])
        let tab = score.toAsciiTab()
        let firstLine = tab.split(separator: "\n").first!
        // 应有两个小节分隔符（结尾的 | 也算）。
        let barCount = firstLine.filter { $0 == "|" }.count
        XCTAssertGreaterThanOrEqual(barCount, 2, "应有小节分隔符 |")
    }

    func testAsciiTabEmptyScore() {
        let score = TabScore(measures: [])
        let tab = score.toAsciiTab()
        let lines = tab.split(separator: "\n")
        XCTAssertEqual(lines.count, 6, "空曲谱也应输出 6 行骨架")
    }

    // MARK: - 技巧符号

    func testTechniqueSymbolInExport() {
        let score = TabScore(measures: [
            TabMeasure(strings: [
                [FretNote(fret: 5, technique: .hammerOn)], [], [], [], [], []
            ])
        ])
        let tab = score.toAsciiTab()
        XCTAssertTrue(tab.contains("5h"), "击弦应显示 5h")
    }
}
