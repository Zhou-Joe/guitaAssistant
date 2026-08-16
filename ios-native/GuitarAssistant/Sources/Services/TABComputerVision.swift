import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Accelerate

/// 二期：本地六线谱 CV 流水线。
///
/// 流程：Core Image 预处理（灰度+对比+Canny）→ 水平投影找 6 条弦线 →
/// Vision OCR 定位数字 → 数字归位到弦 → 小节切分 → 组装 TabScore。
///
/// 弦线检测采用**水平像素投影法**（逐行求和黑像素 + vDSP 峰检测），
/// 而非已废弃的 VNDetectLineSegmentsRequest —— 对规整六线谱更可靠。
///
/// 注意：本类依赖 UIKit/Vision/CoreImage，无法在 SwiftPM 单元测试中直接跑；
/// 纯算法部分（投影峰检测、数字归位）抽取到静态方法，用合成数据测试。
final class TABComputerVision {

    struct ChordAIConfig {
        let endpoint: String
        let apiKey: String
        let model: String
    }

    /// 最近一次识别的诊断信息（供 UI 调试用）。
    static var diagnostics: String = ""

    init() {}

    /// 累加诊断信息（用 print + 存储，确保日志和 UI 都能看到）。
    private func diag(_ msg: String) {
        Self.diagnostics += msg + "\n"
        print("🌐 [CV] " + msg)
    }

    /// 识别曲谱图片。
    /// - Parameters:
    ///   - image: 曲谱原图。
    ///   - chordConfig: 和弦识别用的 AI 配置（nil 时跳过和弦，仅识别六线谱数字）。
    func recognize(image: UIImage, chordConfig: ChordAIConfig?) async throws -> TabScore {
        Self.diagnostics = ""   // 重置诊断
        diag("开始识别，原图尺寸=\(Int(image.size.width))x\(Int(image.size.height))")
        // 1. 预处理：灰度 + 高对比 + Canny 边缘（iOS 17+）。
        guard let processed = preprocess(image) else {
            diag("❌ 预处理失败")
            throw RecognitionError.imageEncodingFailed
        }
        diag("✅ 预处理完成")

        // 2. 水平投影找 6 条弦线 y 坐标。
        let projection = horizontalBlackProjection(of: processed)
        let pixelHeight = processed.cgImage?.height ?? Int(processed.size.height)
        let stringYs = Self.detectStringLines(from: projection,
                                              imageHeight: pixelHeight)
        diag("投影行数=\(projection.count) 弦线检测=\(stringYs) 投影峰值=\(projection.max() ?? 0) 均值=\(projection.reduce(0,+)/Double(max(1,projection.count)))")

        // 3. 若找不到 6 条弦线，降级：返回空 score（调用方可回退 AI）。
        guard stringYs.count >= 4 else {
            diag("弦线不足4条(\(stringYs.count))，返回空 score")
            return TabScore(measures: [])
        }

        // 4. 数字识别：擦除弦线 → 连通域定位数字块 → 形状特征分类。
        //    （放弃通用 OCR：实测对孤立小数字识别率极低，改用 Audiveris 推荐的
        //     连通域 + 形状分类方案。）
        let digitBoxes = recognizeDigitsViaConnectedComponents(image: processed, stringYs: stringYs)
        diag("连通域+形状分类识别到数字 \(digitBoxes.count) 个: \(digitBoxes.map { "(\($0.digit)@\($0.cx),$($0.cy))" })")

        // 5. 数字归位到弦 + 按列聚类成小节。
        let score = Self.assembleScore(stringYs: stringYs,
                                        digitBoxes: digitBoxes,
                                        imageWidth: processed.size.width)
        diag("组装完成: \(score.measures.count) 个小节")

        // 6. 和弦识别（若配置了 AI）。
        var finalScore = score
        if let chordConfig {
            let chords = try? await recognizeChords(image: image, config: chordConfig)
            if let chords, !chords.isEmpty, !finalScore.measures.isEmpty {
                // 把识别的和弦名分配到各小节（按数量对应）。
                for i in 0..<min(chords.count, finalScore.measures.count) {
                    finalScore.measures[i].chords = [chords[i]]
                }
            }
            diag("和弦识别: \(chords ?? [])")
        } else {
            diag("无 AI 配置，跳过和弦识别（仅六线谱数字）")
        }
        return finalScore
    }

    // MARK: - 预处理

    private func preprocess(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        // 灰度 + 高对比（用于投影找弦线）。
        // 注意：不用 CICannyEdgeDetector——实测它会把六线谱整图变成全黑，
        // 破坏水平投影。弦线本身是黑色的，灰度+高对比后的投影就能清晰找到峰。
        let processed = ci
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.6,
                kCIInputBrightnessKey: 0.0
            ])
        let context = CIContext()
        guard let outputCG = context.createCGImage(processed, from: processed.extent) else {
            return nil
        }
        return UIImage(cgImage: outputCG)
    }

    // MARK: - 水平投影（纯算法，可测试）

    /// 计算每行黑像素数。弦线所在行会有大量黑像素，形成投影曲线的峰。
    /// 返回长度 = imageHeight 的数组，每个元素是该行的黑像素计数。
    private func horizontalBlackProjection(of image: UIImage) -> [Double] {
        guard let cg = image.cgImage else { return [] }
        let width = cg.width
        let height = cg.height
        let bytesPerRow = width
        var pixelData = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: &pixelData,
                                       width: width, height: height,
                                       bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return []
        }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 逐行求和黑像素（<128 视为黑）。
        var projection = [Double](repeating: 0, count: height)
        for y in 0..<height {
            var sum: Double = 0
            let rowStart = y * width
            for x in 0..<width {
                if pixelData[rowStart + x] < 128 { sum += 1 }
            }
            projection[y] = sum
        }
        return projection
    }

    /// 从水平投影曲线检测弦线 y 坐标（纯算法，可单元测试）。
    /// 投影曲线的 6 个峰对应 6 条弦线。
    static func detectStringLines(from projection: [Double], imageHeight: Int) -> [CGFloat] {
        guard projection.count > 10 else { return [] }
        // 求峰值（局部极大且显著高于均值）。
        let mean = projection.reduce(0, +) / Double(projection.count)
        let threshold = mean * 1.8   // 峰值需显著高于均值
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
        // 合并相邻峰（同一条线可能产生多个紧邻峰）。
        var merged: [(y: Int, value: Double)] = []
        var lastY = -100
        for p in peaks {
            if p.y - lastY > 8 {   // 间距大于阈值视为新线
                merged.append(p)
            } else if p.value > (merged.last?.value ?? 0) {
                merged[merged.count - 1] = p
            }
            lastY = p.y
        }
        // 从强度最高的峰开始，贪心挑选"间距接近"的 6 条，
        // 排除孤立的误判（如和弦名文字行——它和其它弦线间距异常）。
        let sortedByValue = merged.sorted { $0.value > $1.value }
        var selected: [(y: Int, value: Double)] = []
        for cand in sortedByValue {
            if selected.count >= 6 { break }
            // 与已选中的最近间距应在一个合理范围（弦线间距相对均匀）。
            let valid = selected.allSatisfy { existing in
                let gap = abs(cand.y - existing.y)
                return gap >= 15   // 至少 15px 间距
            }
            if valid { selected.append(cand) }
        }
        // 按 y 升序（图像顶部=高音E）。
        return selected.sorted { $0.y < $1.y }.map { CGFloat($0.y) }
    }

    // MARK: - 数字识别（连通域 + 形状分类）

    /// 通过连通域分析 + 形状特征分类识别数字。
    /// 流程：取二值图 → 擦除弦线（断开数字与线的连接）→ 连通域定位数字块 → DigitClassifier 分类。
    private func recognizeDigitsViaConnectedComponents(
        image: UIImage, stringYs: [CGFloat]
    ) -> [(digit: Int, cx: CGFloat, cy: CGFloat)] {
        guard let cg = image.cgImage else { return [] }
        let W = cg.width, H = cg.height

        // 读灰度像素。
        var px = [UInt8](repeating: 0, count: W * H)
        guard let gctx = CGContext(data: &px, width: W, height: H,
                                    bitsPerComponent: 8, bytesPerRow: W,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return [] }
        gctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))

        // 二值化。
        var bin = [UInt8](repeating: 0, count: W * H)
        for i in 0..<(W * H) { bin[i] = px[i] < 100 ? 1 : 0 }
        func idx(_ x: Int, _ y: Int) -> Int { return y * W + x }

        // 擦除弦线（每条弦线 y 附近 ±2 行置白），断开数字与线的像素连接。
        for sy in stringYs {
            let yi = Int(sy)
            for dy in -2...2 {
                let y = yi + dy
                guard y >= 0 && y < H else { continue }
                for x in 0..<W { bin[idx(x, y)] = 0 }
            }
        }

        // 弦线区域的 y 范围（数字只出现在这里）。
        let yMin = max(0, Int(stringYs.first ?? 0) - 15)
        let yMax = min(H, Int(stringYs.last ?? CGFloat(H)) + 15)

        // 连通域分析（flood fill 4 邻域）。
        var visited = [Bool](repeating: false, count: W * H)
        var digitBoxes: [(digit: Int, cx: CGFloat, cy: CGFloat)] = []
        for y in yMin..<yMax {
            for x in 0..<W {
                let i = idx(x, y)
                guard bin[i] == 1, !visited[i] else { continue }
                // flood fill 找连通块。
                var stack = [(x, y)]
                var mnX = x, mxX = x, mnY = y, mxY = y
                var blobPixels: [(Int, Int)] = []
                while let (cx, cy) = stack.popLast() {
                    if cx < 0 || cx >= W || cy < 0 || cy >= H { continue }
                    let ci = idx(cx, cy)
                    if visited[ci] || bin[ci] == 0 { continue }
                    visited[ci] = true
                    blobPixels.append((cx, cy))
                    mnX = min(mnX, cx); mxX = max(mxX, cx)
                    mnY = min(mnY, cy); mxY = max(mxY, cy)
                    stack.append((cx + 1, cy)); stack.append((cx - 1, cy))
                    stack.append((cx, cy + 1)); stack.append((cx, cy - 1))
                }
                let bw = mxX - mnX + 1, bh = mxY - mnY + 1
                let area = blobPixels.count
                // 数字块尺寸过滤（排除噪声和弦线残余）。
                guard bw >= 3, bw <= 25, bh >= 4, bh <= 20, area >= 6, area <= 300 else { continue }
                // 用 DigitClassifier 分类。
                let relPixels = blobPixels.map { ($0.0 - mnX, $0.1 - mnY) }
                let blob = DigitClassifier.Blob(width: bw, height: bh, pixels: relPixels)
                let result = DigitClassifier.classify(blob)
                let centerX = CGFloat(mnX + mxX) / 2
                let centerY = CGFloat(mnY + mxY) / 2
                digitBoxes.append((result.digit, centerX, centerY))
            }
        }
        return digitBoxes
    }

    // MARK: - 组装曲谱（纯算法，可测试）

    /// 把弦线 y 坐标 + 数字框（digit,中心x,中心y）组装成 TabScore。
    /// 数字按 y 归位到最近弦，按 x 聚类成小节。
    static func assembleScore(stringYs: [CGFloat],
                               digitBoxes: [(digit: Int, cx: CGFloat, cy: CGFloat)],
                               imageWidth: CGFloat) -> TabScore {
        guard !stringYs.isEmpty else { return TabScore(measures: []) }

        // 1. 每个数字归位到弦（最近弦线，弦索引 0=高音E=最顶部）。
        // stringYs 已按升序（顶部到顶部=高音E到低音E）。
        var placed: [(stringIdx: Int, digit: Int, x: CGFloat)] = []
        for box in digitBoxes {
            // 找最近的弦线 y。
            var bestIdx = 0
            var bestDist = CGFloat.infinity
            for (i, sy) in stringYs.enumerated() {
                let d = abs(box.cy - sy)
                if d < bestDist { bestDist = d; bestIdx = i }
            }
            placed.append((bestIdx, box.digit, box.cx))
        }

        // 2. 按 x 聚类成小节。用相邻间距的中位数 * 3 作为切分阈值
        //    （异常大的间距视为小节边界）。
        let sorted = placed.sorted { $0.x < $1.x }
        var gaps: [CGFloat] = []
        for i in 1..<sorted.count { gaps.append(sorted[i].x - sorted[i-1].x) }
        let medianGap = gaps.isEmpty ? imageWidth / 4 : gaps.sorted()[gaps.count / 2]
        // 阈值取"中位间距的3倍"与"图宽15%"的较小者。
        let splitThreshold = min(medianGap * 3, imageWidth * 0.15)
        var measures: [[(stringIdx: Int, digit: Int, x: CGFloat)]] = []
        var currentMeasure: [(stringIdx: Int, digit: Int, x: CGFloat)] = []
        var lastX: CGFloat = -1
        for item in sorted {
            if lastX >= 0 && item.x - lastX > splitThreshold && !currentMeasure.isEmpty {
                measures.append(currentMeasure)
                currentMeasure = []
            }
            currentMeasure.append(item)
            lastX = item.x
        }
        if !currentMeasure.isEmpty { measures.append(currentMeasure) }

        // 3. 每个 measure 组装 6 行。
        let tabMeasures = measures.map { items -> TabMeasure in
            var strings: [[FretNote]] = Array(repeating: [], count: 6)
            for it in items {
                let note = FretNote(fret: it.digit)
                if it.stringIdx < 6 {
                    strings[it.stringIdx].append(note)
                }
            }
            return TabMeasure(chords: [], strings: strings)
        }
        return TabScore(measures: tabMeasures)
    }

    // MARK: - 和弦识别（走 AI，可选）

    private func recognizeChords(image: UIImage, config: ChordAIConfig) async throws -> [String] {
        guard let dataURI = ImageEncoder.jpegDataURI(image) else { return [] }
        let service = AIChatService()
        let prompt = """
        List ONLY the chord names written above the staff in this guitar TAB image, left to right, one per measure.
        Output a JSON array of strings, e.g. ["C","Am","F","G"]. No other text.
        """
        let raw = try await service.recognizeTab(endpoint: config.endpoint, apiKey: config.apiKey,
                                                  model: config.model, imageDataURI: dataURI, prompt: prompt)
        // 解析 JSON 数组。
        if let data = raw.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }
        return []
    }
}
