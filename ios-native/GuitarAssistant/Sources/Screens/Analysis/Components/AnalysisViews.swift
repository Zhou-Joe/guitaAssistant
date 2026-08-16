import SwiftUI

/// 波形视图。对应 Flutter `waveform_view.dart`，但用真实 RMS 包络数据。
struct WaveformView: View {
    let waveform: [Double]

    var body: some View {
        Group {
            if waveform.isEmpty {
                emptyOverlay
            } else {
                canvas
            }
        }
        .frame(height: 160)
        .padding()
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyOverlay: some View {
        Text(NSLocalizedString("no_data", comment: ""))
            .foregroundStyle(AppColors.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canvas: some View {
        Canvas { ctx, size in
            let mid = size.height / 2
            let step = size.width / CGFloat(waveform.count)
            // 中心线
            var center = Path()
            center.move(to: CGPoint(x: 0, y: mid))
            center.addLine(to: CGPoint(x: size.width, y: mid))
            ctx.stroke(center, with: .color(AppColors.surfaceElevated), lineWidth: 1)

            for (i, amp) in waveform.enumerated() {
                let x = CGFloat(i) * step + step / 2
                let h = CGFloat(amp) * mid * 0.85
                let color = amp > 0.7 ? AppColors.cta : AppColors.secondary
                var bar = Path()
                bar.move(to: CGPoint(x: x, y: mid - h))
                bar.addLine(to: CGPoint(x: x, y: mid + h))
                ctx.stroke(bar, with: .color(color), lineWidth: max(1, step * 0.6))
            }
        }
    }
}

/// 时间轴视图。对应 Flutter `timeline_view.dart`：
/// 期望节拍 vs 实际节拍对比。
struct TimelineView: View {
    let expected: [Double]
    let actual: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { ctx, size in
                guard let maxT = (expected + actual).max(), maxT > 0 else { return }
                // 期望（靛蓝）
                drawRow(ctx: ctx, size: size, times: expected, maxT: maxT,
                        y: size.height * 0.3, color: AppColors.secondary)
                // 实际（绿）
                drawRow(ctx: ctx, size: size, times: actual, maxT: maxT,
                        y: size.height * 0.7, color: AppColors.cta)
            }
            .frame(height: 120)

            HStack(spacing: 16) {
                legend(color: AppColors.cta, text: NSLocalizedString("legend_actual", comment: ""))
                legend(color: AppColors.secondary, text: NSLocalizedString("legend_expected", comment: ""))
            }
            .font(.caption)
        }
        .padding()
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func drawRow(ctx: GraphicsContext, size: CGSize, times: [Double],
                         maxT: Double, y: CGFloat, color: Color) {
        var line = Path()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        ctx.stroke(line, with: .color(AppColors.surfaceElevated), lineWidth: 1)
        for t in times {
            let x = CGFloat(t / maxT) * size.width
            let rect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).foregroundStyle(AppColors.textSecondary)
        }
    }
}

/// 热力图视图。对应 Flutter `heatmap_view.dart`：
/// 每拍精度条形 + 聚合统计。
struct HeatmapView: View {
    let perBeat: [(offset: Double, accuracy: BeatAccuracy)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("heatmap_title", comment: ""))
                .font(.caption).foregroundStyle(AppColors.textSecondary)

            if perBeat.isEmpty {
                Text(NSLocalizedString("no_data", comment: ""))
                    .foregroundStyle(AppColors.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                Canvas { ctx, size in
                    let count = perBeat.count
                    let spacing: CGFloat = 4
                    let barW = (size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
                    for (i, beat) in perBeat.enumerated() {
                        let x = CGFloat(i) * (barW + spacing)
                        let (h, color) = style(for: beat)
                        let rect = CGRect(x: x, y: size.height - h,
                                          width: barW, height: h)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                    }
                }
                .frame(height: 120)
            }
        }
        .padding()
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func style(for beat: (offset: Double, accuracy: BeatAccuracy)) -> (height: CGFloat, color: Color) {
        let baseH: CGFloat = 90
        switch beat.accuracy {
        case .onBeat: return (baseH, AppColors.cta)
        case .close: return (baseH * 0.6, AppColors.warning)
        case .off: return (baseH * 0.3, AppColors.error)
        }
    }
}
