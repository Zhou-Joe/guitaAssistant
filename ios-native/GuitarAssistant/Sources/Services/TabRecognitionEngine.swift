import Foundation
import UIKit

/// 曲谱识别引擎。编排一期（AI 整体识别）与二期（本地 CV + 混合）链路。
///
/// - `.ai`：图片 base64 → 多模态 AI 一次返回完整 TabScore JSON。
/// - `.cv`：本地 CV 流水线（二期 TABComputerVision）。
/// - `.hybrid`（默认）：和弦走 AI，六线谱数字走 CV（准确率最优）。
final class TabRecognitionEngine {

    /// AI 配置（从 SwiftData + Keychain 取出后传入）。
    struct AIConfig {
        let endpoint: String
        let apiKey: String
        let model: String
    }

    /// 识别结果。
    struct Result {
        let score: TabScore
        let method: RecognitionMethod
        /// 0-1 置信度（AI 估算或 CV 综合）。
        let confidence: Double
    }

    private let aiService = AIChatService()
    /// 二期 CV 流水线（延迟初始化，一期不依赖）。
    private lazy var cv: TABComputerVision = TABComputerVision()

    init() {}

    // MARK: - 公开入口

    /// 识别曲谱图片。
    /// - Parameters:
    ///   - image: 曲谱原图。
    ///   - method: 识别方法，默认 hybrid。
    ///   - aiConfig: AI 配置（ai/hybrid 需要；cv 不需要）。
    func recognize(image: UIImage,
                    method: RecognitionMethod = .hybrid,
                    aiConfig: AIConfig?) async throws -> Result {
        switch method {
        case .ai:
            return try await recognizeWithAI(image: image, config: aiConfig)
        case .cv:
            // 纯 CV（无需 AI）。
            let score = try await cv.recognize(image: image, chordConfig: nil)
            return Result(score: score, method: .cv, confidence: 0.7)
        case .hybrid:
            return try await recognizeHybrid(image: image, aiConfig: aiConfig)
        }
    }

    // MARK: - 一期：AI 整体识别

    /// 用多模态 AI 识别和弦 + 六线谱数字。
    func recognizeWithAI(image: UIImage, config: AIConfig?) async throws -> Result {
        guard let config else { throw RecognitionError.aiNotConfigured }
        guard let dataURI = ImageEncoder.jpegDataURI(image) else {
            throw RecognitionError.imageEncodingFailed
        }
        let prompt = Self.aiPrompt
        let raw = try await aiService.recognizeTab(
            endpoint: config.endpoint, apiKey: config.apiKey,
            model: config.model, imageDataURI: dataURI, prompt: prompt
        )
        let score = try Self.parseTabScore(from: raw)
        return Result(score: score, method: .ai, confidence: 0.8)
    }

    // MARK: - 二期：混合识别

    /// 和弦走 AI，六线谱数字走 CV。
    func recognizeHybrid(image: UIImage, aiConfig: AIConfig?) async throws -> Result {
        // CV 部分：识别六线谱数字。AI 部分：识别和弦名。
        // 把 AIConfig 转成 CV 需要的 ChordAIConfig；nil 时跳过和弦。
        let chordConfig = aiConfig.map {
            TABComputerVision.ChordAIConfig(endpoint: $0.endpoint, apiKey: $0.apiKey, model: $0.model)
        }
        let score = try await cv.recognize(image: image, chordConfig: chordConfig)
        let method: RecognitionMethod = (aiConfig != nil) ? .hybrid : .cv
        let confidence = aiConfig != nil ? 0.85 : 0.7
        return Result(score: score, method: method, confidence: confidence)
    }

    // MARK: - Prompt 设计

    /// AI 识别 prompt（要求严格 JSON 输出，schema 对齐 TabScore）。
    static let aiPrompt = """
    Recognize this guitar tablature (TAB) image. Output ONLY a JSON object matching this schema, no markdown, no explanation:

    {
      "title": string or null,
      "bpm": number or null,
      "measures": [
        {
          "chords": [string],            // chord names above this measure, e.g. ["C","Am"]; empty array if none
          "strings": [                    // exactly 6 rows, index 0 = high E (1st string) ... index 5 = low E (6th string)
            [{"fret": number, "technique": "normal"}],  // fret numbers in time order on this string
            [],
            ...
          ]
        }
      ]
    }

    Rules:
    - "strings" MUST have exactly 6 arrays (one per string, high E to low E).
    - "fret" is 0 (open string) to 24.
    - "technique" is one of: normal, hammerOn, pullOff, slide, bend, harmonic.
    - If a string has no notes in a measure, use an empty array [].
    - Read measures left to right, separated by vertical bar lines.
    - Return ONLY the JSON.
    """

    // MARK: - JSON 容错解析

    /// 从 AI 原始回复中解析 TabScore。
    /// 容错：剥离 markdown 代码块、提取首个 {...} 对象、字段缺失时给默认值。
    static func parseTabScore(from raw: String) throws -> TabScore {
        // 1. 剥离 ```json ... ``` 代码块（若有）。
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            // 去掉首行 ```json，去掉末尾 ```。
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. 若仍非纯 JSON（夹带文字），尝试提取首个 {...} 子串。
        if !cleaned.hasPrefix("{") {
            if let start = cleaned.firstIndex(of: "{"),
               let end = cleaned.lastIndex(of: "}") {
                cleaned = String(cleaned[start...end])
            } else {
                throw RecognitionError.invalidAIResponse
            }
        }

        // 3. 解码。
        do {
            return try TabScore.fromJSON(cleaned)
        } catch {
            // 4. 严格解码失败，尝试宽松解码（补全缺失的 strings 行 / 默认 technique）。
            if let loose = try? looseDecode(cleaned) {
                return loose
            }
            throw RecognitionError.invalidAIResponse
        }
    }

    /// 宽松解码：AI 可能返回 strings 行数不足 6 或缺 technique，这里补全。
    private static func looseDecode(_ json: String) throws -> TabScore {
        guard let data = json.data(using: .utf8),
              var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RecognitionError.invalidAIResponse
        }
        // 补全每个 measure 的 strings 到 6 行。
        if var measures = dict["measures"] as? [[String: Any]] {
            for i in measures.indices {
                if var strings = measures[i]["strings"] as? [[Any]] {
                    while strings.count < 6 { strings.append([]) }
                    if strings.count > 6 { strings = Array(strings.prefix(6)) }
                    measures[i]["strings"] = strings
                } else {
                    measures[i]["strings"] = [[Any]](repeating: [], count: 6)
                }
                if measures[i]["chords"] == nil {
                    measures[i]["chords"] = [String]()
                }
                // 补全每个 FretNote 缺失的 technique 字段（默认 "normal"）。
                if var strings = measures[i]["strings"] as? [[Any]] {
                    for s in strings.indices {
                        if var notes = strings[s] as? [[String: Any]] {
                            for n in notes.indices where notes[n]["technique"] == nil {
                                notes[n]["technique"] = "normal"
                            }
                            strings[s] = notes
                        }
                    }
                    measures[i]["strings"] = strings
                }
            }
            dict["measures"] = measures
        } else {
            dict["measures"] = [[String: Any]]()
        }
        let reencoded = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(TabScore.self, from: reencoded)
    }
}

// MARK: - 错误

enum RecognitionError: LocalizedError {
    case aiNotConfigured
    case imageEncodingFailed
    case invalidAIResponse

    var errorDescription: String? {
        switch self {
        case .aiNotConfigured:
            return NSLocalizedString("ai_not_configured", comment: "")
        case .imageEncodingFailed:
            return NSLocalizedString("image_encode_failed", comment: "")
        case .invalidAIResponse:
            return NSLocalizedString("ai_response_invalid", comment: "")
        }
    }
}
