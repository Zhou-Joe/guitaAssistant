import Foundation
import AVFoundation
import SwiftUI

/// 速度模式。
enum TempoMode: String, CaseIterable {
    case manual, gradual, step, interval
}

/// 点击音色。
enum SoundStyle: String, CaseIterable {
    case classic, woodblock, hiihat, cowbell, digital

    /// 普通拍资源名（不含扩展）。
    var normalAsset: String { "click_\(rawValue)" }
    /// 强拍资源名。
    var accentAsset: String { "click_\(rawValue)_accent" }

    var displayName: String {
        switch self {
        case .classic: return NSLocalizedString("sound_classic", comment: "")
        case .woodblock: return NSLocalizedString("sound_woodblock", comment: "")
        case .hiihat: return NSLocalizedString("sound_hihat", comment: "")
        case .cowbell: return NSLocalizedString("sound_cowbell", comment: "")
        case .digital: return NSLocalizedString("sound_digital", comment: "")
        }
    }
}

/// 节拍器引擎（@Observable 全局单例）。
///
/// 改进自 Flutter 版 `MetronomeProvider`：
/// - 用 `DispatchSourceTimer`（wall-clock，高精度）替代 `Timer.periodic`，避免事件循环抖动。
/// - 点击音用预加载的 `AVAudioPlayer`（normal=0.7、accent=1.0），`currentTime=0; play()` 复用。
/// - 还原 4 种速度模式逻辑（manual/gradual/step/interval，每 4 拍触发）。
@Observable
final class MetronomeEngine {

    // MARK: - 状态

    private(set) var bpm: Int = AppConstants.defaultBPM
    private(set) var timeSignature: String = AppConstants.defaultTimeSignature
    private(set) var tempoMode: TempoMode = .manual
    private(set) var soundStyle: SoundStyle = .classic
    private(set) var isPlaying = false
    /// 当前正在响的拍(0 基,拍内位置)。UI 高亮用——与点击音严格同步。
    private(set) var currentBeat = 0
    /// 自开始播放以来累计已响的拍数(跨小节)。按小节推进的 UI(如曲谱小节高亮)用。
    private(set) var playedBeatTotal = 0
    /// 下一拍要播放的拍位(引擎内部推进,UI 不读)。
    private var nextBeat = 0
    private(set) var error: String?
    private(set) var hasBeenStarted = false   // 供悬浮窗判断是否常驻

    /// 总音量（0...1）。normal 拍为该值的 0.7，accent 拍为该值的 1.0。
    var volume: Float = 0.8 {
        didSet { applyVolume() }
    }

    var beatsPerMeasure: Int { parseTimeSignature(timeSignature) }

    // 速度模式内部状态
    var targetGradualBpm: Int = AppConstants.defaultBPM {
        didSet { targetGradualBpm = clampBpm(targetGradualBpm) }
    }
    private var beatsAtCurrentBpm = 0
    private let beatsPerIncrement = 4
    private var intervalLowBpm = 60
    private var intervalHighBpm = 100
    private var isAtHighInterval = true

    // MARK: - 音频

    private var normalPlayer: AVAudioPlayer?
    private var accentPlayer: AVAudioPlayer?
    private var beatTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.guitarassistant.metronome", qos: .userInteractive)

    init() {}

    // MARK: - 控制

    func togglePlay() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    private func start() {
        error = nil
        AudioSessionCoordinator.shared.activate(for: .playback)
        loadSounds()
        // 音色加载失败则不进入播放，避免"无声播放"。
        guard normalPlayer != nil, accentPlayer != nil else {
            error = NSLocalizedString("metronome_load_failed", comment: "")
            return
        }

        beatsAtCurrentBpm = 0
        currentBeat = 0
        playedBeatTotal = 0
        nextBeat = 0
        isPlaying = true
        hasBeenStarted = true

        if tempoMode == .interval {
            intervalHighBpm = bpm
            intervalLowBpm = clampBpm(Int(Double(bpm) / 1.2))
            isAtHighInterval = true
        }
        startBeatTimer(resetBeat: true)
    }

    deinit {
        beatTimer?.cancel()
        beatTimer = nil
    }

    func stop() {
        beatTimer?.cancel()
        beatTimer = nil
        isPlaying = false
        currentBeat = 0
        playedBeatTotal = 0
        nextBeat = 0
        beatsAtCurrentBpm = 0
        normalPlayer?.stop()
        accentPlayer?.stop()
    }

    // MARK: - 设置

    func setBpm(_ value: Int) {
        let newBpm = clampBpm(value)
        bpm = newBpm
        // interval 模式：用户手动调速时更新区间基准，避免被 handleTempoMode 覆盖回旧值。
        if tempoMode == .interval && !isPlaying {
            intervalHighBpm = newBpm
            intervalLowBpm = clampBpm(Int(Double(newBpm) / 1.2))
        }
        if isPlaying { restartBeatTimer() }
    }

    func setTimeSignature(_ sig: String) {
        timeSignature = sig
        currentBeat = 0
        nextBeat = 0
    }

    func setSoundStyle(_ style: SoundStyle) {
        guard style != soundStyle else { return }
        soundStyle = style
        if isPlaying {
            loadSounds()
        }
    }

    func setTempoMode(_ mode: TempoMode) {
        tempoMode = mode
        beatsAtCurrentBpm = 0
        if mode == .interval {
            intervalHighBpm = bpm
            intervalLowBpm = clampBpm(Int(Double(bpm) / 1.2))
            isAtHighInterval = true
        }
    }

    // MARK: - 调度

    private func startBeatTimer(resetBeat: Bool = false) {
        beatTimer?.cancel()
        if resetBeat { nextBeat = 0 }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let msPerBeat = max(1, Int(60000.0 / Double(bpm)))
        timer.schedule(deadline: .now(), repeating: .milliseconds(msPerBeat), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.onTick()
        }
        timer.resume()
        beatTimer = timer
    }

    private func restartBeatTimer() {
        guard isPlaying else { return }
        // 变速时只重建 timer，不重置拍位（避免变速模式丢拍）。
        startBeatTimer(resetBeat: false)
    }

    /// 每次 tick：播放点击 + 更新"正在响的拍" + 处理速度模式。
    /// 音频播放可在任意线程；状态修改（@Observable）统一在主线程，确保 UI 正确刷新。
    ///
    /// 对齐约定：`currentBeat` 始终等于**刚触发点击音的那一拍**（而非提前推进到
    /// 下一拍），保证 UI 高亮与听到的声音同步；下一拍位置由 `nextBeat` 内部维护。
    private func onTick() {
        let played = nextBeat
        playClick(accent: played == 0)
        nextBeat = (nextBeat + 1) % max(1, beatsPerMeasure)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentBeat = played
            self.playedBeatTotal += 1
            self.handleTempoMode()
        }
    }

    private func handleTempoMode() {
        beatsAtCurrentBpm += 1
        switch tempoMode {
        case .manual:
            break
        case .gradual:
            if beatsAtCurrentBpm >= beatsPerIncrement {
                beatsAtCurrentBpm = 0
                if bpm < targetGradualBpm { setBpm(bpm + 1) }
                else if bpm > targetGradualBpm { setBpm(bpm - 1) }
            }
        case .step:
            if beatsAtCurrentBpm >= beatsPerIncrement {
                beatsAtCurrentBpm = 0
                if bpm + 5 <= AppConstants.maxBPM { setBpm(bpm + 5) }
            }
        case .interval:
            if beatsAtCurrentBpm >= beatsPerIncrement {
                beatsAtCurrentBpm = 0
                if isAtHighInterval {
                    setBpm(intervalLowBpm)
                    isAtHighInterval = false
                } else {
                    setBpm(intervalHighBpm)
                    isAtHighInterval = true
                }
            }
        }
    }

    // MARK: - 点击音

    private func playClick(accent: Bool) {
        let player = accent ? accentPlayer : normalPlayer
        player?.currentTime = 0
        player?.play()
    }

    private func loadSounds() {
        normalPlayer = makePlayer(asset: soundStyle.normalAsset)
        accentPlayer = makePlayer(asset: soundStyle.accentAsset)
        applyVolume()
    }

    private func makePlayer(asset name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            error = NSLocalizedString("metronome_load_failed", comment: "")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// 应用总音量：normal 拍 0.7×volume，accent 拍 1.0×volume。
    private func applyVolume() {
        let v = max(0, min(1, volume))
        normalPlayer?.volume = 0.7 * v
        accentPlayer?.volume = v
    }

    // MARK: - 工具

    private func parseTimeSignature(_ sig: String) -> Int {
        let parts = sig.split(separator: "/")
        let numerator = Int(parts.first ?? "4") ?? 4
        let denominator = parts.count > 1 ? (Int(parts[1]) ?? 4) : 4
        // 复合拍号（分母 8）：以附点四分音符为一拍（= 3 个八分音符）。
        // 6/8 = 2 拍, 9/8 = 3 拍, 12/8 = 4 拍。
        if denominator == 8 {
            return max(1, numerator / 3)
        }
        return numerator
    }

    private func clampBpm(_ value: Int) -> Int {
        min(AppConstants.maxBPM, max(AppConstants.minBPM, value))
    }
}
