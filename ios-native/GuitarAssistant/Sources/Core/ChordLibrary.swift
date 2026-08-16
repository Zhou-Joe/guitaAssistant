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

    /// 按名称查和弦（大小写不敏感）。
    public static func find(_ name: String) -> ChordShape? {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        if let s = chords[cleaned] { return s }
        return chords.first { $0.key.lowercased() == cleaned.lowercased() }?.value
    }
}
