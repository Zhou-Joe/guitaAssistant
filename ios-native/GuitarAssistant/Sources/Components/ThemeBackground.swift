import SwiftUI

/// 应用根背景:夜间为纯色;日间为暖色渐变 + 柔和可爱图案
/// (吉他拨片、四角星、圆点,马卡龙色、极低对比,不干扰内容阅读)。
struct ThemeBackground: View {
    var body: some View {
        ZStack {
            if ThemeManager.shared.resolvedIsDark {
                AppColors.background
            } else {
                LinearGradient(
                    colors: [Color(hex: 0xFFF9F0), Color(hex: 0xFFF3E4), Color(hex: 0xFFEFE0)],
                    startPoint: .top, endPoint: .bottom)
                CutePattern()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 日间可爱图案

/// 网格 + 抖动排布的柔和图案(确定性伪随机,重建不闪烁)。
private struct CutePattern: View {
    /// 马卡龙色板(粉/薄荷/淡紫/奶油黄/蜜桃)。
    private let palette: [Color] = [
        Color(hex: 0xFFD7E0), Color(hex: 0xD5EFE0), Color(hex: 0xE4DDF6),
        Color(hex: 0xFFEFC7), Color(hex: 0xFFE0CD)
    ]

    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 92
            let rows = Int(size.height / step) + 2
            let cols = Int(size.width / step) + 2
            var idx = 0
            for row in 0..<rows {
                for col in 0..<cols {
                    let (jx, jy) = jitter(idx)
                    let x = CGFloat(col) * step + (row % 2 == 0 ? 0 : step / 2) + jx
                    let y = CGFloat(row) * step + jy
                    let color = palette[(idx * 7 + row * 3) % palette.count].opacity(0.5)
                    let s: CGFloat = 7 + CGFloat(idx % 5) * 2   // 7-15pt
                    switch idx % 3 {
                    case 0: drawPick(ctx: ctx, center: CGPoint(x: x, y: y), size: s, color: color)
                    case 1: drawSparkle(ctx: ctx, center: CGPoint(x: x, y: y), size: s, color: color)
                    default:
                        ctx.fill(Path(ellipseIn: CGRect(x: x - s / 3, y: y - s / 3,
                                                        width: s / 1.5, height: s / 1.5)),
                                 with: .color(color))
                    }
                    idx += 1
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 确定性伪随机抖动(-14...14)。
    private func jitter(_ i: Int) -> (CGFloat, CGFloat) {
        let a = sin(Double(i) * 12.9898) * 43758.5453
        let b = sin(Double(i) * 78.233) * 12345.6789
        let fx = a.truncatingRemainder(dividingBy: 1)
        let fb = b.truncatingRemainder(dividingBy: 1)
        return ((fx * 28 - 14), (fb * 28 - 14))
    }

    /// 吉他拨片:圆角三角。
    private func drawPick(ctx: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let w = size, h = size * 1.18
        var p = Path()
        p.move(to: CGPoint(x: center.x, y: center.y - h / 2))                    // 顶尖
        p.addCurve(to: CGPoint(x: center.x + w / 2, y: center.y + h * 0.12),     // 右肩
                   control1: CGPoint(x: center.x + w * 0.42, y: center.y - h * 0.22),
                   control2: CGPoint(x: center.x + w / 2, y: center.y - h * 0.05))
        p.addArc(center: CGPoint(x: center.x, y: center.y + h * 0.12),
                 radius: w / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addCurve(to: CGPoint(x: center.x, y: center.y - h / 2),                // 回顶
                   control1: CGPoint(x: center.x - w / 2, y: center.y - h * 0.05),
                   control2: CGPoint(x: center.x - w * 0.42, y: center.y - h * 0.22))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    /// 四角星(闪亮)。
    private func drawSparkle(ctx: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let s = size
        var p = Path()
        p.move(to: CGPoint(x: center.x, y: center.y - s))
        p.addQuadCurve(to: CGPoint(x: center.x + s, y: center.y),
                       control: CGPoint(x: center.x + s * 0.18, y: center.y - s * 0.18))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + s),
                       control: CGPoint(x: center.x + s * 0.18, y: center.y + s * 0.18))
        p.addQuadCurve(to: CGPoint(x: center.x - s, y: center.y),
                       control: CGPoint(x: center.x - s * 0.18, y: center.y + s * 0.18))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - s),
                       control: CGPoint(x: center.x - s * 0.18, y: center.y - s * 0.18))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }
}
