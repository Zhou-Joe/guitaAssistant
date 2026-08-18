import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Accelerate

/// 本地六线谱 CV 流水线(分辨率无关版)。
///
/// 流程:
/// 1. 方向归一化(应用 EXIF orientation)+ 等比降采样(最长边 ≤1600)
/// 2. 灰度 + 对比度增强 + Otsu 自适应二值化
/// 3. 每行最长水平黑行程 → 候选线带 → 等差拟合(RANSAC)得到六线谱系统(支持多行谱)
/// 4. 按垂直行程判据擦除弦线(只擦"纯线"像素,不破坏压在弦线上的数字)
/// 5. 连通域定位数字块(尺寸阈值以弦线间距为单位,与分辨率无关)
/// 6. DigitClassifier 分类 → 归弦 → 两位数合并(10-24 品)→ 小节切分
///
/// 纯算法部分在 `TabVisionAlgorithms`(无 UIKit 依赖,可单元测试)。
///
/// 注意:本类依赖 UIKit/Vision/CoreImage,无法在 SwiftPM 单元测试中直接跑。
final class TABComputerVision {

    struct ChordAIConfig {
        let endpoint: String
        let apiKey: String
        let model: String
    }

    /// CV 识别结果:曲谱 + 真实置信度(由弦线拟合分与数字分类分综合)。
    struct CVResult {
        let score: TabScore
        let confidence: Double
    }

    /// 最近一次识别的诊断信息(供 UI 调试用)。
    static var diagnostics: String = ""

    init() {}

    /// 累加诊断信息(用 print + 存储,确保日志和 UI 都能看到)。
    private func diag(_ msg: String) {
        Self.diagnostics += msg + "\n"
        print("🌐 [CV] " + msg)
    }

    /// 工作分辨率上限:所有像素阈值以此为前提,超清图先降采样。
    private static let maxWorkingDimension: CGFloat = 1600

    /// 识别曲谱图片。
    /// - Parameters:
    ///   - image: 曲谱原图(任意方向/分辨率)。
    ///   - chordConfig: 和弦识别用的 AI 配置(nil 时跳过和弦,仅识别六线谱数字)。
    func recognize(image: UIImage, chordConfig: ChordAIConfig?) async throws -> CVResult {
        Self.diagnostics = ""   // 重置诊断
        diag("开始识别,原图尺寸=\(Int(image.size.width))x\(Int(image.size.height)) orientation=\(image.imageOrientation.rawValue)")

        // 1. 方向归一化 + 降采样(CGImage 不带 orientation,必须重绘)。
        guard let normalized = Self.uprightAndScaled(image, maxDimension: Self.maxWorkingDimension) else {
            diag("❌ 方向归一化失败")
            throw RecognitionError.imageEncodingFailed
        }
        guard let cg = normalized.cgImage else {
            diag("❌ 归一化后无 cgImage")
            throw RecognitionError.imageEncodingFailed
        }
        let W = cg.width, H = cg.height
        diag("✅ 归一化完成 \(W)x\(H)")

        // 2. 预处理:灰度 + 高对比。
        guard let processed = preprocess(normalized) else {
            diag("❌ 预处理失败")
            throw RecognitionError.imageEncodingFailed
        }

        // 3. 灰度像素缓冲 + Otsu 二值化。
        guard let processedCG = processed.cgImage,
              let gray = TabVisionAlgorithms.grayscaleBuffer(of: processedCG) else {
            diag("❌ 灰度缓冲失败")
            throw RecognitionError.imageEncodingFailed
        }
        let otsu = TabVisionAlgorithms.otsuThreshold(gray)
        let threshold = (30...220).contains(otsu) ? otsu : 128
        let bin: [UInt8] = gray.map { $0 < UInt8(threshold) ? 1 : 0 }
        diag("二值化阈值=\(threshold)(Otsu)")

        // 4. 每行最长水平黑行程 → 候选线带 → 六线谱系统。
        let maxRun = TabVisionAlgorithms.rowMaxRuns(bin, width: W, height: H)
        let bands = TabVisionAlgorithms.extractLineBands(maxRunPerRow: maxRun, imageWidth: Double(W))
        let systems = TabVisionAlgorithms.fitStringSystems(bands: bands, imageHeight: Double(H))
        diag("线带=\(bands.map { String(format: "%.0f(t%.0f,s%.0f)", $0.center, $0.thickness, $0.strength) })")
        diag("系统=\(systems.count) 个: " + systems.map { s in
            String(format: "[y=%@ d=%.1f inlier=%.2f cv=%.2f]",
                   s.lineYs.map { String(format: "%.0f", $0) }.joined(separator: ","),
                   s.spacing, s.inlierRatio, s.spacingCV)
        }.joined(separator: " "))

        guard !systems.isEmpty else {
            diag("未找到六线谱系统,返回空 score")
            return CVResult(score: TabScore(measures: []), confidence: 0)
        }

        // 5. 擦弦线(垂直行程判据:只擦纯线像素,保留压线的数字笔画)。
        let cleaned = TabVisionAlgorithms.eraseStringLines(bin, width: W, height: H, systems: systems)

        // 6. 连通域定位数字块 + 形状分类。
        let digits = TabVisionAlgorithms.detectDigitBoxes(cleaned, width: W, height: H, systems: systems)
        diag("数字 \(digits.count) 个: \(digits.map { "(\($0.digit)@x\($0.cx),y\($0.cy))" })")

        // 7. 组装 + 置信度。
        let score = TabVisionAlgorithms.assembleScore(systems: systems, digits: digits,
                                                      imageWidth: Double(W))
        let confidence = TabVisionAlgorithms.confidence(systems: systems, digits: digits)
        diag("组装完成: \(score.measures.count) 个小节, 置信度=\(String(format: "%.2f", confidence))")

        // 8. 和弦识别:AI 优先;未配置/失败时用本地 Vision OCR 兜底
        //    (读谱面上方条带里的和弦名,分词后用 ChordLibrary 校验)。
        var finalScore = score
        if finalScore.measures.isEmpty {
            diag("CV 无小节,跳过和弦识别(交由上层回退)")
        } else {
            var chords: [String] = []
            if let chordConfig {
                chords = (try? await recognizeChords(image: image, config: chordConfig)) ?? []
            }
            if chords.isEmpty {
                chords = recognizeChordsLocally(image: normalized, systems: systems)
                if !chords.isEmpty { diag("和弦走本地 OCR") }
            }
            if !chords.isEmpty {
                // 按比例把和弦名分配到各小节(chords 数与 measures 数不一定相等)。
                let count = finalScore.measures.count
                for i in finalScore.measures.indices {
                    let idx = min(Int(Double(i) * Double(chords.count) / Double(count)),
                                  max(0, chords.count - 1))
                    finalScore.measures[i].chords = [chords[idx]]
                }
            }
            diag("和弦识别: \(chords)")
        }
        return CVResult(score: finalScore, confidence: confidence)
    }

    // MARK: - 归一化

    /// 重绘为 upright(应用 EXIF orientation)并等比降采样到最长边 ≤ maxDimension。
    /// 输出 scale=1、orientation=.up,后续所有像素处理不再关心方向。
    static func uprightAndScaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let newSize = CGSize(width: floor(image.size.width * scale),
                             height: floor(image.size.height * scale))
        guard newSize.width > 10, newSize.height > 10 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - 预处理

    private func preprocess(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        // 灰度 + 高对比。不用 CICannyEdgeDetector(会把谱面变全黑,破坏投影)。
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

    // MARK: - 本地和弦 OCR(Vision)

    /// 用 Vision OCR 读各系统上方条带里的和弦名,按阅读顺序返回。
    /// 条带 = 上一系统底线(首系统取图顶)到本系统顶线上方;双尺度(1x/3x)
    /// 并集提高小字召回;分词后仅保留能被 ChordLibrary 解析的和弦 token。
    func recognizeChordsLocally(image: UIImage, systems: [TVStringSystem]) -> [String] {
        guard !systems.isEmpty, let cg = image.cgImage else { return [] }
        var results: [String] = []
        for (si, system) in systems.enumerated() {
            let d = system.spacing
            guard let top = system.lineYs.first else { continue }
            let prevBottom = si == 0 ? 0.0 : (systems[si - 1].lineYs.last ?? 0)
            let bandTop = max(0, Int(prevBottom + 0.1 * d))
            let bandBottom = min(cg.height - 1, Int(top - 0.15 * d))
            guard bandBottom - bandTop > 8 else { continue }
            let rect = CGRect(x: 0, y: bandTop, width: cg.width, height: bandBottom - bandTop)
            guard let crop = cg.cropping(to: rect) else { continue }

            // 双尺度 OCR(1x 原始 + 3x 放大)。
            var texts: [String] = []
            for scale in [1, 3] {
                let sw = crop.width * scale, sh = crop.height * scale
                var buf = [UInt8](repeating: 255, count: sw * sh)
                guard let ctx = CGContext(data: &buf, width: sw, height: sh,
                                          bitsPerComponent: 8, bytesPerRow: sw,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { continue }
                ctx.interpolationQuality = .none
                ctx.draw(crop, in: CGRect(x: 0, y: 0, width: sw, height: sh))
                guard let scaledImg = ctx.makeImage() else { continue }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: scaledImg, options: [:])
                try? handler.perform([request])
                texts += (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            }
            results += Self.extractChordTokens(from: texts)
        }
        // 去掉相邻重复(双尺度会重复识别同一行)。
        var deduped: [String] = []
        for c in results where c != deduped.last { deduped.append(c) }
        return deduped
    }

    /// 从 OCR 文本行提取和弦 token:按非和弦字符切分,ChordLibrary 能解析的保留。
    static func extractChordTokens(from lines: [String]) -> [String] {
        var tokens: [String] = []
        for line in lines {
            var current = ""
            func flush() {
                let t = current
                current = ""
                guard !t.isEmpty, let first = t.first else { return }
                // 能被和弦库解析(表内或音程可解)才算和弦;过滤标题/歌词噪声。
                guard ChordLibrary.find(t) != nil else { return }
                // 规范显示:首字母大写。
                tokens.append(first.uppercased() + t.dropFirst())
            }
            for ch in line {
                if ch.isLetter || ch.isNumber || ch == "#" || ch == "b" || ch == "♯" || ch == "♭" {
                    current.append(ch)
                } else {
                    flush()
                }
            }
            flush()
        }
        return tokens
    }

    // MARK: - 和弦识别(走 AI,可选)

    private func recognizeChords(image: UIImage, config: ChordAIConfig) async throws -> [String] {
        guard let dataURI = ImageEncoder.jpegDataURI(image) else { return [] }
        let service = AIChatService()
        let prompt = """
        List ONLY the chord names written above the staff in this guitar TAB image, left to right, one per measure.
        Output a JSON array of strings, e.g. ["C","Am","F","G"]. No other text.
        """
        let raw = try await service.recognizeTab(endpoint: config.endpoint, apiKey: config.apiKey,
                                                  model: config.model, imageDataURI: dataURI, prompt: prompt)
        if let data = raw.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }
        return []
    }
}
