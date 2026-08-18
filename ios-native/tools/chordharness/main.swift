// 和弦求解器验证 harness(macOS 命令行,编译真实 ChordLibrary.swift)。
// 验证:符号解析、任意和弦的算法求解、指法合法性(音级/根音/低音/声部数/跨度)。

import Foundation

var failures = 0
var passed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("✅ \(name)") }
    else { failures += 1; print("❌ \(name) \(detail())") }
}

let openPC = [4, 9, 2, 7, 11, 4]   // E A D G B E

/// 校验指法合法:发声弦连续、音级都属于和弦、根音在声部里、低音正确。
func validate(_ shape: ChordShape, pcs: Set<Int>, root: Int, bass: Int,
              minVoiced: Int = 3) -> Bool {
    // 发声弦 = 非哑弦且非闷音(nil 或 -1 都不算发声)。
    let idx = shape.frets.indices.filter {
        if let f = shape.frets[$0] { return f >= 0 } else { return false }
    }
    guard idx.count >= minVoiced else { return false }
    guard idx.last! - idx.first! + 1 == idx.count else { return false }
    let voiced = idx.map { shape.frets[$0]! }
    let sounded = Set(idx.map { (openPC[$0] + shape.frets[$0]!) % 12 })
    guard sounded == pcs || sounded.count >= min(voiced.count, pcs.count) else {
        // 声部音级必须都在和弦内(允许省略部分和弦音)。
        return false
    }
    guard sounded.allSatisfy({ pcs.contains($0) }) else { return false }
    guard sounded.contains(root) else { return false }
    let lowest = (openPC[idx.first!] + shape.frets[idx.first!]!) % 12
    guard lowest == bass else { return false }
    // 把位跨度 ≤ 4。
    let played = voiced.filter { $0 > 0 }
    if let lo = played.min(), let hi = played.max(), hi - lo > 4 { return false }
    _ = played
    // 显示基准:baseFret>1 时所有按品都应在窗口内。
    if shape.baseFret > 1 {
        guard played.allSatisfy({ $0 >= shape.baseFret && $0 <= shape.baseFret + 4 }) else { return false }
    }
    return true
}

func pcsOf(root: Int, intervals: [Int]) -> Set<Int> {
    Set(intervals.map { ($0 + root) % 12 })
}

let notePC: [String: Int] = ["C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
                             "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10,
                             "Bb": 10, "B": 11]

// MARK: - 1. 表内和弦照旧

check("表内 C 命中内置指法", ChordLibrary.find("C")?.frets == [-1, 3, 2, 0, 1, 0])
check("大小写不敏感 cm7", ChordLibrary.find("cm7")?.name == "Am7" || ChordLibrary.find("cm7") != nil)

// MARK: - 2. 表外和弦 → 算法求解

let cases: [(name: String, root: String, intervals: [Int], bass: String?)] = [
    ("C#m", "C#", [0, 3, 7], nil),
    ("Gbm", "Gb", [0, 3, 7], nil),
    ("Bbm7", "Bb", [0, 3, 7, 10], nil),
    ("Gmaj7", "G", [0, 4, 7, 11], nil),
    ("Cadd9", "C", [0, 4, 7, 14], nil),
    ("D#dim", "D#", [0, 3, 6], nil),
    ("F5", "F", [0, 7], nil),
    ("Bm7b5", "B", [0, 3, 6, 10], nil),
    ("Esus4", "E", [0, 5, 7], nil),
    ("A9", "A", [0, 4, 7, 10, 14], nil),
    ("E/G#", "E", [0, 4, 7], "G#"),
    ("C/E", "C", [0, 4, 7], "E")
]

for c in cases {
    let shape = ChordLibrary.find(c.name)
    check("求解 \(c.name) 非空", shape != nil, "返回 nil")
    if let shape {
        let root = notePC[c.root]!
        let bass = notePC[c.bass ?? c.root]!
        let minV = c.intervals.count >= 4 ? 4 : 3
        let ok = validate(shape, pcs: pcsOf(root: root, intervals: c.intervals),
                          root: root, bass: bass,
                          minVoiced: c.name.hasSuffix("5") ? 2 : minV)
        check("求解 \(c.name) 指法合法", ok,
              "frets=\(shape.frets) base=\(shape.baseFret)")
    }
}

// MARK: - 3. 花体符号归一化

check("♯ 归一化(F♯m)", ChordLibrary.find("F♯m") != nil)
check("♭ 归一化(B♭)", ChordLibrary.find("B♭") != nil)

// MARK: - 4. 非法输入

check("乱码返回 nil", ChordLibrary.find("xyz") == nil)
check("空串返回 nil", ChordLibrary.find("") == nil)
check("纯低音无根音返回 nil", ChordLibrary.find("/E") == nil)

print("\n通过 \(passed),失败 \(failures)")
exit(failures == 0 ? 0 : 1)
