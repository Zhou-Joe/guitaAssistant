import SwiftUI

/// 和弦指法图：用 Canvas 绘制 6 弦 × 5 品网格 + 按弦黑点 + 闷音/空弦标记。
struct ChordDiagramView: View {
    let chord: ChordShape
    var size: CGFloat = 120

    var body: some View {
        Canvas { ctx, canvasSize in
            drawChord(ctx: ctx, canvasSize: canvasSize)
        }
        .frame(width: size, height: size * 1.2)
        // VoiceOver 可访问性：把 Canvas 内容描述成文字。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    /// 和弦的文字描述（供 VoiceOver）。
    private var accessibilityDescription: String {
        let fretDesc = chord.frets.enumerated().map { idx, fret -> String in
            let stringName = ["低E", "A", "D", "G", "B", "高E"][idx]
            switch fret {
            case nil: return "\(stringName)不弹"
            case -1: return "\(stringName)闷音"
            default: return "\(stringName)第\(fret!)品"
            }
        }.joined(separator: "，")
        return "和弦 \(chord.name)，从第\(chord.baseFret)把位，\(fretDesc)"
    }

    private func drawChord(ctx: GraphicsContext, canvasSize: CGSize) {
        let frets = chord.frets
        let baseFret = chord.baseFret
        let displayFrets = 5   // 显示 5 个品格

        // 布局参数。
        let margin: CGFloat = 14
        let gridW = canvasSize.width - margin * 2
        let gridH = canvasSize.height - margin * 2 - 8   // 顶部留空给弦名/把位
        let stringGap = gridW / CGFloat(frets.count - 1)
        let fretGap = gridH / CGFloat(displayFrets)

        let gridX = margin
        let gridY = margin + 8

        // 把位标注（若非第1把位，左上角显示数字）。
        if baseFret > 1 {
            let text = Text("\(baseFret)fr").font(.caption2).foregroundStyle(AppColors.textSecondary)
            ctx.draw(text, at: CGPoint(x: gridX - 8, y: gridY + fretGap / 2))
        }

        // 6 根竖线（弦）。
        for i in 0..<frets.count {
            let x = gridX + CGFloat(i) * stringGap
            var path = Path()
            path.move(to: CGPoint(x: x, y: gridY))
            path.addLine(to: CGPoint(x: x, y: gridY + gridH))
            // 顶弦（低音E）和底弦（高音E）稍粗。
            ctx.stroke(path, with: .color(AppColors.textSecondary),
                       lineWidth: i == 0 || i == frets.count - 1 ? 1.5 : 1)
        }

        // 横线（品格）。最顶部一条加粗（琴枕）。
        for f in 0...displayFrets {
            let y = gridY + CGFloat(f) * fretGap
            var path = Path()
            path.move(to: CGPoint(x: gridX, y: y))
            path.addLine(to: CGPoint(x: gridX + gridW, y: y))
            ctx.stroke(path, with: .color(AppColors.textSecondary),
                       lineWidth: f == 0 ? 2.5 : 1)
        }

        // 每根弦的按弦标记。
        for (i, fret) in frets.enumerated() {
            let x = gridX + CGFloat(i) * stringGap
            // 顶部标记：闷音 x / 空弦 o。
            if fret == -1 {
                let text = Text("×").font(.caption2).foregroundStyle(AppColors.textMuted)
                ctx.draw(text, at: CGPoint(x: x, y: gridY - 6))
            } else if fret == 0 {
                let circle = Path(ellipseIn: CGRect(x: x - 4, y: gridY - 10, width: 8, height: 8))
                ctx.stroke(circle, with: .color(AppColors.textSecondary), lineWidth: 1)
            }
            // 按弦黑点。
            if let f = fret, f > 0 {
                let displayFret = f - baseFret + 1
                if displayFret >= 1 && displayFret <= displayFrets {
                    let y = gridY + (CGFloat(displayFret) - 0.5) * fretGap
                    let dot = Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
                    ctx.fill(dot, with: .color(AppColors.cta))
                }
            }
        }
    }
}

/// 和弦速查卡：点击和弦名弹出指法图。
struct ChordCardView: View {
    let chordName: String
    @State private var shape: ChordShape?

    var body: some View {
        VStack(spacing: 10) {
            if let shape {
                ChordDiagramView(chord: shape, size: 134)
                Text(chordName).font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            } else {
                // 内置库未收录的和弦：显示名称 + 提示。
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 48)).foregroundStyle(AppColors.textMuted)
                Text(chordName).font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(NSLocalizedString("chord_not_found", comment: ""))
                    .font(.caption2).foregroundStyle(AppColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            shape = ChordLibrary.find(chordName)
        }
    }
}
