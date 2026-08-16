import SwiftUI

/// 调音显示区：大字音名 + 频率 + 水平偏差指示条 + 状态文案。
/// 对应 Flutter 版 `lib/screens/tuner/widgets/tuner_display.dart`。
struct TunerDisplay: View {
    let frequency: Double
    let detectedNote: String
    let cents: Double
    let nearestStringIndex: Int
    let selectedStringNote: String?
    let isInTune: Bool
    let isListening: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            noteDisplay
            deviationIndicator
            statusText
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 音名

    private var noteDisplay: some View {
        VStack(spacing: 6) {
            Text(displayNote)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(noteColor)
                .contentTransition(.numericText())

            if frequency > 0 {
                Text(String(format: "%.1f Hz", frequency))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textMuted)
            }

            // 选中模式：显示目标音名；自动模式：显示检测到的弦号。
            if let selectedStringNote {
                Text(String(format: NSLocalizedString("target_format", comment: ""), selectedStringNote))
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColors.surfaceElevated, in: Capsule())
            } else if isListening, nearestStringIndex >= 0, nearestStringIndex < AppConstants.guitarStringFrequencies.count {
                Text(String(format: NSLocalizedString("string_n", comment: ""),
                            AppConstants.guitarStringNames[nearestStringIndex]))
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColors.surfaceElevated, in: Capsule())
            }
        }
    }

    private var displayNote: String {
        selectedStringNote ?? detectedNote
    }

    private var noteColor: Color {
        guard isListening else { return AppColors.textSecondary }
        return isInTune ? AppColors.cta : AppColors.textPrimary
    }

    // MARK: - 偏差指示条

    private var deviationIndicator: some View {
        let clamped = max(-50, min(50, cents))
        let offset = (clamped / 50.0) * 110   // ±110pt 满量程
        return ZStack {
            // 底槽
            RoundedRectangle(cornerRadius: 28)
                .fill(AppColors.surface)
                .frame(width: 280, height: 56)
            // 中央"准"标记
            Capsule().fill(AppColors.cta.opacity(0.9)).frame(width: 3, height: 40)
            // 指针
            Circle()
                .fill(indicatorColor)
                .frame(width: 18, height: 18)
                .shadow(color: indicatorColor.opacity(0.5), radius: 6)
                .offset(x: offset)
            // 左右箭头与刻度
            HStack {
                Image(systemName: "arrowtriangle.down.fill")
                    .foregroundStyle(AppColors.textMuted).font(.caption2)
                Spacer()
                Text("-50").font(.caption2).foregroundStyle(AppColors.textMuted)
                Text("0").font(.caption2).foregroundStyle(AppColors.cta)
                Text("+50").font(.caption2).foregroundStyle(AppColors.textMuted)
                Spacer()
                Image(systemName: "arrowtriangle.down.fill")
                    .foregroundStyle(AppColors.textMuted).font(.caption2)
            }
            .frame(width: 300)
            .offset(y: 38)
        }
        .frame(height: 80)
        .animation(.easeOut(duration: 0.1), value: cents)
    }

    private var indicatorColor: Color {
        let a = abs(cents)
        if a <= AppConstants.defaultTunerTolerance { return AppColors.cta }
        if a <= 15 { return AppColors.warning }
        return AppColors.error
    }

    // MARK: - 状态文案

    @ViewBuilder private var statusText: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(statusColor)
    }

    private var message: String {
        if let errorMessage { return errorMessage }
        if !isListening { return NSLocalizedString("tap_start_to_begin", comment: "") }
        if isInTune { return NSLocalizedString("in_tune", comment: "") }
        if cents < -15 { return NSLocalizedString("too_flat_tighten", comment: "") }
        if cents > 15 { return NSLocalizedString("too_sharp_loosen", comment: "") }
        return NSLocalizedString("almost_there", comment: "")
    }

    private var statusColor: Color {
        if isInTune && isListening { return AppColors.cta }
        if !isListening { return AppColors.textMuted }
        return AppColors.textSecondary
    }
}
