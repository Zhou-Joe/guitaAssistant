import Foundation
import SwiftUI
import SwiftData

/// 曲谱识别视图模型。驱动识别流程 + 持久化结果到 SwiftData。
@Observable
final class RecognitionViewModel {

    enum Phase: Equatable {
        case idle
        case recognizing(method: RecognitionMethod)
        case done(score: TabScore, method: RecognitionMethod, confidence: Double)
        case error(String)
    }

    private(set) var phase: Phase = .idle
    /// 是否正在识别。
    var isRecognizing: Bool {
        if case .recognizing = phase { return true }
        return false
    }

    /// 外部设置错误状态（如未配置 AI 时调用）。
    func setError(_ message: String) {
        phase = .error(message)
    }

    private let engine = TabRecognitionEngine()

    /// 触发识别。
    /// - Parameters:
    ///   - image: 曲谱原图。
    ///   - method: 识别方法，默认 hybrid。
    ///   - aiConfig: AI 配置（从 SwiftData+Keychain 取）。
    ///   - tabId: 关联的原曲谱 id（用于持久化）。
    ///   - modelContext: SwiftData 上下文（用于存识别结果）。
    @MainActor
    func recognize(image: UIImage, method: RecognitionMethod = .hybrid,
                   aiConfig: TabRecognitionEngine.AIConfig?,
                   tabId: String, modelContext: ModelContext) async {
        phase = .recognizing(method: method)
        do {
            let result = try await engine.recognize(image: image, method: method, aiConfig: aiConfig)
            // 持久化到 SwiftData。
            persist(score: result.score, method: result.method,
                    confidence: result.confidence, tabId: tabId, modelContext: modelContext)
            // 若结果为空，附带诊断信息，便于排查。
            if result.score.measures.isEmpty {
                lastDiagnostics = TABComputerVision.diagnostics
            }
            phase = .done(score: result.score, method: result.method, confidence: result.confidence)
        } catch {
            // 详细错误：显示完整错误描述（含 HTTP 状态码等）。
            let nsError = error as NSError
            var msg = error.localizedDescription
            if nsError.code != 0 { msg += " [code=\(nsError.code)]" }
            phase = .error(msg)
        }
    }

    /// 最近一次诊断信息（CV 识别为空或出错时供 UI 展示）。
    private(set) var lastDiagnostics: String = ""

    /// 从已有的 RecognizedTabModel 恢复状态（进入页面时若已有识别结果）。
    @MainActor
    func restore(from model: RecognizedTabModel) {
        if let score = try? TabScore.fromJSON(model.scoreJSON) {
            phase = .done(score: score, method: model.method, confidence: model.confidence)
        }
    }

    /// 用户编辑后刷新内存状态（让交互视图立即显示新内容）。
    @MainActor
    func refresh(score: TabScore, confidence: Double) {
        let method: RecognitionMethod = if case .done(_, let m, _) = phase { m } else { .ai }
        phase = .done(score: score, method: method, confidence: confidence)
    }

    func reset() { phase = .idle }

    // MARK: - 持久化

    @MainActor
    private func persist(score: TabScore, method: RecognitionMethod,
                         confidence: Double, tabId: String, modelContext: ModelContext) {
        // 先编码（确保成功后再删旧数据，避免编码失败丢原有结果）。
        guard let json = try? score.toJSON() else { return }
        // 覆盖同一曲谱的旧识别结果：优先 update，无则 insert。
        let tabIdValue = tabId
        let pred = #Predicate<RecognizedTabModel> { $0.tabId == tabIdValue }
        let descriptor = FetchDescriptor<RecognizedTabModel>(predicate: pred)
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.scoreJSON = json
            existing.methodRaw = method.rawValue
            existing.confidence = confidence
        } else {
            let model = RecognizedTabModel(tabId: tabId, scoreJSON: json,
                                           method: method, confidence: confidence)
            modelContext.insert(model)
        }
        try? modelContext.save()
    }
}
