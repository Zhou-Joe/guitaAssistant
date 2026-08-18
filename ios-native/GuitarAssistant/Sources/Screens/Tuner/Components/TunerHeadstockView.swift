import SwiftUI

/// 调音页签名组件:矢量吉他琴头,整页尺寸(390 × 680 设计画布)。
///
/// 设计意图:琴头即页面——琴冠在顶部安全区下展开,六根弦从 3+3 弦钮
/// 汇聚到骨白枕木,琴颈出血延伸到底部边缘。音名/仪表由调用方叠加在
/// 上部琴头面与下部琴颈之上。
///
/// 材质取自制琴语汇:胡桃木渐变琴头面、骨白色枕木、低音缠弦(青铜)与
/// 高音钢弦(银白)按真实粗细渐细。
///
/// 交互(对齐市面主流调音 app):
/// - 点弦钮 → 手动锁定该弦(靛蓝描边);再点 → 回自动模式。
/// - 自动模式检测到弦 → 该弦与弦钮琥珀色脉动高亮。
/// - 准音 → 整根弦 + 弦钮绿色辉光。
struct TunerHeadstockView: View {
    /// 自动模式检测到的弦索引(-1 = 无)。
    let detectedStringIndex: Int
    /// 手动选中的弦索引(nil = 自动模式)。
    let selectedStringIndex: Int?
    let isInTune: Bool
    let isListening: Bool
    /// 点弦钮回调(参数为切换后的选中索引,nil = 回自动)。
    let onSelect: (Int?) -> Void

    /// 高亮脉动相位(仅在"检测中未准音"时影响辉光强度)。
    @State private var glowPhase = false

    // MARK: - 设计坐标系(390 × 680,等比缩放铺满可用区域)

    private let designSize = CGSize(width: 390, height: 680)

    /// 弦钮位置(3+3)。左列自上而下服务 0/1/2 弦,右列自上而下服务 5/4/3 弦
    /// (与真实琴头一致,弦不交叉)。
    private let pegAnchors: [CGPoint] = [
        CGPoint(x: 100, y: 175),   // 弦6 E2 左上
        CGPoint(x: 100, y: 285),   // 弦5 A2 左中
        CGPoint(x: 100, y: 395),   // 弦4 D3 左下
        CGPoint(x: 290, y: 395),   // 弦3 G3 右下
        CGPoint(x: 290, y: 285),   // 弦2 B3 右中
        CGPoint(x: 290, y: 175)    // 弦1 E4 右上
    ]

    /// 枕木槽位 x(等距,中心对称)。
    private var nutSlotX: [CGFloat] { (0..<6).map { 147.0 + CGFloat($0) * 19.2 } }
    private let nutSlotY: CGFloat = 476

    /// 弦粗细(低→高渐细,比例接近真实缠弦/钢弦)。
    private let stringThickness: [CGFloat] = [5.2, 4.4, 3.6, 2.9, 2.0, 1.3]

    private let pegRadius: CGFloat = 20

    // MARK: - 状态

    /// 该弦是否处于"激活"状态(手动选中或自动检测)。
    private func isActive(_ index: Int) -> Bool {
        selectedStringIndex == index || (isListening && detectedStringIndex == index)
    }

    /// 弦的辉光颜色:准音绿、检测中琥珀、其余无。
    private func glowColor(_ index: Int) -> Color? {
        guard isActive(index) else { return nil }
        return isInTune ? AppColors.cta : AppColors.warning
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / designSize.width,
                            geo.size.height / designSize.height)
            ZStack {
                neck
                headstockFace
                strings
                nut
                pegs
            }
            .frame(width: designSize.width, height: designSize.height)
            .scaleEffect(scale)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(designSize.width / designSize.height, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
    }

    // MARK: - 琴头面(胡桃木渐变)

    private var facePath: Path { Self.makeFacePath() }

    /// 琴头面轮廓(设计坐标系,静态供 FaceClipShape 复用)。
    fileprivate static func makeFacePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 100, y: 480))
        p.addCurve(to: CGPoint(x: 78, y: 300),
                   control1: CGPoint(x: 112, y: 420), control2: CGPoint(x: 82, y: 360))
        p.addCurve(to: CGPoint(x: 72, y: 170),
                   control1: CGPoint(x: 74, y: 252), control2: CGPoint(x: 70, y: 205))
        p.addCurve(to: CGPoint(x: 120, y: 48),
                   control1: CGPoint(x: 76, y: 108), control2: CGPoint(x: 94, y: 62))
        // 琴冠圆顶:两侧控制点与顶点同高,入/出切线均为水平 → 镜像处光滑过度。
        p.addQuadCurve(to: CGPoint(x: 195, y: 30),
                       control: CGPoint(x: 152, y: 30))
        p.addQuadCurve(to: CGPoint(x: 270, y: 48),
                       control: CGPoint(x: 238, y: 30))
        p.addCurve(to: CGPoint(x: 318, y: 170),
                   control1: CGPoint(x: 296, y: 62), control2: CGPoint(x: 314, y: 108))
        p.addCurve(to: CGPoint(x: 312, y: 300),
                   control1: CGPoint(x: 320, y: 205), control2: CGPoint(x: 316, y: 252))
        p.addCurve(to: CGPoint(x: 290, y: 480),
                   control1: CGPoint(x: 308, y: 360), control2: CGPoint(x: 278, y: 420))
        p.closeSubpath()
        return p
    }

    private var headstockFace: some View {
        ZStack {
            // 木面基础:胡桃木垂直渐变。
            facePath
                .fill(LinearGradient(
                    colors: [Color(hex: 0x463122), Color(hex: 0x31220F), Color(hex: 0x241811)],
                    startPoint: .top, endPoint: .bottom))
            // 木纹:几道纵向波浪暗纹。
            woodGrain
                .clipShape(FaceClipShape())
            // 体积光:左亮右暗,营造受光方向。
            FaceClipShape()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.10), .clear, .black.opacity(0.20)],
                    startPoint: .leading, endPoint: .trailing))
            // 顶部光泽:上半部的漆面高光。
            FaceClipShape()
                .fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.18), location: 0),
                        .init(color: .white.opacity(0.04), location: 0.30),
                        .init(color: .clear, location: 0.55)
                    ],
                    startPoint: .top, endPoint: .bottom))
            // 边缘:外圈暗描边 + 内圈微亮倒角。
            facePath
                .stroke(Color(hex: 0x120B06).opacity(0.8), lineWidth: 2)
            FaceClipShape()
                .stroke(.white.opacity(0.08), lineWidth: 1.5)
        }
    }

    /// 纵向木纹(暗色波浪线,clip 到琴头面内)。
    private var woodGrain: some View {
        Path { p in
            for baseX in [128.0, 165.0, 205.0, 245.0] {
                var x = baseX
                var y = 52.0
                p.move(to: CGPoint(x: x, y: y))
                while y < 470 {
                    let dx = sin(y * 0.05 + baseX) * 4
                    x = baseX + dx
                    y += 24
                    p.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(Color(hex: 0x171009).opacity(0.55), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }

    /// 枕木下方的琴颈,渐隐收尾(不等到底边——底部让位给仪表区,
    /// 避免木纹与页面底色的交界形成色带感)。
    private var neck: some View {
        Path { p in
            p.move(to: CGPoint(x: 145, y: 478))
            p.addLine(to: CGPoint(x: 255, y: 478))
            p.addLine(to: CGPoint(x: 258, y: 590))
            p.addLine(to: CGPoint(x: 142, y: 590))
            p.closeSubpath()
        }
        .fill(LinearGradient(
            stops: [
                .init(color: Color(hex: 0x2E1E13), location: 0),
                .init(color: Color(hex: 0x2E1E13).opacity(0.5), location: 0.55),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top, endPoint: .bottom))
    }

    // MARK: - 枕木(骨白)

    private var nut: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(
                colors: [Color(hex: 0xF0EADB), Color(hex: 0xD9D0BC)],
                startPoint: .top, endPoint: .bottom))
            .frame(width: 126, height: 10)
            .position(x: 195, y: 480)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }

    // MARK: - 弦(缠弦青铜 / 钢弦银白,带圆柱高光)

    private var strings: some View {
        ForEach(0..<6, id: \.self) { i in
            let active = isActive(i)
            let bronze = i <= 3   // 低音四根缠弦用青铜色
            let base = bronze ? Color(hex: 0xC08A4E) : Color(hex: 0xC9CDD6)
            let color = active ? base : base.opacity(0.4)
            let path = Path { p in
                p.move(to: pegAnchors[i])
                p.addLine(to: CGPoint(x: nutSlotX[i], y: nutSlotY))
            }
            path
                .stroke(color, style: StrokeStyle(lineWidth: stringThickness[i], lineCap: .round))
                .shadow(color: glowColor(i).map { $0.opacity(glowPhase ? 0.85 : 0.35) } ?? .clear,
                        radius: active ? (glowPhase ? 8 : 4) : 0)
            // 圆柱高光:弦中央的细亮线,营造金属圆截面反光。
            path
                .stroke(.white.opacity(active ? 0.55 : 0.30),
                        style: StrokeStyle(lineWidth: max(0.8, stringThickness[i] * 0.32),
                                           lineCap: .round))
        }
    }

    // MARK: - 卷弦器(3+3:侧旋钮 + 传动轴 + 弦柱,可点选)

    /// 单个卷弦器总成。左右结构镜像:旋钮在琴头侧面,弦柱在琴面上(弦锚定处)。
    /// 点按整组(110×52 热区)切换手动锁弦/自动模式。
    private func tunerMachine(_ i: Int) -> some View {
        let anchor = pegAnchors[i]
        let isLeft = i <= 2
        let isSelected = selectedStringIndex == i
        let isDetected = isListening && detectedStringIndex == i
        let ring: Color = {
            if (isSelected || isDetected) && isInTune { return AppColors.cta }
            if isSelected { return AppColors.secondary }
            if isDetected { return AppColors.warning }
            return Color(hex: 0x5A4730)
        }()
        let active = isSelected || isDetected
        let flip: CGFloat = isLeft ? 1 : -1   // 左侧:旋钮在左;右侧镜像

        return Button {
            onSelect(isSelected ? nil : i)
        } label: {
            ZStack {
                // 传动轴(铬色)。
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xA8A8B6), Color(hex: 0x55555F)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: 24, height: 8)
                    .offset(x: 19 * flip)
                // 侧旋钮(象牙白,顶部高光)。
                ZStack {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0xF0ECDD), Color(hex: 0xCFC8B4), Color(hex: 0xA89F8A)],
                            startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(.white.opacity(0.38))
                        .frame(width: 44, height: 9)
                        .offset(y: -8)
                    Capsule()
                        .stroke(.black.opacity(0.30), lineWidth: 1)
                    Text(String(AppConstants.guitarStringNotes[i].dropLast()))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(active ? ring : Color(hex: 0x4A4335))
                }
                .frame(width: 60, height: 34)
                .overlay(Capsule().stroke(ring, lineWidth: active ? 3 : 1.5))
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
                .shadow(color: active ? ring.opacity(0.55) : .clear,
                        radius: glowPhase && !isInTune ? 9 : 5)
                .offset(x: -20.5 * flip)
                // 弦柱(弦锚定处,金属小柱)。
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: 0x7A7A8C), Color(hex: 0x2A2A36)],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 1, endRadius: 13))
                    Circle()
                        .fill(Color(hex: 0x14141C))
                        .frame(width: 11, height: 11)
                    Circle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 4.5, height: 4.5)
                        .blur(radius: 0.8)
                        .offset(x: -4, y: -4)
                }
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(ring.opacity(active ? 0.9 : 0.3), lineWidth: active ? 2 : 1))
                .offset(x: 39.5 * flip)
            }
            .frame(width: 104, height: 60)
        }
        .buttonStyle(.plain)
        .position(x: isLeft ? 60.5 : 329.5, y: anchor.y)
        .accessibilityLabel(String(format: NSLocalizedString("string_n", comment: ""),
                                   AppConstants.guitarStringNames[i]))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var pegs: some View {
        ForEach(0..<6, id: \.self) { i in
            tunerMachine(i)
        }
    }
}

/// 琴头面轮廓 Shape(供 clipShape/fill/strokeBorder 使用)。
private struct FaceClipShape: Shape {
    func path(in rect: CGRect) -> Path {
        TunerHeadstockView.makeFacePath()
    }
}
