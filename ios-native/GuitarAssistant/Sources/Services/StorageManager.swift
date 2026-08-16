import Foundation

/// 文件存储管理。对应 Flutter `StorageService`，但修复了"只存临时路径"的 bug，
/// 统一将资产拷贝进 App Sandbox 的 Documents 子目录。
struct StorageManager {
    static let shared = StorageManager()

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var tabsURL: URL { directory(.tabs) }
    var recordingsAudioURL: URL { directory(.recordingsAudio) }
    var recordingsVideoURL: URL { directory(.recordingsVideo) }
    var analysisURL: URL { directory(.analysis) }

    enum Directory: String {
        case tabs = "tabs"
        case recordingsAudio = "recordings/audio"
        case recordingsVideo = "recordings/video"
        case analysis = "analysis"
    }

    private func directory(_ dir: Directory) -> URL {
        let url = documentsURL.appendingPathComponent(dir.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 将源文件拷贝进指定目录，返回新文件 URL。若已存在同名则附加时间戳。
    @discardableResult
    func copy(into dir: Directory, from sourceURL: URL,
              suggestedName: String? = nil) throws -> URL {
        let destDir = directory(dir)
        let baseName = suggestedName ?? sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var destURL = destDir.appendingPathComponent(ext.isEmpty ? baseName : "\(baseName).\(ext)")
        if FileManager.default.fileExists(atPath: destURL.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            let name = ext.isEmpty ? "\(baseName)_\(stamp)" : "\(baseName)_\(stamp).\(ext)"
            destURL = destDir.appendingPathComponent(name)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
}
