import Foundation
import AVFoundation
import SwiftUI
import Combine

/// 音频/视频播放控制器。对应 Flutter `RecordingProvider` 的播放逻辑：
/// 单实例、点哪条播哪条；支持进度/seek/完成回调。
///
/// 改进：
/// - 同时支持音频（AVAudioPlayer）和视频（AVPlayer），Flutter 版视频无法回放。
/// - 播放前配置 AVAudioSession（.playback），避免被录音的 .playAndRecord 路由到听筒。
/// - 暴露 errorMessage，不再静默吞掉播放失败。
/// - 陈旧回调防护：切歌时忽略前一曲的延迟完成回调。
@Observable
final class PlaybackController: NSObject {

    private(set) var currentRecordingId: String?
    private(set) var isPlaying = false
    private(set) var position: Double = 0
    private(set) var duration: Double = 0
    private(set) var errorMessage: String?
    /// 当前播放的媒体类型（决定音频/视频渲染）。
    private(set) var currentMode: RecordingMode = .audio
    /// 视频 AVPlayer（供 VideoPlayer 绑定）。
    private(set) var videoPlayer: AVPlayer?

    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    // 时间观察
    private var timer: Timer?
    private var videoEndObserver: NSObjectProtocol?
    // 防陈旧回调：记录当前曲目身份令牌。
    private var token = 0

    func toggle(recording: RecordingModel) {
        if currentRecordingId == recording.id {
            // 同一条：播放/暂停切换。
            if isPlaying { pause() } else { resume() }
        } else {
            // 切到新条目。
            play(recording: recording)
        }
    }

    private func play(recording: RecordingModel) {
        // 清理上一曲（含视频观察者、陈旧回调防护）。
        token += 1
        let myToken = token
        cleanup()

        // 配置会话（.playback 独占扬声器，避免被录音路由影响）。
        AudioSessionCoordinator.shared.activate(for: .playbackOnly)

        let url = URL(fileURLWithPath: recording.filePath)
        currentRecordingId = recording.id
        currentMode = recording.mode
        errorMessage = nil

        if recording.mode == .audio {
            playAudio(url: url, token: myToken)
        } else {
            playVideo(url: url, token: myToken)
        }
    }

    private func playAudio(url: URL, token: Int) {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            audioPlayer = p
            duration = p.duration
            position = 0
            isPlaying = true
            startTimer(token: token)
        } catch {
            errorMessage = NSLocalizedString("playback_failed", comment: "")
        }
    }

    private func playVideo(url: URL, token: Int) {
        let player = AVPlayer(url: url)
        videoPlayer = player
        // 监听播放结束。
        videoEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleFinish(token: token)
        }
        // 取时长。
        if let item = player.currentItem {
            // KVO 取 duration（异步加载）。
            item.observe(\.duration, options: [.new]) { [weak self] observedItem, _ in
                let d = observedItem.duration.seconds
                if d.isFinite, d > 0 {
                    DispatchQueue.main.async { self?.duration = d }
                }
            }
        }
        position = 0
        isPlaying = true
        player.play()
        startTimer(token: token)
    }

    private func resume() {
        if let audioPlayer {
            audioPlayer.play()
        } else {
            videoPlayer?.play()
        }
        isPlaying = true
        startTimer(token: token)
    }

    func pause() {
        audioPlayer?.pause()
        videoPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func seek(to fraction: Double) {
        let clamped = max(0, min(1, fraction))
        if let audioPlayer {
            audioPlayer.currentTime = clamped * audioPlayer.duration
            position = audioPlayer.currentTime
        } else if let videoPlayer {
            let target = clamped * duration
            videoPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
            position = target
        }
    }

    func stop() {
        cleanup()
        currentRecordingId = nil
        isPlaying = false
        position = 0
        duration = 0
    }

    private func cleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
        videoPlayer?.pause()
        videoPlayer = nil
        if let obs = videoEndObserver {
            NotificationCenter.default.removeObserver(obs)
            videoEndObserver = nil
        }
        stopTimer()
    }

    deinit {
        cleanup()
    }

    private func startTimer(token: Int) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard token == self.token else { return }   // 防陈旧
            if let p = self.audioPlayer {
                self.position = p.currentTime
            } else if let vp = self.videoPlayer {
                self.position = vp.currentTime().seconds
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleFinish(token: Int) {
        // 忽略陈旧曲目回调。
        guard token == self.token else { return }
        DispatchQueue.main.async {
            self.isPlaying = false
            self.position = 0
            self.stopTimer()
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return position / duration
    }

    var formattedPosition: String { formatTime(position) }
    var formattedDuration: String { formatTime(duration) }

    private func formatTime(_ t: Double) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - 音频播放委托

extension PlaybackController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        handleFinish(token: token)
    }
}
