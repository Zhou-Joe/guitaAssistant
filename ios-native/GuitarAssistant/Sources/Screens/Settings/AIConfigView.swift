import SwiftUI
import SwiftData

/// AI 配置界面。对应 Flutter `ai_config_screen.dart`。
/// 改进：API Key 存 Keychain（Flutter 版明文存 Hive）。
struct AIConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AIConfigModel> { $0.id == "default" })
    private var configs: [AIConfigModel]

    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var isEnabled = false
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess = false
    @State private var showSavedToast = false

    private var config: AIConfigModel? { configs.first }

    /// 表单是否可保存（URL 合法 + 模型非空）。
    private var canSave: Bool {
        !endpoint.isEmpty && URL(string: endpoint)?.scheme?.hasPrefix("http") == true
            && !modelName.isEmpty
    }

    var body: some View {
        Form {
            Section(NSLocalizedString("ai_endpoint", comment: "")) {
                TextField("https://api.example.com/v1/chat/completions",
                          text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            Section(NSLocalizedString("ai_key", comment: "")) {
                SecureField(NSLocalizedString("ai_key_placeholder", comment: ""), text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section(NSLocalizedString("ai_model", comment: "")) {
                TextField("gpt-4-vision-preview", text: $modelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                Toggle(NSLocalizedString("ai_enable", comment: ""), isOn: $isEnabled)
            }
            // 测试连接
            Section {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if isTesting { ProgressView().controlSize(.small) }
                        Text(NSLocalizedString("ai_test_connection", comment: ""))
                    }
                }
                .disabled(isTesting || !canSave)
                if let testResult {
                    Label(testResult, systemImage: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(testSuccess ? AppColors.cta : AppColors.error)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(NSLocalizedString("ai_features", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("save", comment: "")) { save() }
                    .disabled(!canSave)
            }
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                Text(NSLocalizedString("saved", comment: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(AppColors.cta, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { load() }
    }

    // MARK: - 测试连接

    private func testConnection() async {
        guard canSave else {
            testResult = NSLocalizedString("invalid_url", comment: "")
            testSuccess = false
            return
        }
        isTesting = true
        testResult = nil
        let service = AIChatService()
        let messages = [AIChatService.Message(role: "user",
                                              content: .text("ping"))]
        do {
            _ = try await service.send(endpoint: endpoint, apiKey: apiKey,
                                        model: modelName, messages: messages, maxTokens: 8)
            await MainActor.run {
                testSuccess = true
                testResult = NSLocalizedString("ai_test_success", comment: "")
                isTesting = false
            }
        } catch {
            await MainActor.run {
                testSuccess = false
                testResult = NSLocalizedString("ai_test_failed", comment: "")
                isTesting = false
            }
        }
    }

    private func load() {
        if let config {
            endpoint = config.apiEndpoint
            modelName = config.modelName
            isEnabled = config.isEnabled
            apiKey = KeychainStore.load(account: config.keychainAccount) ?? ""
        }
    }

    private func save() {
        guard canSave else { return }
        let config = config ?? AIConfigModel()
        config.apiEndpoint = endpoint
        config.modelName = modelName
        config.isEnabled = isEnabled
        if config.modelContext == nil {
            modelContext.insert(config)
        }
        // API Key 存 Keychain。
        if apiKey.isEmpty {
            KeychainStore.delete(account: config.keychainAccount)
        } else {
            KeychainStore.save(account: config.keychainAccount, value: apiKey)
        }
        do {
            try modelContext.save()
            showToast()
        } catch {
            // 保存失败保留静默（ErrorState 在本表单上下文未注入）。
        }
    }

    private func showToast() {
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }
}
