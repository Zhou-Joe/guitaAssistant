import SwiftUI

/// 主底部导航（4 个 Tab：调音器/节拍器/收藏/设置）。
/// 节拍器在其它 Tab 上以悬浮窗形式常驻（Flutter 版 MinimizedMetronome 行为）。
struct MainTabView: View {
    // 支持 launch argument 指定初始 tab，便于验证（如 -initialTab metronome）。
    /// 主题管理(body 内读取 mode 以建立观察依赖)。
    private let theme = ThemeManager.shared
    /// 系统深浅色(system 主题模式下联动重建)。
    @Environment(\.colorScheme) private var systemScheme
    @State private var selectedTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-initialTab"), idx + 1 < args.count {
            let v = args[idx + 1]
            switch v {
            case "metronome": return 1
            case "favorites": return 2
            case "settings": return 3
            default: return 0
            }
        }
        return 0
    }()

    // deep link 目标（用于验证二级页面：guitarassistant://recording 等）。
    @State var deepLink: DeepLink?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TunerView()
                    .background(ThemeBackground())
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(NSLocalizedString("tuner", comment: ""), systemImage: "tuningfork")
            }
            .tag(0)

            NavigationStack {
                MetronomeView()
                    .background(ThemeBackground())
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(NSLocalizedString("metronome", comment: ""), systemImage: "metronome")
            }
            .tag(1)

            NavigationStack {
                FavoritesView()
                    .background(ThemeBackground())
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(NSLocalizedString("favorites", comment: ""), systemImage: "star")
            }
            .tag(2)

            NavigationStack {
                SettingsView(deepLink: $deepLink)
                    .background(ThemeBackground())
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(NSLocalizedString("settings", comment: ""), systemImage: "gearshape")
            }
            .tag(3)
        }
        // 录音/分析作为收藏页的入口或独立导航；此处暂以节拍器悬浮窗为例保留联动。
        .overlay(alignment: .bottomTrailing) {
            // 悬浮节拍器仅在收藏页显示(曲谱播放需要);调音/节拍器/设置页不打扰。
            if selectedTab == 2 {
                MinimizedMetronome()
                    .padding(.trailing, 16)
                    .padding(.bottom, 88)
            }
        }
        // 根背景:夜间纯色;日间暖色渐变 + 可爱图案。
        .background(ThemeBackground())
        // 系统 UI(导航/Tab 栏、键盘等)跟随应用内主题(system 模式传 nil);
        // .id 含系统深浅色:主题切换或系统外观变化时整树重建,即时换肤。
        .id("\(theme.mode.rawValue)-\(systemScheme)")
        .preferredColorScheme(theme.preferredScheme)
        .onOpenURL { url in
            // guitarassistant://recording / guitarassistant://aiConfig
            deepLink = DeepLink(rawValue: url.host ?? "")
            // 二级页面都在设置 tab 下，切过去。
            if deepLink != nil { selectedTab = 3 }
        }
    }
}

/// 二级页面 deep link 目标。
enum DeepLink: String, Identifiable {
    case recording
    case aiConfig
    var id: String { rawValue }
}
