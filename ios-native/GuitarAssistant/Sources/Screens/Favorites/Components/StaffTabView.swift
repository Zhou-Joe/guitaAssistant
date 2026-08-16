import SwiftUI

/// 标准六线谱样式视图：用 Canvas 绘制真实的 TAB 谱面。
/// 6 条横线代表 6 根弦，数字标在弦上，竖线分隔小节，顶部标和弦名。
/// 支持自定义每行显示的小节数。
struct StaffTabView: View {
    let score: TabScore
    /// 每行显示的小节数。
    let measuresPerRow: Int

    /// 标准调弦音名（高音 E 到低音 E）。
    private let stringNames = ["e", "B", "G", "D", "A", "E"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, rowMeasures in
                    // rows 是只读计算属性，offset 作 id 不影响正确性。
                    staffRow(rowMeasures)
                }
            }
            .padding()
        }
    }

    /// 把小节按 measuresPerRow 分行。
    private var rows: [[TabMeasure]] {
        guard !score.measures.isEmpty else { return [] }
        var result: [[TabMeasure]] = []
        var current: [TabMeasure] = []
        for (i, m) in score.measures.enumerated() {
            current.append(m)
            if current.count == measuresPerRow || i == score.measures.count - 1 {
                result.append(current)
                current = []
            }
        }
        return result
    }

    /// 渲染一行六线谱。
    private func staffRow(_ measures: [TabMeasure]) -> some View {
        VStack(spacing: 4) {
            // Canvas 绘制六线谱主体。
            Canvas { ctx, size in
                drawStaff(ctx: ctx, size: size, measures: measures)
            }
            .frame(height: CGFloat(measures.count > 0 ? 160 : 100))
        }
    }

    // MARK: - Canvas 绘制

    private func drawStaff(ctx: GraphicsContext, size: CGSize, measures: [TabMeasure]) {
        guard !measures.isEmpty else { return }

        let leftMargin: CGFloat = 24      // 弦名留白
        let rightMargin: CGFloat = 8
        let topMargin: CGFloat = 24       // 和弦名留白
        let lineCount = 6
        let lineGap: CGFloat = 16         // 弦线间距
        let staffHeight = CGFloat(lineCount - 1) * lineGap
        let totalWidth = size.width - leftMargin - rightMargin
        let measureWidth = totalWidth / CGFloat(measures.count)

        let lineColor = Color(white: 0.7)
        let accentColor = AppColors.cta
        let textColor = AppColors.textPrimary
        let chordColor = AppColors.warning

        // 绘制每根弦线（横线），贯穿整行。
        for i in 0..<lineCount {
            let y = topMargin + CGFloat(i) * lineGap
            var path = Path()
            path.move(to: CGPoint(x: leftMargin, y: y))
            path.addLine(to: CGPoint(x: size.width - rightMargin, y: y))
            ctx.stroke(path, with: .color(lineColor), lineWidth: 1)
        }

        // 弦名标签（左侧）。
        for (i, name) in stringNames.enumerated() {
            let y = topMargin + CGFloat(i) * lineGap
            let text = Text(name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.textMuted)
            ctx.draw(text, at: CGPoint(x: leftMargin - 12, y: y))
        }

        // 起始竖线。
        var startBar = Path()
        let startX = leftMargin
        startBar.move(to: CGPoint(x: startX, y: topMargin))
        startBar.addLine(to: CGPoint(x: startX, y: topMargin + staffHeight))
        ctx.stroke(startBar, with: .color(lineColor), lineWidth: 2)

        // 逐小节绘制。
        for (mIdx, measure) in measures.enumerated() {
            let mStartX = leftMargin + CGFloat(mIdx) * measureWidth
            let mEndX = mStartX + measureWidth

            // 和弦名（小节顶部）。
            if !measure.chords.isEmpty {
                let chordText = Text(measure.chords.joined(separator: " "))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(chordColor)
                ctx.draw(chordText, at: CGPoint(x: mStartX + measureWidth / 2, y: topMargin - 12))
            }

            // 小节内的数字。
            // 计算每根弦的音符 x 位置（均匀分布）。
            for stringIdx in 0..<lineCount {
                let notes = stringIdx < measure.strings.count ? measure.strings[stringIdx] : []
                guard !notes.isEmpty else { continue }
                let y = topMargin + CGFloat(stringIdx) * lineGap
                let noteSpacing = (measureWidth - 20) / CGFloat(max(notes.count, 1))
                for (nIdx, note) in notes.enumerated() {
                    let x = mStartX + 12 + CGFloat(nIdx) * noteSpacing
                    let label = note.fret >= 10 ? "\(note.fret)" : "\(note.fret)"
                    let color = note.fret == 0 ? accentColor : textColor
                    // 数字背景（遮住弦线，让数字清晰）。
                    let bgRect = CGRect(x: x - 10, y: y - 8, width: 20, height: 16)
                    ctx.fill(Path(bgRect), with: .color(AppColors.background))
                    let text = Text(label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    ctx.draw(text, at: CGPoint(x: x, y: y))
                }
            }

            // 小节竖线。
            var bar = Path()
            bar.move(to: CGPoint(x: mEndX, y: topMargin))
            bar.addLine(to: CGPoint(x: mEndX, y: topMargin + staffHeight))
            ctx.stroke(bar, with: .color(lineColor), lineWidth: 2)
        }
    }
}
