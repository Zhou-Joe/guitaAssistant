import Foundation
import SwiftData

// MARK: - 曲谱

/// 曲谱文件类型。
enum TabFileType: String, Codable {
    case pdf, image
}

/// 曲谱模型。迁移自 Flutter `Tab`（Hive typeId:2）。
@Model
final class TabModel {
    @Attribute(.unique) var id: String
    var title: String
    var filePath: String
    var fileTypeRaw: String
    var folderId: String
    var createdAt: Date
    var updatedAt: Date

    var fileType: TabFileType {
        get { TabFileType(rawValue: fileTypeRaw) ?? .pdf }
        set { fileTypeRaw = newValue.rawValue }
    }

    init(id: String = UUID().uuidString, title: String, filePath: String,
         fileType: TabFileType, folderId: String = "default",
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.fileTypeRaw = fileType.rawValue
        self.folderId = folderId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 文件夹

/// 文件夹模型。迁移自 Flutter `Folder`（Hive typeId:0），支持 parentId 层级。
@Model
final class FolderModel {
    @Attribute(.unique) var id: String
    var name: String
    var parentId: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String,
         parentId: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
    }
}

// MARK: - 录音

/// 录制模式。
enum RecordingMode: String, Codable {
    case audio, video
}

/// 录音模型。迁移自 Flutter `Recording`（Hive typeId:4）。
@Model
final class RecordingModel {
    @Attribute(.unique) var id: String
    var title: String
    var filePath: String
    var modeRaw: String
    var durationSeconds: Int
    var createdAt: Date

    var mode: RecordingMode {
        get { RecordingMode(rawValue: modeRaw) ?? .audio }
        set { modeRaw = newValue.rawValue }
    }

    var fileExtension: String { mode == .audio ? "m4a" : "mp4" }

    init(id: String = UUID().uuidString, title: String, filePath: String,
         mode: RecordingMode, durationSeconds: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.modeRaw = mode.rawValue
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }
}

// MARK: - AI 配置

/// AI 配置模型。迁移自 Flutter `AIConfig`（Hive typeId:5）。
@Model
final class AIConfigModel {
    @Attribute(.unique) var id: String
    var apiEndpoint: String
    var modelName: String
    var isEnabled: Bool
    // 注意：API Key 出于安全不存 SwiftData，而是放 Keychain。
    /// API Key 的 Keychain key（不存储明文）。
    var keychainAccount: String

    init(id: String = "default", apiEndpoint: String = "",
         modelName: String = "", isEnabled: Bool = false,
         keychainAccount: String = "aiApiKey") {
        self.id = id
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.isEnabled = isEnabled
        self.keychainAccount = keychainAccount
    }

    var isConfigured: Bool {
        !apiEndpoint.isEmpty && !modelName.isEmpty
    }
}
