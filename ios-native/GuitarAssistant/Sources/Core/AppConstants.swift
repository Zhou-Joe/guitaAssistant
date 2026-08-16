import Foundation

/// 应用全局常量。迁移自 Flutter 版 `lib/config/constants.dart`。
public enum AppConstants {
    /// 应用显示名称。
    public static let appName = "Guitar Assistant"

    // MARK: - 调音 (Tuner)

    /// 准音判定容差（cents）。绝对值小于等于该值视为"准"。
    public static let defaultTunerTolerance: Double = 5.0

    /// 标准吉他调弦频率（Hz）。
    /// 索引 0 = 第 6 弦（低音 E2），索引 5 = 第 1 弦（高音 E4）。
    public static let guitarStringFrequencies: [Double] = [
        82.41,   // String 6: E2 (Low E)
        110.00,  // String 5: A2
        146.83,  // String 4: D3
        196.00,  // String 3: G3
        246.94,  // String 2: B3
        329.63,  // String 1: E4 (High E)
    ]

    /// 标准吉他弦音名（含八度）。
    public static let guitarStringNotes: [String] = ["E2", "A2", "D3", "G3", "B3", "E4"]

    /// 标准吉他弦音名（不含八度，用于简单显示）。
    public static let guitarStringNoteLetters: [String] = ["E", "A", "D", "G", "B", "E"]

    /// 弦显示名（1–6，吉他上的标注顺序）。
    public static let guitarStringNames: [String] = ["6", "5", "4", "3", "2", "1"]

    /// 十二平均律音名。
    public static let noteNames: [String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - 节拍器 (Metronome)

    public static let minBPM: Int = 30
    public static let maxBPM: Int = 250
    public static let defaultBPM: Int = 120
    public static let defaultTimeSignature: String = "4/4"

    /// 可选拍号。
    public static let timeSignatures: [String] = ["2/4", "3/4", "4/4", "5/4", "6/8", "7/8", "9/8", "12/8"]

    // MARK: - 音频 / DSP

    /// 默认采样率。
    public static let sampleRate: Double = 44100.0

    /// 调音音高检测使用的缓冲区大小。
    /// Flutter 版为 1024，过低导致低音 E2(≈82Hz, 单周期≈535 采样点) 检测失败。
    /// 此处提升至 4096，确保低音弦至少包含约 7 个完整周期，YIN 可靠检测。
    public static let tunerBufferSize: Int = 4096

    /// YIN 阈值。
    public static let yinThreshold: Double = 0.15

    /// 吉他音域下限（Hz），低音 E2 以下。
    public static let guitarMinFrequency: Double = 70.0
    /// 吉他音域上限（Hz），高音 E4 以上留余量。
    public static let guitarMaxFrequency: Double = 400.0

    // MARK: - 沙盒目录名

    public static let tabsFolder = "tabs"
    public static let recordingsAudioFolder = "recordings/audio"
    public static let recordingsVideoFolder = "recordings/video"
    public static let analysisFolder = "analysis"
}
