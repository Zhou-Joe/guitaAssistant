import Foundation
import CoreGraphics
import CoreText

/// 数字形状分类器:多字体软模板 + 高度归一化 + 偏移对齐匹配。
///
/// - 模板:CoreText 高分辨率渲染多种字体,下采样为**墨量密度网格**
///   (保留抗锯齿/笔画粗细信息,而非硬二值)。
/// - 归一化:blob 与模板都按**高度铺满网格、水平居中、保留宽高比**
///   (拉伸归一化会抹掉 "1 窄 0 宽" 这类关键特征)。
/// - 匹配:软 Dice 系数,并对查询做 ±1 格偏移搜索容忍对齐误差。
/// - 辅助证据:宽高比一致性(温和罚分);孔洞数(仅在查询确实检出孔时
///   启用——小字号的孔洞闭合是常态,0 孔不可靠)。
public enum DigitClassifier {

    public struct Blob {
        public let width: Int
        public let height: Int
        /// 黑像素的相对坐标 (x in 0..<width, y in 0..<height)。
        public let pixels: [(x: Int, y: Int)]
        public init(width: Int, height: Int, pixels: [(x: Int, y: Int)]) {
            self.width = width
            self.height = height
            self.pixels = pixels
        }
    }

    public struct Result {
        public let digit: Int
        public let confidence: Double
        public init(digit: Int, confidence: Double) {
            self.digit = digit
            self.confidence = confidence
        }
    }

    // MARK: - 网格与字体

    private static let gridW = 36
    private static let gridH = 48
    private static let fontNames = [
        "Helvetica-Bold", "Helvetica",
        "TimesNewRomanPS-BoldMT", "TimesNewRomanPSMT",
        "Courier-Bold", "Courier",
        "Georgia-Bold", "Menlo-Bold", "AvenirNextCondensed-Bold"
    ]

    // MARK: - 模板缓存

    /// 软模板:fonts × digits 的墨量密度网格(值域 [0,1])。
    private static var templates: [[[Double]]] = []
    /// 模板模糊变体(粗笔画容错:小字号二值化让笔画相对变粗)。
    private static var blurredTemplates: [[[Double]]] = []
    private static var templateHoles: [[Int]] = []
    private static var templateAspect: [[Double]] = []
    private static let lock = NSLock()

    private static func ensureTemplates() {
        lock.lock()
        defer { lock.unlock() }
        guard templates.isEmpty else { return }
        var t: [[[Double]]] = []
        var b: [[[Double]]] = []
        var holes: [[Int]] = []
        var aspects: [[Double]] = []
        for font in fontNames {
            var row: [[Double]] = [], rowB: [[Double]] = [], rowH: [Int] = [], rowA: [Double] = []
            for d in 0...9 {
                let g = renderSoftTemplate(digit: d, fontName: font)
                row.append(g.ink)
                rowB.append(blur(g.ink))
                rowH.append(g.holes); rowA.append(g.aspect)
            }
            t.append(row); b.append(rowB); holes.append(rowH); aspects.append(rowA)
        }
        templates = t
        blurredTemplates = b
        templateHoles = holes
        templateAspect = aspects
    }

    /// 高分辨率渲染 → bbox 裁剪 → 高度归一化密度网格。
    private static func renderSoftTemplate(digit: Int, fontName: String)
        -> (ink: [Double], holes: Int, aspect: Double) {
        let empty = [Double](repeating: 0, count: gridW * gridH)
        let fontSize: CGFloat = 320
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let attr = [kCTFontAttributeName: font] as CFDictionary
        guard let attrString = CFAttributedStringCreate(nil, "\(digit)" as CFString, attr) else {
            return (empty, 0, 0.6)
        }
        let line = CTLineCreateWithAttributedString(attrString)
        let W = 512, H = 512
        var px = [UInt8](repeating: 255, count: W * H)
        guard let ctx = CGContext(data: &px, width: W, height: H,
                                  bitsPerComponent: 8, bytesPerRow: W,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return (empty, 0, 0.6)
        }
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: 96, y: 384)
        CTLineDraw(line, ctx)

        var minX = W, maxX = -1, minY = H, maxY = -1
        for y in 0..<H {
            for x in 0..<W where px[y * W + x] < 128 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return (empty, 0, 0.6) }
        let bw = maxX - minX + 1, bh = maxY - minY + 1
        let aspect = Double(bw) / Double(bh)

        // 高度铺满 gridH(每格 cell 像素),横向按纵横比等比、水平居中。
        let cell = Double(bh) / Double(gridH)
        let scaledW = aspect * Double(gridH)          // 网格列数(含小数)
        let x0 = (Double(gridW) - scaledW) / 2        // 左侧留白(格)
        let SS = 8                                    // 每格 8×8 子采样
        var ink = [Double](repeating: 0, count: gridW * gridH)
        for gy in 0..<gridH {
            for gx in 0..<gridW {
                var black = 0
                for sy in 0..<SS {
                    let wy = minY + Int((Double(gy) + Double(sy) / Double(SS)) * cell)
                    guard wy >= minY, wy <= maxY else { continue }
                    for sx in 0..<SS {
                        let wx = minX + Int((Double(gx) - x0 + Double(sx) / Double(SS)) * cell)
                        guard wx >= minX, wx <= maxX else { continue }
                        if px[wy * W + wx] < 128 { black += 1 }
                    }
                }
                ink[gy * gridW + gx] = Double(black) / Double(SS * SS)
            }
        }
        let binary = ink.map { $0 > 0.5 }
        return (ink, holeCount(binary, w: gridW, h: gridH), aspect)
    }

    /// 模板模糊:与 4 邻域的 0.6 倍取 max(模拟笔画增粗后的形状)。
    private static func blur(_ grid: [Double]) -> [Double] {
        var out = grid
        for gy in 0..<gridH {
            for gx in 0..<gridW {
                let i = gy * gridW + gx
                var m = grid[i]
                if gx > 0 { m = max(m, grid[i - 1] * 0.6) }
                if gx < gridW - 1 { m = max(m, grid[i + 1] * 0.6) }
                if gy > 0 { m = max(m, grid[i - gridW] * 0.6) }
                if gy < gridH - 1 { m = max(m, grid[i + gridW] * 0.6) }
                out[i] = m
            }
        }
        return out
    }

    /// 封闭孔数:从边界白区洪泛,未触边的白区即孔。
    private static func holeCount(_ grid: [Bool], w: Int, h: Int) -> Int {
        var visited = [Bool](repeating: false, count: grid.count)
        var stack: [Int] = []
        func pushBorder() {
            for x in 0..<w {
                for y in [0, h - 1] {
                    let i = y * w + x
                    if !grid[i], !visited[i] { visited[i] = true; stack.append(i) }
                }
            }
            for y in 0..<h {
                for x in [0, w - 1] {
                    let i = y * w + x
                    if !grid[i], !visited[i] { visited[i] = true; stack.append(i) }
                }
            }
        }
        pushBorder()
        while let i = stack.popLast() {
            let x = i % w, y = i / w
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                let j = ny * w + nx
                if !grid[j], !visited[j] { visited[j] = true; stack.append(j) }
            }
        }
        var holes = 0
        for i in 0..<grid.count where !grid[i] && !visited[i] {
            holes += 1
            stack.append(i)
            visited[i] = true
            while let j = stack.popLast() {
                let x = j % w, y = j / w
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                    let k = ny * w + nx
                    if !grid[k], !visited[k] { visited[k] = true; stack.append(k) }
                }
            }
        }
        return holes
    }

    // MARK: - 分类

    public static func classify(_ blob: Blob) -> Result {
        ensureTemplates()
        guard blob.width > 0, blob.height > 0, !blob.pixels.isEmpty else {
            return Result(digit: 0, confidence: 0)
        }
        let queryAspect = Double(blob.width) / Double(blob.height)

        // 查询密度网格:高度铺满、水平居中,四周留 2 格边距供偏移搜索。
        let pad = 2
        let qW = gridW + pad * 2, qH = gridH + pad * 2
        var base = [Double](repeating: 0, count: qW * qH)
        let scaledW = min(Double(gridW), queryAspect * Double(gridH))
        let x0 = (Double(gridW) - scaledW) / 2
        let perCell = max(1.0, Double(blob.pixels.count) / Double(gridW * gridH))
        // 双线性撒点:像素质量按亚像素位置分给相邻 4 格,
        // 小字号 blob 的量化锯齿因此被平滑(对齐信息保留)。
        func splat(_ fx: Double, _ fy: Double, mass: Double) {
            let cx = min(qW - 2, max(0, Int(fx)))
            let cy = min(qH - 2, max(0, Int(fy)))
            let tx = fx - Double(cx), ty = fy - Double(cy)
            base[cy * qW + cx] += mass * (1 - tx) * (1 - ty)
            base[cy * qW + cx + 1] += mass * tx * (1 - ty)
            base[(cy + 1) * qW + cx] += mass * (1 - tx) * ty
            base[(cy + 1) * qW + cx + 1] += mass * tx * ty
        }
        for p in blob.pixels {
            let fx = Double(p.x) / Double(blob.width) * scaledW + x0 + Double(pad)
            let fy = Double(p.y) / Double(blob.height) * Double(gridH) + Double(pad)
            splat(fx, fy, mass: 1 / perCell)
        }
        let queryBinary = base.map { min(1.0, $0) > 0.5 }
        let queryHoles = holeCount(queryBinary, w: qW, h: qH)

        var scores: [Int: Double] = [:]
        for (f, fontRow) in templates.enumerated() {
            for d in 0...9 {
                // 偏移(±1 格) × 纵向尺度(±5%) × 模板变体(原/粗笔画)的软 Dice,
                // 取最优。小字号 blob 的笔画相对增粗 + bbox 漂移由此容忍。
                var best = 0.0
                for tVariant in [fontRow[d], blurredTemplates[f][d]] {
                  for scale in [0.95, 1.0, 1.05] {
                    // 尺度实现:对查询行做重采样(取整格中心映射)。
                    for dy in -1...1 {
                        for dx in -1...1 {
                            var inter = 0.0, sumQ = 0.0, sumT = 0.0
                            for ty in 0..<gridH {
                                let qyF = (Double(ty) - (Double(gridH) * (scale - 1)) / 2)
                                          / scale + Double(dy) + Double(pad)
                                let qy = Int(qyF.rounded())
                                guard qy >= 0, qy < qH else { continue }
                                let qRow = qy * qW
                                let tRow = ty * gridW
                                for tx in 0..<gridW {
                                    let qx = tx + dx + pad
                                    guard qx >= 0, qx < qW else { continue }
                                    let qv = min(1.0, base[qRow + qx])
                                    let tv = tVariant[tRow + tx]
                                    sumQ += qv
                                    sumT += tv
                                    if qv > 0, tv > 0 { inter += min(qv, tv) }
                                }
                            }
                            let dice = sumQ + sumT > 0 ? 2 * inter / (sumQ + sumT) : 0
                            best = max(best, dice)
                        }
                    }
                  }
                }
                var score = best
                // 宽高比一致性(温和罚分)。
                score -= min(0.15, abs(queryAspect - templateAspect[f][d]) * 0.3)
                // 孔洞证据(仅在查询检出孔时启用)。
                if queryHoles > 0 {
                    let th = templateHoles[f][d]
                    if th == queryHoles { score += 0.06 }
                    else if th < queryHoles { score -= 0.10 }
                }
                scores[d] = max(scores[d] ?? 0, score)
            }
        }

        let ranked = scores.sorted { $0.value > $1.value }
        guard let best = ranked.first else { return Result(digit: 0, confidence: 0) }
        let second = ranked.count > 1 ? ranked[1].value : 0
        let margin = max(0, best.value - second)
        let confidence = min(1, max(0.2, best.value * 0.7 + margin * 3.0))
        return Result(digit: best.key, confidence: confidence)
    }
}
