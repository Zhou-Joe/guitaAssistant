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
                self?.tracker.reset()
            }
        }
    }
    /// 是否准音。
    private(set) var isInTune = false
    /// 错误信息。
    private(set) var errorMessage: String?

    // MARK: - 依赖

    private let processingQueue = DispatchQueue(label: "com.guitarassistant.pitch",
                                                 qos: .userInteractive)
    /// mini-pYIN 跟踪器(仅在 processingQueue 上访问)。
    private var tracker = PitchTracker()
    /// 重叠帧滑窗:tank 2048,分析窗口 4096 → 帧率翻倍(~21.5fps)。
    private var frameHistory = [Float]()
    private var frameWindowSize = 0
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
            frameHistory.removeAll()
            processingQueue.async { [weak self] in
                self?.tracker.reset()
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
        frameHistory.removeAll()
        processingQueue.async { [weak self] in
            self?.tracker.reset()
        }
    }

    // MARK: - 处理

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        guard !samples.isEmpty else { return }

        // 重叠帧滑窗:tank 2048、分析窗口 4096(重叠 50%)→ 帧率 ~21.5fps,
        // 所有响应延迟减半。
        if frameWindowSize == 0 { frameWindowSize = samples.count * 2 }
        frameHistory.append(contentsOf: samples)
        let drop = frameHistory.count - frameWindowSize
        if drop > 0 { frameHistory.removeFirst(drop) }
        guard frameHistory.count >= frameWindowSize else { return }

        // RMS 能量门限:带内尾音保留,静音底噪丢弃。
        let energy = vDSP.dot(frameHistory, frameHistory)
        let rms = (energy / Float(frameHistory.count)).squareRoot()
        guard rms.isFinite, rms > rmsGate else { return }

        // 按实际采样率构造检测器（缓存，避免每帧重建）。
        let useSampleRate = sampleRate > 0 ? sampleRate : AppConstants.sampleRate
        if runtimeDetector == nil || runtimeDetector?.sampleRate != useSampleRate {
            runtimeDetector = PitchDetector(sampleRate: useSampleRate)
        }
        guard let detector = runtimeDetector else { return }

        let target = self.selectedStringIndex
        let window = frameHistory
        processingQueue.async { [weak self] in
            guard let self else { return }
            // mini-pYIN:多候选 → 跟踪器打分 → 平滑可信的频率。
            let candidates = detector.detectCandidates(samples: window)
            let tracked = self.tracker.update(candidates: candidates)
            guard let smoothed = tracked.frequency else { return }

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
                // 跟踪器自带"粘性"(转移代价),音名/弦直接从跟踪频率导出。
                let semitones = 12.0 * log2(smoothed / 440.0)
                let noteIdx = Int(semitones.rounded())
                displayNote = PitchDetector.noteName(forSemitoneIndex: noteIdx)
                displayCents = max(-50, min(50, (semitones - Double(noteIdx)) * 100.0))
                nearest = detector.nearestStringIndex(for: smoothed)
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
