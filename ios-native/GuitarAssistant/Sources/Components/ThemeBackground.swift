import SwiftUI

/// 应用根背景。
/// 夜间:纯深蓝。
/// 日间:Headspace/Duolingo 式软色晕斑(mesh blob)——不透明奶油底 +
/// 大块粉/薄荷/淡紫/蜜桃光晕 + 稀疏的拨片/星星涂鸦。
/// 注意:必须以不透明底色绘制,不能依赖背后内容透出(否则会被
/// 导航容器的系统白底盖住)。
struct ThemeBackground: View {
    var body: some View {
        Group {
            if ThemeManager.shared.resolvedIsDark {
                AppColors.background
            } else {
                CuteLightBackground()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 日间:软色晕斑 + 涂鸦

private struct CuteLightBackground: View {
    var body: some View {
        ZStack {
            // 不透明奶油底。
            Color(hex: 0xFFF5E6)
            Canvas { ctx, size in
                drawBlobs(ctx: ctx, size: size)
                drawDoodles(ctx: ctx, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 大块柔色晕斑

    private func drawBlobs(ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let maxDim = max(w, h)
        // (中心x比例, 中心y比例, 半径比例, 颜色)
        let blobs: [(CGFloat, CGFloat, CGFloat, Color)] = [
            (0.10, 0.08, 0.55, Color(hex: 0xFFD3DE)),   // 樱花粉(左上)
            (0.95, 0.18, 0.48, Color(hex: 0xCDEBDC)),   // 薄荷(右上)
            (0.88, 0.88, 0.60, Color(hex: 0xDDD4F4)),   // 淡紫(右下)
            (0.08, 0.90, 0.50, Color(hex: 0xFFE9BF)),   // 奶油黄(左下)
            (0.52, 0.50, 0.38, Color(hex: 0xFFDFC9))    // 蜜桃(中央)
        ]
        for (fx, fy, fr, color) in blobs {
            let center = CGPoint(x: w * fx, y: h * fy)
            let radius = maxDim * fr
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [color.opacity(0.65), color.opacity(0)]),
                center: center, startRadius: 0, endRadius: radius))
        }
    }

    // MARK: 稀疏涂鸦(拨片/四角星/圆点)

    private let doodlePalette: [Color] = [
        Color(hex: 0xF7C6D4), Color(hex: 0xBEE3CE), Color(hex: 0xCFC3EC),
        Color(hex: 0xF7DFAD), Color(hex: 0xF6CBAF)
    ]

    private func drawDoodles(ctx: GraphicsContext, size: CGSize) {
        let step: CGFloat = 96
        let rows = Int(size.height / step) + 2
        let cols = Int(size.width / step) + 2
        var idx = 0
        for row in 0..<rows {
            for col in 0..<cols {
                let (jx, jy) = jitter(idx)
                let x = CGFloat(col) * step + (row % 2 == 0 ? 0 : step / 2) + jx
                let y = CGFloat(row) * step + jy
                let color = doodlePalette[(idx * 7 + row * 3) % doodlePalette.count].opacity(0.4)
                let s: CGFloat = 7 + CGFloat(idx % 5) * 2
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
        p.move(to: CGPoint(x: center.x, y: center.y - h / 2))
        p.addCurve(to: CGPoint(x: center.x + w / 2, y: center.y + h * 0.12),
                   control1: CGPoint(x: center.x + w * 0.42, y: center.y - h * 0.22),
                   control2: CGPoint(x: center.x + w / 2, y: center.y - h * 0.05))
        p.addArc(center: CGPoint(x: center.x, y: center.y + h * 0.12),
                 radius: w / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addCurve(to: CGPoint(x: center.x, y: center.y - h / 2),
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
