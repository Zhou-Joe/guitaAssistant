import SwiftUI

/// 调音顶部叠加层:大字音名 + 频率 + 弦标签(叠在琴头面上部)。
struct TunerDisplay: View {
    let frequency: Double
    let detectedNote: String
    let nearestStringIndex: Int
    let selectedStringNote: String?
    let isInTune: Bool
    let isListening: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(displayNote)
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundStyle(noteColor)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

            if frequency > 0 {
                Text(String(format: "%.1f Hz", frequency))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            // 选中模式:显示目标音名;自动模式:显示检测到的弦号。
            if let selectedStringNote {
                Text(String(format: NSLocalizedString("target_format", comment: ""), selectedStringNote))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.35), in: Capsule())
            } else if isListening, (0..<AppConstants.guitarStringFrequencies.count).contains(nearestStringIndex) {
                Text(String(format: NSLocalizedString("string_n", comment: ""),
                            AppConstants.guitarStringNames[nearestStringIndex]))
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var displayNote: String {
        selectedStringNote ?? detectedNote
    }

    /// 音名压在琴头木面上(任何主题下木面都是深色),固定浅色保证对比。
    private var noteColor: Color {
        guard isListening else { return .white.opacity(0.72) }
        return isInTune ? AppColors.cta : .white
    }
}

/// 细偏差指示条(叠在琴颈上方):底槽 + 中央准音刻度 + 辉光指针。
struct TunerMeterBar: View {
    let cents: Double

    var body: some View {
        let clamped = max(-50, min(50, cents))
        let offset = (clamped / 50.0) * 120   // ±120pt 满量程
        // 自带主题底色的卡片:不依赖底下是木纹还是页面背景,两主题都可读。
        VStack(spacing: 2) {
            ZStack {
                Capsule()
                    .fill(AppColors.surfaceElevated.opacity(0.9))
                    .frame(width: 300, height: 40)
                // 中央"准"标记。
                Capsule()
                    .fill(AppColors.cta.opacity(0.9))
                    .frame(width: 3, height: 28)
                // 指针。
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: indicatorColor.opacity(0.5), radius: 6)
                    .offset(x: offset)
                // 两端提示与刻度(压在胶囊两端上方)。
                HStack {
                    Text("♭").font(.caption).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("-50").font(.caption2).foregroundStyle(AppColors.textSecondary)
                    Text("0").font(.caption2).foregroundStyle(AppColors.cta)
                    Text("+50").font(.caption2).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("♯").font(.caption).foregroundStyle(AppColors.textSecondary)
                }
                .frame(width: 320)
                .offset(y: 24)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .background(AppColors.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
        .animation(.easeOut(duration: 0.1), value: cents)
    }

    private var indicatorColor: Color {
        let a = abs(cents)
        if a <= AppConstants.defaultTunerTolerance { return AppColors.cta }
        if a <= 15 { return AppColors.warning }
        return AppColors.error
    }
}
