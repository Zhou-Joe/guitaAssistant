import SwiftUI
import SwiftData

@main
struct GuitarAssistantApp: App {
    // 全局共享的节拍器引擎（悬浮窗与主页面共用同一实例）。
    @State private var metronome = MetronomeEngine()
    // 全局错误提示通道。
    @State private var errorState = ErrorState()

    // SwiftData 容器：在启动时创建，确保 Application Support 目录存在，
    // 避免 CoreData "Failed to stat path" 运行时错误。
    let modelContainer: ModelContainer

    init() {
        Self.ensureApplicationSupportExists()
        do {
            modelContainer = try ModelContainer(
                for: TabModel.self, FolderModel.self, RecordingModel.self,
                AIConfigModel.self, RecognizedTabModel.self)
        } catch {
            // 容器创建失败时退化为内存存储，避免启动崩溃。
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(
                for: TabModel.self, FolderModel.self, RecordingModel.self,
                AIConfigModel.self, RecognizedTabModel.self,
                configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(AppColors.cta)
                .environment(metronome)
                .environment(errorState)
                .modelContainer(modelContainer)
                .errorAlert(errorState)   // 直接传入，避免在 modifier 内 @Environment
                .task {
                    // 修复卸载重装后失效的文件路径。
                    DataSeeder.fixStalePaths(modelContext: modelContainer.mainContext)
                    // 首次启动播种示例曲谱 + AI 配置。
                    DataSeeder.seedSampleTabIfNeeded(modelContext: modelContainer.mainContext)
                    DataSeeder.seedAIConfigIfNeeded(modelContext: modelContainer.mainContext)
                }
        }
    }

    /// 确保 Application Support 目录存在（SwiftData 默认 store 所在）。
    private static func ensureApplicationSupportExists() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
    }
}

/// 所有 SwiftData 模型类型，用于 modelContainer 注册。
enum SwiftDataModel {
    static var allTypes: [any PersistentModel.Type] {
        [TabModel.self, FolderModel.self, RecordingModel.self,
         AIConfigModel.self, RecognizedTabModel.self]
    }
}
