import Foundation
import AVFoundation

/// 全局 AVAudioSession 协调器。
///
/// 解决跨模块的会话配置冲突：调音器/录音需要输入，节拍器/播放器只需输出。
/// 各模块不再各自调用 `setCategory`，而是通过本协调器声明用途，由协调器统一配置
/// 共享的 `AVAudioSession.sharedInstance()`，避免后启动的模块静默覆盖先前的路由。
///
/// 同时集中处理中断通知（来电/闹钟）与路由变更，保证各模块状态一致。
final class AudioSessionCoordinator {

    static let shared = AudioSessionCoordinator()

    /// 音频用途。决定会话 category。
    enum Purpose {
        case playback         // 节拍器、音频回放
        case playbackOnly     // 仅播放（如播放器，可独占扬声器）
        case record           // 调音器（需输入 + 输出）
        case recordOnly       // 录音（仅输入）
    }

    /// 中断回调：begin 时模块应暂停/停止；ended 时可恢复。
    var onInterruption: ((Bool) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var lastPurpose: Purpose?
    private var wasInterrupted = false

    private init() {
        registerNotifications()
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - 配置

    /// 按用途激活会话。同一用途重复调用是幂等的。
    func activate(for purpose: Purpose) {
        // 若当前会话因中断被停用，ended 时再恢复，这里先记录意图。
        lastPurpose = purpose
        do {
            let session = AVAudioSession.sharedInstance()
            switch purpose {
            case .playback:
                try session.setCategory(.playback, mode: .default,
                                        options: [.mixWithOthers])
            case .playbackOnly:
                try session.setCategory(.playback, mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth])
            case .record:
                // 调音器：输入 + 输出（边听边可播放提示）。
                try session.setCategory(.playAndRecord, mode: .measurement,
                                        options: [.defaultToSpeaker, .allowBluetooth,
                                                  .mixWithOthers])
            case .recordOnly:
                try session.setCategory(.record, mode: .default, options: [])
            }
            try session.setActive(true, options: [])
        } catch {
            // 配置失败不阻断流程，调用方自行处理后续。
            print("[AudioSession] 配置失败: \(error.localizedDescription)")
        }
    }

    /// 停用会话（应在模块完全不再需要音频时调用，如离开页面）。
    /// 注意：其它模块可能仍在使用会话，因此默认不真正停用以避免打断邻居。
    func deactivateIfPossible() {
        // 保留激活状态，避免互相打断；仅在有明确需求时停用。
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - 中断 / 路由变更

    private func registerNotifications() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note: note)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleRouteChange(note: note)
        })
    }

    private func handleInterruption(note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            wasInterrupted = true
            onInterruption?(true)   // 各模块暂停
        case .ended:
            // 中断结束后，若有选项提示应恢复，且记录过最后用途，则重新激活。
            let options = AVAudioSession.InterruptionOptions(
                rawValue: (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0)
            if options.contains(.shouldResume), let purpose = lastPurpose {
                activate(for: purpose)
            }
            wasInterrupted = false
            onInterruption?(false)  // 各模块可恢复
        @unknown default:
            break
        }
    }

    private func handleRouteChange(note: Notification) {
        guard let info = note.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        // 设备拔出（如耳机）：通知中断开始。
        if reason == .oldDeviceUnavailable {
            onInterruption?(true)
        }
        // 新设备插入或路由恢复：通知中断结束（让模块可恢复）。
        if reason == .newDeviceAvailable || reason == .routeConfigurationChange {
            onInterruption?(false)
        }
    }
}
