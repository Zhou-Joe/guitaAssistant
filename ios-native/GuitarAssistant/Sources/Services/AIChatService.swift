import Foundation

/// OpenAI 兼容的 Chat Completions 客户端。
/// 对应 Flutter 版 `AIConfig` 的预期用途（`/v1/chat/completions`，gpt-4-vision），
/// Flutter 版只存了配置但从未真正调用，此处补全实现。
///
/// 用法：传入 AIConfigModel（从 SwiftData 取）+ Keychain 中的 apiKey。
struct AIChatService {
    struct Message: Encodable {
        let role: String
        let content: Content

        enum Content {
            case text(String)
            case multimodal(text: String, imageURL: String)
        }

        enum CodingKeys: String, CodingKey { case role, content }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(role, forKey: .role)
            switch content {
            case .text(let s):
                try c.encode(s, forKey: .content)
            case .multimodal(let text, let imageURL):
                struct Part: Codable { let type: String; let text: String?; let image_url: ImageURL? }
                struct ImageURL: Codable { let url: String }
                try c.encode([
                    Part(type: "text", text: text, image_url: nil),
                    Part(type: "image_url", text: nil, image_url: ImageURL(url: imageURL))
                ], forKey: .content)
            }
        }
    }

    struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let max_tokens: Int?
    }

    struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                /// 常规模型的最终答案。
                let content: String?
                /// 推理模型（如 DeepSeek-R1、Nex-N2-Pro）的思考过程；
                /// 部分模型最终 content 为空，答案需从 reasoning_content 提取。
                let reasoning_content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    /// 发送一次对话请求，返回回复文本。
    func send(endpoint: String, apiKey: String, model: String,
              messages: [Message], maxTokens: Int = 1024) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(model: model, messages: messages, max_tokens: maxTokens)
        request.httpBody = try JSONEncoder().encode(body)
        // 推理模型（如 Nex-N2-Pro）思考较慢，给足超时。
        request.timeoutInterval = 300   // 5 分钟

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            // 带状态码和响应体的详细错误，便于诊断。
            let bodyText = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            throw NSError(domain: "AIChatService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey:
                            "HTTP \(http.statusCode): \(bodyText)"])
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let msg = decoded.choices.first?.message
        // 优先 content；为空时 fallback 到 reasoning_content（推理模型）。
        let content = msg?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !content.isEmpty {
            return content
        }
        // reasoning fallback：尝试从中提取 JSON 答案。
        if let reasoning = msg?.reasoning_content,
           let extracted = extractJSON(from: reasoning) {
            return extracted
        }
        return msg?.reasoning_content ?? ""
    }

    /// 从推理模型的思考文本中提取最后的 JSON 对象（答案通常在思考末尾）。
    private func extractJSON(from text: String) -> String? {
        // 找最后一个 {...} 块。
        guard let lastBrace = text.lastIndex(of: "}") else { return nil }
        // 从这个 } 往前找匹配的 {。
        var depth = 0
        var startIdx: String.Index?
        var idx = lastBrace
        while idx >= text.startIndex {
            let ch = text[idx]
            if ch == "}" { depth += 1 }
            else if ch == "{" {
                depth -= 1
                if depth == 0 { startIdx = idx; break }
            }
            if idx == text.startIndex { break }
            idx = text.index(before: idx)
        }
        guard let start = startIdx else { return nil }
        return String(text[start...lastBrace])
    }

    /// 曲谱识别便捷方法：发送图片 + 识别 prompt，返回 AI 的原始回复文本。
    /// - Parameters:
    ///   - endpoint: API 端点。
    ///   - apiKey: API Key。
    ///   - model: 模型名。
    ///   - imageDataURI: 图片的 base64 data URI（`data:image/jpeg;base64,...`）。
    ///   - prompt: 识别指令文本。
    func recognizeTab(endpoint: String, apiKey: String, model: String,
                      imageDataURI: String, prompt: String) async throws -> String {
        let messages = [
            Message(role: "system", content: .text(
                "You are a guitar tablature recognition assistant. Respond ONLY with valid JSON, no markdown fences, no explanation."
            )),
            Message(role: "user", content: .multimodal(text: prompt, imageURL: imageDataURI))
        ]
        return try await send(endpoint: endpoint, apiKey: apiKey, model: model,
                              messages: messages, maxTokens: 4096)
    }
}
