import Foundation
import AVFoundation
import SwiftUI
import Accelerate

/// 调音器视图模型（@Observable，替代 Flutter 的 `TunerProvider`）。
///
/// 职责：管理 AVAudioEngine 麦克风采集 → 后台线程 PitchDetector + FrequencySmoother →
/// 主线程更新 UI 状态。所有 DSP 计算在 `userInteractive` 后台队列执行，避免阻塞 UI。
@Observable
final class TunerViewModel {

    // MARK: - 对外状态（UI 绑定）

    /// 是否正在监听。
    private(set) var isListening = false
    /// 当前检测到的频率（Hz）。
    private(set) var currentFrequency: Double = 0
    /// 当前音名。
    private(set) var detectedNote: String = "—"
    /// 当前音分偏差（自动模式 clamp 到 ±50）。
    private(set) var cents: Double = 0
    /// 最近弦索引（-1 表示无）。
    private(set) var nearestStringIndex: Int = -1
    /// 手动选定的弦索引（nil = 自动模式）。
    var selectedStringIndex: Int? {
        didSet {
            // 切换目标弦清空平滑历史与滞回状态——派发到 processingQueue 避免与后台 process() 竞态。
            processingQueue.async { [weak self] in
                self?.smoother.reset()
                self?.stickyNote.reset()
                self?.stickyString.reset()
            }
        }
    }
    /// 是否准音。
    private(set) var isInTune = false
    /// 错误信息。
    private(set) var errorMessage: String?

    // MARK: - 依赖

    private let smoother = FrequencySmoother()
    private let processingQueue = DispatchQueue(label: "com.guitarassistant.pitch",
                                                 qos: .userInteractive)
    // 自动模式滞回状态(仅在 processingQueue 上访问)。
    // 确认 2 帧(≈0.2s):滤单帧毛刺,又不拖慢响应。
    private var stickyNote = StickySelector(confirmFrames: 2)
    private var stickyString = StickySelector(confirmFrames: 2)
    /// RMS 门限(线性幅值,约 -45dBFS):低于此值的帧视为瞬态/衰减噪声,丢弃。
    // 真机麦克风收吉他声压偏低,门限过严会连正常尾音都丢(表现为响应慢)。
    private let rmsGate: Float = pow(10, -50.0 / 20)

    // MARK: - 音频引擎

    private let audioEngine = AVAudioEngine()
    private var isEngineStarted = false
    /// 运行时检测器（按实际采样率创建/缓存）。
    private var runtimeDetector: PitchDetector?

    init() {
        // 中断（来电/拔耳机）时停止监听，避免引擎处于不一致状态。
        AudioSessionCoordinator.shared.onInterruption = { [weak self] began in
            if began, self?.isListening == true {
                self?.stopListening()
            }
        }
    }

    deinit {
        // 兜底释放：确保离开时引擎停止、tap 移除，避免持续占用麦克风。
        if isEngineStarted {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    // MARK: - 监听控制

    func startListening() {
        guard !isListening else { return }

        // 请求权限（iOS 首次会弹窗）。
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async {
                if granted {
                    self.beginCapture()
                } else {
                    self.errorMessage = NSLocalizedString("mic_permission_denied", comment: "")
                }
            }
        }
    }

    private func beginCapture() {
        // 通过协调器配置会话（record 用途），避免被其它模块的 playback 配置覆盖。
        AudioSessionCoordinator.shared.activate(for: .record)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let actualSampleRate = recordingFormat.sampleRate
        // 防御：采样率非法时提示，避免 PitchDetector(sampleRate:0) 除零。
        guard actualSampleRate > 0 else {
            errorMessage = NSLocalizedString("mic_unavailable", comment: "")
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: UInt32(AppConstants.tunerBufferSize),
                             format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.process(buffer: buffer, sampleRate: actualSampleRate)
        }

        do {
            try audioEngine.start()
            isEngineStarted = true
            isListening = true
            errorMessage = nil
            processingQueue.async { [weak self] in
                self?.smoother.reset()
                self?.stickyNote.reset()
                self?.stickyString.reset()
            }
        } catch {
            // 启动失败时移除已安装的 tap，保持状态干净。
            inputNode.removeTap(onBus: 0)
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        if isEngineStarted {
            audioEngine.stop()
            isEngineStarted = false
        }
        isListening = false
        currentFrequency = 0
        detectedNote = "—"
        cents = 0
        isInTune = false
        nearestStringIndex = -1
        processingQueue.async { [weak self] in
            self?.smoother.reset()
            self?.stickyNote.reset()
            self?.stickyString.reset()
        }
    }

    // MARK: - 处理

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        // 拷贝到独立数组（buffer 会被复用）。
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        guard samples.count >= AppConstants.tunerBufferSize else { return }

        // RMS 能量门限：拨弦瞬态与尾音衰减期的低能量帧会输出幽灵频率，直接丢弃
        // （保持上次显示，避免读数/音名跳变）。
        let energy = vDSP.dot(samples, samples)
        let rms = (energy / Float(samples.count)).squareRoot()
        guard rms.isFinite, rms > rmsGate else { return }

        // 按实际采样率构造检测器（缓存，避免每帧重建）。
        let useSampleRate = sampleRate > 0 ? sampleRate : AppConstants.sampleRate
        if runtimeDetector == nil || runtimeDetector?.sampleRate != useSampleRate {
            runtimeDetector = PitchDetector(sampleRate: useSampleRate)
        }
        guard let detector = runtimeDetector else { return }

        let target = self.selectedStringIndex
        processingQueue.async { [weak self] in
            guard let self else { return }
            let result = detector.detect(samples: samples, targetStringIndex: target)
            guard let freq = result.frequency else {
                // 未检测到，保持上次显示（不强制清零，避免读数闪烁）。
                return
            }
            guard let smoothed = self.smoother.process(freq) else { return }

            // 重新计算展示值（用平滑后频率）。
            let displayCents: Double
            let displayNote: String
            let displayInTune: Bool
            let nearest: Int

            if let target {
                let targetFreq = AppConstants.guitarStringFrequencies[target]
                displayCents = 1200.0 * log2(smoothed / targetFreq)
                displayNote = AppConstants.guitarStringNotes[target]
                nearest = target
            } else {
                // 自动模式:音名/弦选择走滞回,消除边界抖动导致的频繁跳变。
                // - 音名:当前音 ±60 音分内保持;新音需连续 3 帧一致才切换。
                // - 弦高亮:当前弦 ±120 音分内保持;新弦需连续 3 帧一致才切换。
                let semitones = 12.0 * log2(smoothed / 440.0)
                let rawNote = Int(semitones.rounded())
                let noteHold = self.stickyNote.stable >= 0
                    && abs((semitones - Double(self.stickyNote.stable)) * 100.0) <= 60
                let noteIdx = self.stickyNote.update(rawNote, hold: noteHold)
                let displayIdx = noteIdx >= 0 ? noteIdx : rawNote
                displayNote = PitchDetector.noteName(forSemitoneIndex: displayIdx)
                displayCents = max(-50, min(50, (semitones - Double(displayIdx)) * 100.0))

                let rawString = detector.nearestStringIndex(for: smoothed)
                let stringHold = self.stickyString.stable >= 0
                    && abs(1200.0 * log2(smoothed / AppConstants.guitarStringFrequencies[self.stickyString.stable])) <= 120
                let stringIdx = self.stickyString.update(rawString, hold: stringHold)
                nearest = stringIdx >= 0 ? stringIdx : rawString
            }
            displayInTune = abs(displayCents) <= AppConstants.defaultTunerTolerance

            DispatchQueue.main.async {
                self.currentFrequency = smoothed
                self.detectedNote = displayNote
                self.cents = displayCents
                self.nearestStringIndex = nearest
                self.isInTune = displayInTune
            }
        }
    }
}
