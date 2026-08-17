import Foundation
import CoreGraphics

// MARK: - 数据结构

/// 候选水平线带(可能是弦线):中心 y、厚度、强度(带内最长水平黑行程)。
public struct TVLineBand: Equatable {
    public let center: Double
    public let thickness: Double
    public let strength: Double
    public init(center: Double, thickness: Double, strength: Double) {
        self.center = center
        self.thickness = thickness
        self.strength = strength
    }
}

/// 一组六线谱系统:6 条弦线 y(升序)+ 平均弦距 + 拟合质量指标。
public struct TVStringSystem: Equatable {
    /// 6 个弦线 y 坐标,升序(顶部 = 高音 E)。缺失的弦线由等差拟合插值补齐。
    public let lineYs: [Double]
    /// 平均弦线间距(像素,工作分辨率下)。
    public let spacing: Double
    /// 实际命中候选线 / 6(插值补齐的线不计),衡量弦线检测可信度。
    public let inlierRatio: Double
    /// 相邻间距变异系数(std/mean),越小越规整。
    public let spacingCV: Double
    /// 弦线平均厚度(像素),用于擦线。
    public let lineThickness: Double
    public init(lineYs: [Double], spacing: Double, inlierRatio: Double,
                spacingCV: Double, lineThickness: Double) {
        self.lineYs = lineYs
        self.spacing = spacing
        self.inlierRatio = inlierRatio
        self.spacingCV = spacingCV
        self.lineThickness = lineThickness
    }
}

/// 识别到的一个数字框(已分类)。
public struct TVDigitBox: Equatable {
    public let digit: Int
    public let confidence: Double
    /// 数字外接框左右边界(用于两位数合并的间距判定)。
    public let x0: Double
    public let x1: Double
    public let cx: Double
    public let cy: Double
    public init(digit: Int, confidence: Double, x0: Double, x1: Double,
                cx: Double, cy: Double) {
        self.digit = digit
        self.confidence = confidence
        self.x0 = x0
        self.x1 = x1
        self.cx = cx
        self.cy = cy
    }
}

// MARK: - 纯算法

/// 六线谱识别的纯算法集合(不依赖 UIKit,可单元测试)。
/// 所有阈值均以"平均弦线间距 d"或图像尺寸的相对值表达,与输入分辨率无关。
public enum TabVisionAlgorithms {

    // MARK: 1. 从每行最长水平黑行程提取候选线带

    /// 弦线是贯穿谱面宽度的水平长线;文字行的最长行程远小于弦线。
    /// 用 maxRun ≥ max(0.45×最长行程, 0.30×图宽) 筛行,再合并相邻行为线带。
    /// - Parameters:
    ///   - maxRunPerRow: 每行最长连续黑像素段长度(下标 = 行 y)。
    ///   - imageWidth: 图宽(像素)。
    public static func extractLineBands(maxRunPerRow: [Double], imageWidth: Double) -> [TVLineBand] {
        guard let longest = maxRunPerRow.max(), longest > 0 else { return [] }
        let threshold = max(0.45 * longest, 0.30 * imageWidth)
        // 合并相邻候选行(允许 ≤2 行的间断,抗锯齿边缘可能掉一行)。
        var bands: [TVLineBand] = []
        var runStart = -1
        var runStrength = 0.0
        var gap = 0
        func closeBand(end: Int) {
            guard runStart >= 0, end > runStart else { return }
            bands.append(TVLineBand(center: Double(runStart + end - 1) / 2.0,
                                    thickness: Double(end - runStart),
                                    strength: runStrength))
            runStart = -1
            runStrength = 0
            gap = 0
        }
        for (y, run) in maxRunPerRow.enumerated() {
            if run >= threshold {
                if runStart < 0 { runStart = y }
                runStrength = max(runStrength, run)
                gap = 0
            } else if runStart >= 0 {
                gap += 1
                if gap > 2 { closeBand(end: y - gap + 1) }
            }
        }
        closeBand(end: maxRunPerRow.count)
        return bands
    }

    // MARK: 2. 等差拟合(RANSAC)分组弦线系统

    /// 把候选线带分组为若干六线谱系统。弦线满足等差数列(y = y0 + m×d);
    /// 标题/歌词/和弦名等文字行不会恰好落在等距网格上,从而被排除。
    /// 支持一图多行谱:拟合出一组后移除其候选带,继续拟合下一组。
    public static func fitStringSystems(bands: [TVLineBand], imageHeight: Double) -> [TVStringSystem] {
        guard bands.count >= 4 else { return [] }
        let minSpacing = 8.0
        let maxSpacing = max(60.0, imageHeight / 5.0)
        var remaining = bands.sorted { $0.center < $1.center }
        var systems: [TVStringSystem] = []
        while remaining.count >= 4 {
            guard let best = bestSystem(in: remaining,
                                        minSpacing: minSpacing,
                                        maxSpacing: maxSpacing,
                                        imageHeight: imageHeight) else { break }
            systems.append(best)
            let tol = 0.36 * best.spacing
            remaining.removeAll { band in
                best.lineYs.contains { abs($0 - band.center) < tol }
            }
        }
        return systems
    }

    /// 在候选带中找最高分的一组六线谱(枚举点对假设等差间距 + 打分)。
    private static func bestSystem(in bands: [TVLineBand], minSpacing: Double,
                                   maxSpacing: Double, imageHeight: Double) -> TVStringSystem? {
        let ys = bands.map(\.center)
        var bestScore = -1.0
        var bestModel: (y0: Double, d: Double)? = nil

        for i in 0..<ys.count {
            for j in (i + 1)..<ys.count {
                let span = ys[j] - ys[i]
                guard span > 0 else { continue }
                // 两带之间可能是 1...5 步(中间弦线缺失时步数不等于带序差)。
                for k in 1...5 {
                    let d = span / Double(k)
                    guard d >= minSpacing, d <= maxSpacing, 5.0 * d <= imageHeight else { continue }
                    // 锚点偏移:yi 不一定是系统顶弦,枚举它落在第 s 槽。
                    for s in 0...k {
                        let y0 = ys[i] - Double(s) * d
                        guard y0 >= -0.5 * d, y0 + 5.0 * d <= imageHeight + 0.5 * d else { continue }
                        // 打分:6 个槽各找 tol 内最近带。连续对齐分(完全对齐=1.0,
                        // 偏移越多分越低),避免"漂移网格"与真实网格同分而误选;
                        // 带强度作次级加分(真实弦线贯穿全宽,强度高,量级远大于文字行)。
                        var hits = 0
                        var alignment = 0.0
                        var strength = 0.0
                        for m in 0..<6 {
                            let slot = y0 + Double(m) * d
                            var nearest = -1
                            var nearestDist = 0.30 * d
                            for b in bands.indices {
                                let dist = abs(bands[b].center - slot)
                                if dist < nearestDist {
                                    nearestDist = dist
                                    nearest = b
                                }
                            }
                            if nearest >= 0 {
                                hits += 1
                                alignment += 1.0 - nearestDist / (0.30 * d)
                                strength += bands[nearest].strength
                            }
                        }
                        // 强度归一:以最强带的强度为参照,最多贡献 0.9 分,
                        // 只在对齐分接近时起决定作用。
                        let strengthBonus = strength > 0 ? min(strength / (6.0 * maxStrength(bands)), 0.9) : 0
                        let score = alignment + strengthBonus
                        if score > bestScore {
                            bestScore = score
                            bestModel = (y0, d)
                        }
                    }
                }
            }
        }
        // 阈值 ≈ 4 个槽的接近完美对齐(4×0.75)。
        guard let model = bestModel, bestScore >= 3.0 else { return nil }
        return refine(model: model, bands: bands)
    }

    private static func maxStrength(_ bands: [TVLineBand]) -> Double {
        bands.map(\.strength).max() ?? 1
    }

    /// 最小二乘精化等差模型并生成最终系统。
    private static func refine(model: (y0: Double, d: Double),
                               bands: [TVLineBand]) -> TVStringSystem? {
        let d0 = model.d
        // 带分配到最近槽(0..<6 且距离 ≤ 0.35×d)。
        var candidates: [(band: Int, slot: Int, dist: Double)] = []
        for (b, band) in bands.enumerated() {
            let slot = Int(((band.center - model.y0) / d0).rounded())
            let slotY = model.y0 + Double(slot) * d0
            let dist = abs(band.center - slotY)
            if (0..<6).contains(slot), dist <= 0.35 * d0 {
                candidates.append((b, slot, dist))
            }
        }
        // 每槽保留最近带。
        var chosen: [Int: Int] = [:]
        for item in candidates.sorted(by: { $0.dist < $1.dist }) {
            if chosen[item.slot] == nil { chosen[item.slot] = item.band }
        }
        guard chosen.count >= 4 else { return nil }

        // 线性回归 y ≈ a + slot×d。
        let pairs = chosen.map { (Double($0.key), bands[$0.value].center) }
        let n = Double(pairs.count)
        let sumM = pairs.reduce(0.0) { $0 + $1.0 }
        let sumY = pairs.reduce(0.0) { $0 + $1.1 }
        let sumMM = pairs.reduce(0.0) { $0 + $1.0 * $1.0 }
        let sumMY = pairs.reduce(0.0) { $0 + $1.0 * $1.1 }
        let denom = n * sumMM - sumM * sumM
        guard abs(denom) > 1e-9 else { return nil }
        let dFit = (n * sumMY - sumM * sumY) / denom
        let aFit = (sumY - dFit * sumM) / n
        guard dFit > 4 else { return nil }

        // 最终槽位:拟合值;附近(0.35×d)有实际带则吸附,并计为 inlier。
        var lineYs: [Double] = []
        var inliers = 0
        var thicknesses: [Double] = []
        for m in 0..<6 {
            let fitted = aFit + Double(m) * dFit
            if let bandIdx = chosen[m] {
                lineYs.append(bands[bandIdx].center)
                inliers += 1
                thicknesses.append(bands[bandIdx].thickness)
            } else {
                lineYs.append(fitted)
            }
        }
        // 间距统计(用吸附后的 y,更贴近真实)。
        var gaps: [Double] = []
        for g in 1..<lineYs.count { gaps.append(lineYs[g] - lineYs[g - 1]) }
        let meanGap = gaps.reduce(0.0, +) / Double(max(gaps.count, 1))
        let variance = gaps.reduce(0.0) { $0 + ($1 - meanGap) * ($1 - meanGap) } / Double(max(gaps.count, 1))
        let cv = meanGap > 0 ? (variance.squareRoot() / meanGap) : 1
        let thickness = thicknesses.isEmpty ? 2 : thicknesses.sorted()[thicknesses.count / 2]
        return TVStringSystem(lineYs: lineYs,
                              spacing: meanGap,
                              inlierRatio: Double(inliers) / 6.0,
                              spacingCV: cv,
                              lineThickness: thickness)
    }

    // MARK: 3. 组装(归弦 + 两位数合并 + 小节切分 + 多系统拼接)

    private struct PlacedNote {
        let string: Int
        let fret: Int
        let conf: Double
        let cx: Double
    }

    /// 把系统 + 数字框组装为 TabScore。
    /// 流程(每个系统内):数字归弦 → 同弦两位数合并(10-24 品)→
    /// 按音符 x 间距切小节 → 组装;多系统按出现顺序拼接。
    public static func assembleScore(systems: [TVStringSystem],
                                     digits: [TVDigitBox],
                                     imageWidth: Double) -> TabScore {
        guard !systems.isEmpty else { return TabScore(measures: []) }
        var allMeasures: [TabMeasure] = []
        for system in systems {
            let d = system.spacing
            guard let top = system.lineYs.first, let bottom = system.lineYs.last else { continue }
            // 该系统纵向范围内的数字。
            let sysDigits = digits.filter { $0.cy >= top - 0.75 * d && $0.cy <= bottom + 0.75 * d }
            // 归弦:最近弦线,且距离 ≤ 0.5d(超出视为和弦名等系统外文字,丢弃;
            // 数字压线居中,真实距离通常 ≤ 0.2d)。
            struct RawItem {
                let string: Int
                let digit: Int
                let conf: Double
                let x0: Double
                let x1: Double
                let cx: Double
                let cy: Double
            }
            var raw: [RawItem] = []
            for digit in sysDigits {
                var best = -1
                var bestDist = 0.5 * d
                for (i, sy) in system.lineYs.enumerated() {
                    let dist = abs(digit.cy - sy)
                    if dist < bestDist { bestDist = dist; best = i }
                }
                if best >= 0 {
                    raw.append(RawItem(string: best, digit: digit.digit, conf: digit.confidence,
                                       x0: digit.x0, x1: digit.x1, cx: digit.cx, cy: digit.cy))
                }
            }
            guard !raw.isEmpty else { continue }

            // 同弦两位数合并:十位 ∈ {1,2}、水平间隙小、基线对齐、合并值 ≤ 24。
            var notesByString = Array(repeating: [PlacedNote](), count: 6)
            for s in 0..<6 {
                let items = raw.filter { $0.string == s }.sorted { $0.cx < $1.cx }
                var i = 0
                while i < items.count {
                    let a = items[i]
                    if i + 1 < items.count {
                        let b = items[i + 1]
                        let gap = b.x0 - a.x1
                        let twoDigit = a.digit * 10 + b.digit
                        if (a.digit == 1 || a.digit == 2), twoDigit <= 24,
                           gap >= -0.12 * d, gap <= 0.50 * d,
                           abs(a.cy - b.cy) <= 0.40 * d {
                            notesByString[s].append(PlacedNote(
                                string: s, fret: twoDigit,
                                conf: min(a.conf, b.conf) * 0.95,
                                cx: (a.cx + b.cx) / 2))
                            i += 2
                            continue
                        }
                    }
                    notesByString[s].append(PlacedNote(string: s, fret: a.digit,
                                                       conf: a.conf, cx: a.cx))
                    i += 1
                }
            }

            // 小节切分:音符 x 间距超过 min(max(中位间距×3, 1.2d), 0.15×图宽) 视为边界。
            let allNotes = (0..<6).flatMap { notesByString[$0] }
            let sortedX = allNotes.map(\.cx).sorted()
            var gaps: [Double] = []
            for g in 1..<sortedX.count { gaps.append(sortedX[g] - sortedX[g - 1]) }
            let medianGap = gaps.isEmpty ? 2 * d : gaps.sorted()[gaps.count / 2]
            let split = min(max(medianGap * 3, 1.2 * d), 0.15 * imageWidth)
            let ordered = allNotes.sorted { $0.cx < $1.cx }
            var groups: [[PlacedNote]] = []
            var current: [PlacedNote] = []
            var lastX = -1.0
            for note in ordered {
                if lastX >= 0, note.cx - lastX > split, !current.isEmpty {
                    groups.append(current)
                    current = []
                }
                current.append(note)
                lastX = note.cx
            }
            if !current.isEmpty { groups.append(current) }

            for group in groups {
                var strings = Array(repeating: [FretNote](), count: 6)
                for note in group { strings[note.string].append(FretNote(fret: note.fret)) }
                allMeasures.append(TabMeasure(chords: [], strings: strings))
            }
        }
        return TabScore(measures: allMeasures)
    }

    // MARK: 4. 置信度

    /// 综合置信度 = 0.35×弦线拟合分 + 0.65×数字分类分。
    public static func confidence(systems: [TVStringSystem], digits: [TVDigitBox]) -> Double {
        guard !systems.isEmpty, !digits.isEmpty else { return 0 }
        let lineScore = systems.reduce(0.0) { acc, s in
            let regularity = max(0, 1 - s.spacingCV / 0.4)
            return acc + 0.5 * s.inlierRatio + 0.5 * regularity
        } / Double(systems.count)
        let digitScore = digits.reduce(0.0) { $0 + $1.confidence } / Double(digits.count)
        return min(1, max(0, 0.35 * lineScore + 0.65 * digitScore))
    }

    // MARK: 5. 像素级工具(仅依赖 CoreGraphics,便于跨平台测试)

    /// 提取 8-bit 灰度像素缓冲(单通道,无 alpha)。
    /// 输出约定:buffer[y*W + x] 的 y=0 对应图像**顶部**行(自然阅读顺序,
    /// 即 CGImage 数据行的原始顺序,已由 macOS harness 的方向实验验证)。
    public static func grayscaleBuffer(of cg: CGImage) -> [UInt8]? {
        let width = cg.width, height = cg.height
        var px = [UInt8](repeating: 0, count: width * height)
        guard let ctx = CGContext(data: &px, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return px
    }

    /// Otsu 全局自适应二值化阈值。
    public static func otsuThreshold(_ px: [UInt8]) -> Int {
        var hist = [Double](repeating: 0, count: 256)
        for v in px { hist[Int(v)] += 1 }
        let total = Double(px.count)
        guard total > 0 else { return 128 }
        var sum = 0.0
        for i in 0..<256 { sum += Double(i) * hist[i] }
        var sumB = 0.0
        var wB = 0.0
        var maxVar = -1.0
        var threshold = 128
        for t in 0..<256 {
            wB += hist[t]
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }
            sumB += Double(t) * hist[t]
            let mB = sumB / wB
            let mF = (sum - sumB) / wF
            let between = wB * wF * (mB - mF) * (mB - mF)
            if between > maxVar { maxVar = between; threshold = t }
        }
        return threshold
    }

    /// 每行最长连续黑像素段长度(下标 = 行 y,y=0 为图像顶部)。
    /// 弦线行 ≈ 谱面宽度,文字行远小于它。
    public static func rowMaxRuns(_ bin: [UInt8], width: Int, height: Int) -> [Double] {
        var runs = [Double](repeating: 0, count: height)
        for y in 0..<height {
            let rowStart = y * width
            var best = 0
            var cur = 0
            for x in 0..<width {
                if bin[rowStart + x] == 1 {
                    cur += 1
                    if cur > best { best = cur }
                } else {
                    cur = 0
                }
            }
            runs[y] = Double(best)
        }
        return runs
    }

    /// 按垂直行程判据擦除弦线像素:
    /// 仅当像素的垂直黑行程 ≤ max(3×线厚, 6) 时才视为"纯线像素"擦掉;
    /// 压在弦线上的数字笔画(垂直行程 = 数字高度)不受影响。
    /// 这样既切断数字与线的连通,又不吃掉数字本体。
    public static func eraseStringLines(_ bin: [UInt8], width: Int, height: Int,
                                        systems: [TVStringSystem]) -> [UInt8] {
        // 先算每个像素的垂直黑行程长度(一次列扫描)。
        var runLen = [Int32](repeating: 0, count: width * height)
        for x in 0..<width {
            var y = 0
            while y < height {
                if bin[y * width + x] == 1 {
                    var e = y
                    while e < height, bin[e * width + x] == 1 { e += 1 }
                    let len = Int32(e - y)
                    for yy in y..<e { runLen[yy * width + x] = len }
                    y = e
                } else {
                    y += 1
                }
            }
        }
        var out = bin
        for system in systems {
            let d = system.spacing
            let thickness = max(2.0, min(system.lineThickness, 0.25 * d))
            let half = Int((thickness / 2).rounded()) + 1
            let maxLineRun = Int32(max(3.0 * thickness, 6.0))
            for lineY in system.lineYs {
                let yi = Int(lineY.rounded())
                let lo = max(0, yi - half - 1)
                let hi = min(height - 1, yi + half + 1)
                guard lo <= hi else { continue }
                for y in lo...hi {
                    let rowStart = y * width
                    for x in 0..<width {
                        let i = rowStart + x
                        if out[i] == 1, runLen[i] <= maxLineRun {
                            out[i] = 0
                        }
                    }
                }
            }
        }
        return out
    }

    /// 连通域分析定位数字块(尺寸阈值以弦线间距 d 为单位,与分辨率无关),
    /// 形状分类后返回 TVDigitBox。
    public static func detectDigitBoxes(_ bin: [UInt8], width: Int, height: Int,
                                        systems: [TVStringSystem]) -> [TVDigitBox] {
        var visited = [Bool](repeating: false, count: width * height)
        var boxes: [TVDigitBox] = []
        func idx(_ x: Int, _ y: Int) -> Int { y * width + x }

        for system in systems {
            let d = system.spacing
            guard let top = system.lineYs.first, let bottom = system.lineYs.last else { continue }
            let yMin = max(0, Int(top - 0.8 * d))
            let yMax = min(height, Int(bottom + 0.8 * d))
            guard yMin < yMax else { continue }
            // 相对尺寸过滤(与分辨率无关):单个数字 0-9 的典型尺寸。
            let minW = 0.12 * d, maxW = 1.15 * d
            let minH = 0.22 * d, maxH = 1.60 * d
            let minArea = 4.0, maxArea = 2.0 * d * d
            for y in yMin..<yMax {
                for x in 0..<width {
                    let i = idx(x, y)
                    guard bin[i] == 1, !visited[i] else { continue }
                    // flood fill(4 邻域)。
                    var stack = [(x, y)]
                    var mnX = x, mxX = x, mnY = y, mxY = y
                    var blobPixels: [(Int, Int)] = []
                    while let (cx, cy) = stack.popLast() {
                        if cx < 0 || cx >= width || cy < 0 || cy >= height { continue }
                        let ci = idx(cx, cy)
                        if visited[ci] || bin[ci] == 0 { continue }
                        visited[ci] = true
                        blobPixels.append((cx, cy))
                        mnX = min(mnX, cx); mxX = max(mxX, cx)
                        mnY = min(mnY, cy); mxY = max(mxY, cy)
                        stack.append((cx + 1, cy)); stack.append((cx - 1, cy))
                        stack.append((cx, cy + 1)); stack.append((cx, cy - 1))
                    }
                    let bw = Double(mxX - mnX + 1)
                    let bh = Double(mxY - mnY + 1)
                    let area = Double(blobPixels.count)
                    guard bw >= minW, bw <= maxW, bh >= minH, bh <= maxH,
                          area >= minArea, area <= maxArea else { continue }
                    let relPixels = blobPixels.map { ($0.0 - mnX, $0.1 - mnY) }
                    let blob = DigitClassifier.Blob(width: Int(bw), height: Int(bh), pixels: relPixels)
                    let result = DigitClassifier.classify(blob)
                    boxes.append(TVDigitBox(digit: result.digit,
                                            confidence: result.confidence,
                                            x0: Double(mnX), x1: Double(mxX),
                                            cx: Double(mnX + mxX) / 2,
                                            cy: Double(mnY + mxY) / 2))
                }
            }
        }
        return boxes
    }
}
