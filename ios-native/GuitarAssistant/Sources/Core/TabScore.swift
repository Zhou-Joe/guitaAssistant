import Foundation

/// 吉他演奏技巧（品位音符的修饰）。
public enum TabTechnique: String, Codable, Equatable, CaseIterable {
    case normal       // 普通弹奏
    case hammerOn     // 击弦（h）
    case pullOff      // 勾弦（p）
    case slide        // 滑音（/ 或 \）
    case bend         // 推弦（b）
    case harmonic     // 泛音
    case palmMute     // 闷音
    case letRing      // 延音（let ring）

    /// ASCII TAB 中显示的修饰符号。
    public var symbol: String {
        switch self {
        case .normal: return ""
        case .hammerOn: return "h"
        case .pullOff: return "p"
        case .slide: return "/"
        case .bend: return "b"
        case .harmonic: return "<>"
        case .palmMute: return "PM"
        case .letRing: return "ring"
        }
    }
}

/// 一个品位音符（在某根弦上按某品）。
public struct FretNote: Codable, Equatable {
    /// 品位：0=空弦，1-24。
    public var fret: Int
    /// 演奏技巧。
    public var technique: TabTechnique

    public init(fret: Int, technique: TabTechnique = .normal) {
        self.fret = fret
        self.technique = technique
    }
}

/// 一个小节。
public struct TabMeasure: Codable, Equatable, Identifiable {
    /// 稳定标识（用于 SwiftUI ForEach，避免用 offset 导致删除错位）。
    /// Codable 编解码时自动处理：解码旧 JSON 无此字段时自动生成。
    public var id: UUID
    /// 该小节上方标注的和弦名（如 ["C", "Am"]）。
    public var chords: [String]
    /// 六线谱：6 行，索引 0 = 高音 E（第 1 弦），索引 5 = 低音 E（第 6 弦）。
    /// 每行是该小节内这根弦上按时间顺序出现的品位音符序列。
    public var strings: [[FretNote]]

    public init(id: UUID = UUID(), chords: [String] = [],
                strings: [[FretNote]] = Array(repeating: [], count: 6)) {
        self.id = id
        self.chords = chords
        self.strings = strings
    }

    /// 该小节是否为空（无音符也无和弦）。
    public var isEmpty: Bool { strings.allSatisfy { $0.isEmpty } && chords.isEmpty }

    // MARK: - Codable（向后兼容：旧 JSON 无 id 时自动生成）

    private enum CodingKeys: String, CodingKey {
        case id, chords, strings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        chords = try c.decode([String].self, forKey: .chords)
        strings = try c.decode([[FretNote]].self, forKey: .strings)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(chords, forKey: .chords)
        try c.encode(strings, forKey: .strings)
    }
}

/// 完整的结构化曲谱（识别结果的核心数据模型，纯 Swift，可单元测试）。
public struct TabScore: Codable, Equatable {
    public var title: String?
    public var bpm: Int?
    public var measures: [TabMeasure]

    public init(title: String? = nil, bpm: Int? = nil, measures: [TabMeasure] = []) {
        self.title = title
        self.bpm = bpm
        self.measures = measures
    }

    // MARK: - ASCII TAB 导出

    /// 导出为标准 ASCII TAB 文本（6 行，e/B/G/D/A/E）。
    /// 每个小节用 `|` 分隔，品位之间用 `-` 连接。
    public func toAsciiTab() -> String {
        // 标准调弦音名（从高音 E 到低音 E，对应 strings 索引 0..5）。
        let stringNames = ["e", "B", "G", "D", "A", "E"]
        guard !measures.isEmpty else {
            // 无小节也输出一个空骨架。
            return stringNames.map { "\($0)|" }.joined(separator: "\n")
        }

        // 先把每个小节渲染成 6 行（每行不含弦名前缀），并记录每行宽度用于对齐。
        // 同一小节内，6 根弦的最大音符数决定该小节宽度。
        var renderedMeasures: [[String]] = []   // [measureIndex][stringIndex] -> 该弦该小节的文本
        var measureWidths: [Int] = []

        for measure in measures {
            var rows = [String](repeating: "", count: 6)
            // 计算每根弦的文本长度，对齐到该小节最长弦。
            var stringTexts = [String](repeating: "", count: 6)
            for i in 0..<6 {
                let notes = i < measure.strings.count ? measure.strings[i] : []
                stringTexts[i] = notes.map { note -> String in
                    let f = "\(note.fret)"
                    return note.technique == .normal ? f : "\(f)\(note.technique.symbol)"
                }.joined(separator: "-")
            }
            let maxLen = max(2, stringTexts.map(\.count).max() ?? 2)
            measureWidths.append(maxLen)
            for i in 0..<6 {
                // 用 - 填充到 maxLen 对齐。
                let padded = stringTexts[i].padding(toLength: maxLen, withPad: "-", startingAt: 0)
                rows[i] = padded
            }
            renderedMeasures.append(rows)
        }

        // 拼装最终 6 行：弦名 + | + 各小节用 | 分隔。
        var lines = [String]()
        for stringIdx in 0..<6 {
            var line = stringNames[stringIdx] + "|"
            for (mIdx, rows) in renderedMeasures.enumerated() {
                line += rows[stringIdx]
                line += "|"
            }
            lines.append(line)
        }

        // 顶部加和弦行（若有）。
        let hasChords = measures.contains { !$0.chords.isEmpty }
        if hasChords {
            var chordLine = "  "
            for (mIdx, measure) in measures.enumerated() {
                let label = measure.chords.joined(separator: ",")
                let width = measureWidths[mIdx]
                // 和弦名居中到小节宽度。
                let pad = max(0, (width - label.count) / 2)
                chordLine += String(repeating: " ", count: pad) + label
                let used = pad + label.count
                if used < width + 1 { chordLine += String(repeating: " ", count: width + 1 - used) }
            }
            lines.insert(chordLine, at: 0)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON 编解码

    /// 编码为 JSON 字符串。
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 从 JSON 字符串解码。
    public static func fromJSON(_ json: String) throws -> TabScore {
        guard let data = json.data(using: .utf8) else {
            throw TabScoreError.invalidJSON
        }
        let decoder = JSONDecoder()
        return try decoder.decode(TabScore.self, from: data)
    }
}

public enum TabScoreError: Error {
    case invalidJSON
    case aiReturnedNonJSON
    case schemaMismatch
}
