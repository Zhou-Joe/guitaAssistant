import Foundation
import SwiftData

/// 识别方法。
enum RecognitionMethod: String, Codable {
    case ai        // 纯云端 AI 整体识别（一期）
    case cv        // 纯本地 CV 流水线（二期）
    case hybrid    // 和弦走 AI + 六线谱走 CV（二期融合，默认）
}

/// 曲谱识别结果模型。关联原 `TabModel`（一对多：一张曲谱可多次识别）。
/// 设计为独立表，不改原 TabModel 结构，避免迁移风险，且支持多种识别结果并存。
@Model
final class RecognizedTabModel {
    @Attribute(.unique) var id: String
    /// 关联的原曲谱 id（TabModel.id）。
    var tabId: String
    /// TabScore 编码后的 JSON 字符串。
    var scoreJSON: String
    /// 识别方法。
    var methodRaw: String
    /// 识别置信度（0-1，AI 给出或 CV 综合估算）。
    var confidence: Double
    /// 原图叠加标注后的图片路径（可选）。
    var annotatedImagePath: String?
    var createdAt: Date

    var method: RecognitionMethod {
        get { RecognitionMethod(rawValue: methodRaw) ?? .ai }
        set { methodRaw = newValue.rawValue }
    }

    init(id: String = UUID().uuidString, tabId: String, scoreJSON: String,
         method: RecognitionMethod, confidence: Double = 0,
         annotatedImagePath: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.tabId = tabId
        self.scoreJSON = scoreJSON
        self.methodRaw = method.rawValue
        self.confidence = confidence
        self.annotatedImagePath = annotatedImagePath
        self.createdAt = createdAt
    }
}
