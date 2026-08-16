import SwiftUI

/// 应用配色。迁移自 Flutter 版 `lib/config/theme.dart` 的 `AppColors`。
/// 全暗色方案。
enum AppColors {
    static let primary = Color(hex: 0x1E1B4B)        // Indigo 950 - 标题、强调
    static let secondary = Color(hex: 0x4338CA)      // Indigo 700 - 次级元素
    static let cta = Color(hex: 0x22C55E)            // Green 500 - 播放/成功
    static let error = Color(hex: 0xEF4444)          // Red 500 - 停止/错误
    static let warning = Color(hex: 0xF59E0B)        // Amber 500 - 接近/警告
    static let background = Color(hex: 0x0F0F23)     // 深海军蓝背景
    static let surface = Color(hex: 0x1A1A2E)        // 卡片、面板
    static let surfaceElevated = Color(hex: 0x252542) // 弹窗、对话框
    static let textPrimary = Color(hex: 0xF8FAFC)    // 主文字 (Slate 50)
    static let textSecondary = Color(hex: 0x94A3B8)  // 次文字 (Slate 400)
    static let textMuted = Color(hex: 0x64748B)      // 标签 (Slate 500)

    // 功能卡片强调色
    static let accentTuner = Color(hex: 0x22C55E)      // 绿 - 调音/成功
    static let accentMetronome = Color(hex: 0x4338CA)  // 靛蓝 - 节奏
    static let accentFavorites = Color(hex: 0xF59E0B)  // 琥珀 - 收藏
    static let accentRecording = Color(hex: 0xEF4444)  // 红 - 录制指示
    static let accentAnalysis = Color(hex: 0x8B5CF6)   // 紫 - 分析
    static let accentSettings = Color(hex: 0x64748B)   // 灰 - 中性
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
