import SwiftUI

/// 主题模式:夜间(原深色)/ 日间(奶油暖色可爱风)。
enum AppThemeMode: String, CaseIterable {
    case dark
    case light

    var displayName: String {
        switch self {
        case .dark: return NSLocalizedString("theme_dark", comment: "")
        case .light: return NSLocalizedString("theme_light", comment: "")
        }
    }
}

/// 应用配色。迁移自 Flutter 版 `lib/config/theme.dart` 的 `AppColors`。
/// 双主题:所有颜色为计算属性,按启动时读取的主题模式解析(切换后重启生效)。
enum AppColors {
    private static let themeKey = "appTheme"
    /// 当前主题(启动时读取,默认夜间)。
    static var mode: AppThemeMode {
        AppThemeMode(rawValue: UserDefaults.standard.string(forKey: themeKey) ?? "") ?? .dark
    }

    /// 切换主题(持久化;重启后生效)。
    static func setMode(_ newMode: AppThemeMode) {
        UserDefaults.standard.set(newMode.rawValue, forKey: themeKey)
    }

    // MARK: - 语义色(夜间 / 日间)

    static var primary: Color { mode == .dark
        ? Color(hex: 0x1E1B4B)      // Indigo 950
        : Color(hex: 0x8B7EC8) }    // 柔雾紫
    static var secondary: Color { mode == .dark
        ? Color(hex: 0x4338CA)      // Indigo 700
        : Color(hex: 0xA797E3) }    // 淡藤紫
    static var cta: Color { mode == .dark
        ? Color(hex: 0x22C55E)      // Green 500
        : Color(hex: 0x58C273) }    // 嫩芽绿
    static var error: Color { mode == .dark
        ? Color(hex: 0xEF4444)      // Red 500
        : Color(hex: 0xFF8A80) }    // 珊瑚粉
    static var warning: Color { mode == .dark
        ? Color(hex: 0xF59E0B)      // Amber 500
        : Color(hex: 0xF2A65A) }    // 杏子橙

    static var background: Color { mode == .dark
        ? Color(hex: 0x0F0F23)      // 深海军蓝
        : Color(hex: 0xFFF6EC) }    // 奶油米白
    static var surface: Color { mode == .dark
        ? Color(hex: 0x1A1A2E)      // 卡片、面板
        : Color(hex: 0xFFFFFF) }    // 纯白卡片(暖底上浮起)
    static var surfaceElevated: Color { mode == .dark
        ? Color(hex: 0x252542)
        : Color(hex: 0xFFEFD9) }    // 蜜桃奶油

    static var textPrimary: Color { mode == .dark
        ? Color(hex: 0xF8FAFC)
        : Color(hex: 0x53463C) }    // 可可棕
    static var textSecondary: Color { mode == .dark
        ? Color(hex: 0x94A3B8)
        : Color(hex: 0x9B8B7D) }    // 暖灰棕
    static var textMuted: Color { mode == .dark
        ? Color(hex: 0x64748B)
        : Color(hex: 0xBFB0A3) }    // 燕麦灰

    // MARK: - 功能卡片强调色

    static var accentTuner: Color { mode == .dark
        ? Color(hex: 0x22C55E) : Color(hex: 0x58C273) }        // 嫩芽绿
    static var accentMetronome: Color { mode == .dark
        ? Color(hex: 0x4338CA) : Color(hex: 0x8B7EC8) }        // 柔雾紫
    static var accentFavorites: Color { mode == .dark
        ? Color(hex: 0xF59E0B) : Color(hex: 0xF2B04F) }        // 蜂蜜黄
    static var accentRecording: Color { mode == .dark
        ? Color(hex: 0xEF4444) : Color(hex: 0xFF8A80) }        // 珊瑚粉
    static var accentAnalysis: Color { mode == .dark
        ? Color(hex: 0x8B5CF6) : Color(hex: 0xB79CE8) }        // 香芋紫
    static var accentSettings: Color { mode == .dark
        ? Color(hex: 0x64748B) : Color(hex: 0xC0B6AC) }        // 亚麻灰
}

extension Color {
    /// 用 0xRRGGBB 整数创建 Color（忽略 alpha，不透明）。
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

/// 应用主题修饰符，统一组件外观。
enum AppTheme {
    /// 卡片圆角。
    static let cardCornerRadius: CGFloat = 16
    /// 弹窗圆角。
    static let dialogCornerRadius: CGFloat = 20
    /// 按钮圆角。
    static let buttonCornerRadius: CGFloat = 28
}
