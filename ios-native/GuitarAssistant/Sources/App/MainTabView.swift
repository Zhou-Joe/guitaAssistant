import SwiftUI

/// 主底部导航（4 个 Tab：调音器/节拍器/收藏/设置）。
/// 节拍器在其它 Tab 上以悬浮窗形式常驻（Flutter 版 MinimizedMetronome 行为）。
struct MainTabView: View {
    // 支持 launch argument 指定初始 tab，便于验证（如 -initialTab metronome）。
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
            }
            .tabItem {
                Label(NSLocalizedString("tuner", comment: ""), systemImage: "tuningfork")
            }
            .tag(0)

            NavigationStack {
                MetronomeView()
            }
            .tabItem {
                Label(NSLocalizedString("metronome", comment: ""), systemImage: "metronome")
            }
            .tag(1)

            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label(NSLocalizedString("favorites", comment: ""), systemImage: "star")
            }
            .tag(2)

            NavigationStack {
                SettingsView(deepLink: $deepLink)
            }
            .tabItem {
                Label(NSLocalizedString("settings", comment: ""), systemImage: "gearshape")
            }
            .tag(3)
        }
        // 录音/分析作为收藏页的入口或独立导航；此处暂以节拍器悬浮窗为例保留联动。
        .overlay(alignment: .bottomTrailing) {
            if selectedTab != 1 {
                MinimizedMetronome()
                    .padding(.trailing, 16)
                    .padding(.bottom, 88)
            }
        }
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
