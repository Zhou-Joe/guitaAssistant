import SwiftUI

/// 支持的语言。
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

/// 语言管理。改进：用 UserDefaults 持久化（Flutter 版 `LanguageProvider` 不持久化）。
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private let key = "appLanguage"

    /// 当前语言；未设置时跟随系统（nil）。
    var current: AppLanguage? {
        didSet {
            if let current {
                UserDefaults.standard.set(current.rawValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    var resolved: AppLanguage {
        if let current { return current }
        // 跟随系统首选。
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = String(preferred.prefix(2))
        return AppLanguage(rawValue: code) ?? .english
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: key) {
            current = AppLanguage(rawValue: raw)
        }
    }
}
