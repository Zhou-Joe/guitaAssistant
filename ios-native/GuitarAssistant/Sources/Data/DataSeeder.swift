import Foundation
import SwiftData
import UIKit

/// 首次启动播种：自动添加示例曲谱 + AI 配置，方便立即体验识别功能。
enum DataSeeder {
    /// 若曲谱库为空，播种两张示例曲谱。
    @discardableResult
    static func seedSampleTabIfNeeded(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<TabModel>()
        guard let count = try? modelContext.fetchCount(descriptor), count == 0 else {
            return false
        }
        // 两张示例曲谱：C-Am-F-G 进行 + G-Em-C-D 进行。
        let samples: [(resource: String, titleKey: String)] = [
            ("sample_tab", "sample_tab_title"),
            ("sample_tab2", "sample_tab2_title")
        ]
        var seeded = false
        for sample in samples {
            guard let srcURL = Bundle.main.url(forResource: sample.resource, withExtension: "png") else {
                continue
            }
            do {
                let destURL = try StorageManager.shared.copy(into: .tabs, from: srcURL,
                                                              suggestedName: sample.resource)
                let tab = TabModel(title: NSLocalizedString(sample.titleKey, comment: ""),
                                   filePath: destURL.path, fileType: .image)
                modelContext.insert(tab)
                seeded = true
            } catch {
                // 单张失败不阻断其它。
            }
        }
        try? modelContext.save()
        return seeded
    }

    /// 修复失效的文件路径：卸载重装后容器 UUID 变化导致旧路径失效。
    /// 用文件名在当前 Documents 子目录中重新定位。
    static func fixStalePaths(modelContext: ModelContext) {
        let tabs = (try? modelContext.fetch(FetchDescriptor<TabModel>())) ?? []
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        var changed = false
        for tab in tabs {
            guard !tab.filePath.isEmpty, !FileManager.default.fileExists(atPath: tab.filePath) else { continue }
            // 提取文件名，在 Documents 下重新搜索。
            let filename = (tab.filePath as NSString).lastPathComponent
            if let docsDir {
                let newPath = docsDir.appendingPathComponent("tabs/\(filename)")
                if FileManager.default.fileExists(atPath: newPath.path) {
                    tab.filePath = newPath.path
                    changed = true
                }
            }
        }
        if changed { try? modelContext.save() }
    }

    /// 播种 AI 配置（若未配置）。endpoint/model 存 SwiftData，key 存 Keychain。
    /// API Key 出于安全考虑不在源码中播种 —— 请在「设置 → AI 配置」中输入，
    /// key 只写入 Keychain，不进数据库、不进 git。
    @discardableResult
    static func seedAIConfigIfNeeded(modelContext: ModelContext) -> Bool {
        #if DEBUG
        let pred = #Predicate<AIConfigModel> { $0.id == "default" }
        let descriptor = FetchDescriptor<AIConfigModel>(predicate: pred)
        let existing = (try? modelContext.fetch(descriptor))?.first
        if let existing, existing.isConfigured {
            return false   // 已配置，不覆盖
        }
        let config = existing ?? AIConfigModel()
        config.apiEndpoint = "https://api.siliconflow.cn/v1/chat/completions"
        config.modelName = "nex-agi/Nex-N2-Pro"
        config.isEnabled = true
        if config.modelContext == nil { modelContext.insert(config) }
        try? modelContext.save()
        return true
        #else
        return false
        #endif
    }
}
