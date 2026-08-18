import Foundation

/// 和弦指法数据：6 根弦（低音E→高音E）上每个品位，nil 表示不弹，-1 表示闷音。
/// 索引 0 = 低音 E（第6弦），索引 5 = 高音 E（第1弦）。
public struct ChordShape: Equatable {
    public let name: String
    /// 每根弦的品位（nil=不弹，-1=闷音 x，0=空弦，>0=按品）。
    public let frets: [Int?]
    /// 该指法的基础把位（用于显示几品开始的网格）。
    public let baseFret: Int

    public init(name: String, frets: [Int?], baseFret: Int = 1) {
        self.name = name
        self.frets = frets
        self.baseFret = baseFret
    }
}

/// 内置常用和弦库（约 30 个，覆盖流行/民谣常用调）。
/// frets 从低音 E（第6弦）到高音 E（第1弦）。
public enum ChordLibrary {
    public static let chords: [String: ChordShape] = [
        // C 大调顺阶
        "C":    ChordShape(name: "C",    frets: [-1, 3, 2, 0, 1, 0]),
        "Dm":   ChordShape(name: "Dm",   frets: [-1, -1, 0, 2, 3, 1]),
        "Em":   ChordShape(name: "Em",   frets: [0, 2, 2, 0, 0, 0]),
        "F":    ChordShape(name: "F",    frets: [1, 3, 3, 2, 1, 1]),
        "G":    ChordShape(name: "G",    frets: [3, 2, 0, 0, 0, 3]),
        "Am":   ChordShape(name: "Am",   frets: [-1, 0, 2, 2, 1, 0]),
        // G 大调顺阶
        "D":    ChordShape(name: "D",    frets: [-1, -1, 0, 2, 3, 2]),
        "Bm":   ChordShape(name: "Bm",   frets: [-1, 2, 4, 4, 3, 2], baseFret: 2),
        // 七和弦 / 挂留
        "C7":   ChordShape(name: "C7",   frets: [-1, 3, 2, 3, 1, 0]),
        "D7":   ChordShape(name: "D7",   frets: [-1, -1, 0, 2, 1, 2]),
        "G7":   ChordShape(name: "G7",   frets: [3, 2, 0, 0, 0, 1]),
        "A7":   ChordShape(name: "A7",   frets: [-1, 0, 2, 0, 2, 0]),
        "E7":   ChordShape(name: "E7",   frets: [0, 2, 0, 1, 0, 0]),
        "Am7":  ChordShape(name: "Am7",  frets: [-1, 0, 2, 0, 1, 0]),
        "Dm7":  ChordShape(name: "Dm7",  frets: [-1, -1, 0, 2, 1, 1]),
        "Em7":  ChordShape(name: "Em7",  frets: [0, 2, 0, 0, 0, 0]),
        "Csus2": ChordShape(name: "Csus2", frets: [-1, 3, 5, 5, 3, 3], baseFret: 3),
        "Dsus2": ChordShape(name: "Dsus2", frets: [-1, -1, 0, 2, 3, 0]),
        "Asus4": ChordShape(name: "Asus4", frets: [-1, 0, 2, 2, 3, 0]),
        // 大横按
        "A":    ChordShape(name: "A",    frets: [-1, 0, 2, 2, 2, 0]),
        "E":    ChordShape(name: "E",    frets: [0, 2, 2, 1, 0, 0]),
        "Bb":   ChordShape(name: "Bb",   frets: [1, 1, 3, 3, 3, 1]),
        "B":    ChordShape(name: "B",    frets: [-1, 2, 4, 4, 4, 2], baseFret: 2),
        "B7":   ChordShape(name: "B7",   frets: [-1, 2, 1, 2, 0, 2]),
        // 大七 / 小七
        "Cmaj7": ChordShape(name: "Cmaj7", frets: [-1, 3, 2, 0, 0, 0]),
        "Fmaj7": ChordShape(name: "Fmaj7", frets: [-1, -1, 3, 2, 1, 0]),
        "Dmaj7": ChordShape(name: "Dmaj7", frets: [-1, -1, 0, 2, 2, 2]),
        // 更多小调
        "F#m":  ChordShape(name: "F#m",  frets: [2, 4, 4, 2, 2, 2]),
        "C#m":  ChordShape(name: "C#m",  frets: [-1, 4, 6, 6, 5, 4], baseFret: 4),
        "G#m":  ChordShape(name: "G#m",  frets: [4, 6, 6, 4, 4, 4])
    ]

    /// 按名称查和弦：先查内置表(手工指法更顺手)，找不到则算法求解任意和弦符号。
    public static func find(_ name: String) -> ChordShape? {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        if let s = chords[cleaned] { return s }
        if let s = chords.first(where: { $0.key.lowercased() == cleaned.lowercased() })?.value {
            return s
        }
        return solve(name: cleaned)
    }

    // MARK: - 算法求解(任意和弦符号 → 吉他指法)

    /// 标准调弦各弦空弦 pitch class(E A D G B E)。
    private static let openStringPCs = [4, 9, 2, 7, 11, 4]

    /// 和弦质量后缀 → 相对根音的音程(半音)。精确匹配,含常见别名。
    private static let qualities: [String: [Int]] = [
        "": [0, 4, 7], "m": [0, 3, 7], "min": [0, 3, 7], "-": [0, 3, 7],
        "7": [0, 4, 7, 10],
        "maj7": [0, 4, 7, 11], "M7": [0, 4, 7, 11], "Δ": [0, 4, 7, 11],
        "m7": [0, 3, 7, 10], "min7": [0, 3, 7, 10],
        "m7b5": [0, 3, 6, 10], "ø": [0, 3, 6, 10],
        "dim": [0, 3, 6], "°": [0, 3, 6], "dim7": [0, 3, 6, 9], "°7": [0, 3, 6, 9],
        "aug": [0, 4, 8], "+": [0, 4, 8],
        "sus2": [0, 2, 7], "sus4": [0, 5, 7], "sus": [0, 5, 7],
        "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "min6": [0, 3, 7, 9],
        "add9": [0, 4, 7, 14], "9": [0, 4, 7, 10, 14],
        "maj9": [0, 4, 7, 11, 14], "m9": [0, 3, 7, 10, 14],
        "7sus4": [0, 5, 7, 10],
        "5": [0, 7],
        "maj": [0, 4, 7]
    ]

    /// 解析和弦符号 → (根音/低音 pitch class + 音程集合)。
    private static func parse(_ name: String) -> (rootPC: Int, intervals: [Int], bassPC: Int?)? {
        // 归一化花体符号。
        var s = name
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
            .replacingOccurrences(of: "Δ", with: "maj7")
            .replacingOccurrences(of: "ø", with: "m7b5")
            .replacingOccurrences(of: "°", with: "dim")
        // 转位低音(如 E/G#)。
        var bass: String? = nil
        if let slash = s.firstIndex(of: "/") {
            bass = String(s[s.index(after: slash)...])
            s = String(s[..<slash])
        }
        // 根音长度:字母 + 可选升降号。
        let second = s.count >= 2 ? String(s[s.index(after: s.startIndex)]) : ""
        let rootLen = isAccidental(second) ? 2 : 1
        guard let root = parseNote(String(s.prefix(rootLen))) else { return nil }
        let suffix = String(s.dropFirst(rootLen)).lowercased()
        guard let intervals = qualities[suffix] else { return nil }
        var bassPC: Int? = nil
        if let bass, let b = parseNote(bass) { bassPC = b }
        return (root, intervals, bassPC)
    }

    private static func isAccidental(_ c: String) -> Bool { c == "#" || c == "b" }

    /// 音名(含升降号)→ pitch class。仅首字母大写匹配,保留 'b' 作降号。
    private static func parseNote(_ note: String) -> Int? {
        let base: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        let chars = Array(note.trimmingCharacters(in: .whitespaces))
        guard let first = chars.first else { return nil }
        guard let pc = base[Character(first.uppercased())] else { return nil }
        var result = pc
        for c in chars.dropFirst() {
            if c == "#" { result += 1 }
            else if c == "b" { result -= 1 }
            else if c != " " { return nil }
        }
        return ((result % 12) + 12) % 12
    }

    /// 在指板上搜索合法指法:枚举把位窗口(1..9,跨度 4 品),
    /// 每弦选哑弦或窗口内命中和弦音的品位,按约束过滤后评分取最优。
    static func solve(name: String) -> ChordShape? {
        guard let parsed = parse(name) else { return nil }
        let pcs = Set(parsed.intervals.map { ($0 + parsed.rootPC) % 12 })
        let bass = parsed.bassPC ?? parsed.rootPC
        let minVoiced = max(3, min(pcs.count, 4))

        var best: (score: Int, frets: [Int?], base: Int)? = nil

        for base in 1...9 {
            let allowOpen = (base == 1)
            // 每弦候选:哑弦 + 窗口内命中和弦音的品位。
            var options: [[Int?]] = []
            for stringIdx in 0..<6 {
                var opts: [Int?] = [nil]
                for fret in 0...12 {
                    if fret == 0, !allowOpen { continue }
                    if fret > 0, (fret < base || fret > base + 3) { continue }
                    let pc = (openStringPCs[stringIdx] + fret) % 12
                    if pcs.contains(pc) { opts.append(fret) }
                }
                options.append(opts)
            }

            var frets = [Int?](repeating: nil, count: 6)
            func evaluate() {
                let voicedIdx = frets.indices.filter { frets[$0] != nil }
                guard voicedIdx.count >= minVoiced else { return }
                // 发声弦必须连续(中间不留哑弦,扫弦友好)。
                guard voicedIdx.last! - voicedIdx.first! + 1 == voicedIdx.count else { return }
                let voiced = voicedIdx.map { frets[$0]! }
                // 根音必须发声。
                let sounded = Set(voicedIdx.map { (openStringPCs[$0] + frets[$0]!) % 12 })
                guard sounded.contains(parsed.rootPC) else { return }
                // 最低声部必须是低音(转位和弦的指定低音/根音)。
                let lowest = (openStringPCs[voicedIdx.first!] + frets[voicedIdx.first!]!) % 12
                guard lowest == bass else { return }

                let maxF = voiced.max() ?? 0
                // 评分:声部多 > 把位低 > 按弦省力 > 开放弦多。
                var score = voicedIdx.count * 100
                score -= voiced.reduce(0, +)
                score -= base * 8
                score += voiced.filter { $0 == 0 }.count * 5
                if base == 1, maxF <= 4 { score += 15 }   // 优先开放把位
                let played = voiced.filter { $0 > 0 }
                if let lo = played.min() { score -= (maxF - lo) * 2 }
                if best == nil || score > best!.score {
                    best = (score, frets, maxF > 4 ? base : 1)
                }
            }
            // DFS 枚举(候选已被音级过滤,规模很小)。
            func dfs(_ stringIdx: Int) {
                if stringIdx == 6 { evaluate(); return }
                for opt in options[stringIdx] {
                    frets[stringIdx] = opt
                    dfs(stringIdx + 1)
                }
            }
            dfs(0)
        }
        guard let b = best else { return nil }
        // 哑弦统一用 -1(闷音 ×)表示,指法图上可见"这根弦不弹"。
        return ChordShape(name: name, frets: b.frets.map { $0 ?? -1 }, baseFret: b.base)
    }
}
