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
                // 同步写入系统语言偏好——NSLocalizedString 在下次启动时
                // 按 AppleLanguages 解析 Bundle 语言,切换才会真正生效。
                UserDefaults.standard.set([current.rawValue], forKey: "AppleLanguages")
                UserDefaults.standard.set([current.rawValue], forKey: "AppleLocale")
            } else {
                UserDefaults.standard.removeObject(forKey: key)
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                UserDefaults.standard.removeObject(forKey: "AppleLocale")
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
        if let raw = UserDefaults.standard.string(forKey: key),
           let lang = AppLanguage(rawValue: raw) {
            current = lang
            // 兼容旧版本:此前只存了偏好没写入 AppleLanguages,这里补同步,
            // 否则升级后首次重启语言切换仍不生效。
            if UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first != raw {
                UserDefaults.standard.set([raw], forKey: "AppleLanguages")
                UserDefaults.standard.set([raw], forKey: "AppleLocale")
            }
        }
    }
}
