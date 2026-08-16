import SwiftUI

/// 设置主界面。对应 Flutter `settings_screen.dart`。
struct SettingsView: View {
    @State private var languageManager = LanguageManager.shared
    @State private var showLanguageHint = false
    // deep link 绑定（来自 MainTabView，用于验证二级页面）。
    @Binding var deepLink: DeepLink?

    /// 从 Bundle 动态读取版本号（不再硬编码）。
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section(NSLocalizedString("recording_analysis", comment: "")) {
                NavigationLink {
                    RecordingView()
                } label: {
                    Label(NSLocalizedString("recording", comment: ""), systemImage: "waveform.circle")
                }
                .accessibilityIdentifier("recordingEntry")
            }
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.surfaceElevated)

            Section(NSLocalizedString("ai_features", comment: "")) {
                NavigationLink {
                    AIConfigView()
                } label: {
                    Label(NSLocalizedString("ai_config", comment: ""), systemImage: "cpu")
                }
            }
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.surfaceElevated)

            Section {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Button {
                        if languageManager.current != lang {
                            languageManager.current = lang
                            showLanguageHint = true
                        }
                    } label: {
                        HStack {
                            Text(lang.displayName).foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            if languageManager.current == lang {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.cta)
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("language", comment: ""))
            } footer: {
                Text(NSLocalizedString("language_hint", comment: ""))
                    .font(.caption2)
            }
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.surfaceElevated)

            Section(NSLocalizedString("about", comment: "")) {
                Label {
                    Text(String(format: NSLocalizedString("version_format", comment: ""),
                                AppConstants.appName, appVersion))
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.surfaceElevated)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("settings", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .alert(NSLocalizedString("language_hint_title", comment: ""),
               isPresented: $showLanguageHint) {
            Button(NSLocalizedString("ok", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("language_hint", comment: ""))
        }
        // deep link 驱动二级页面导航（用于验证）。
        .navigationDestination(item: $deepLink) { link in
            switch link {
            case .recording: RecordingView()
            case .aiConfig: AIConfigView()
            }
        }
    }
}
