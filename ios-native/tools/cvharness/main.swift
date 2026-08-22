// CV 纯算法验证 harness(macOS 命令行,编译真实生产源文件)。
import CoreText
// 用合成数据验证:线带提取、等差拟合(含文字行干扰/缺线/多行谱)、
// 两位数合并、归弦、小节切分、置信度。

import Foundation

var failures = 0
var passed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("✅ \(name)") }
    else { failures += 1; print("❌ \(name) \(detail())") }
}
func approx(_ a: Double, _ b: Double, _ tol: Double) -> Bool { abs(a - b) <= tol }

// MARK: - 合成工具

/// 合成每行最长黑行程数组:弦线行给 run≈tabWidth,文字行给小 run。
func synthMaxRun(height: Int, width: Double, lineYs: [Int],
                 textRows: [(y: Int, run: Double)] = [],
                 lineRun: Double? = nil) -> [Double] {
    var rows = [Double](repeating: 0, count: height)
    let lr = lineRun ?? width * 0.95
    for y in lineYs where (0..<height).contains(y) { rows[y] = lr }
    for t in textRows where (0..<height).contains(t.y) { rows[t.y] = t.run }
    return rows
}

// MARK: - 1. extractLineBands

do {
    // 6 条弦线 + 标题行 + 歌词行(行程远小于弦线)。
    let lineYs = [100, 150, 200, 250, 300, 350]
    let rows = synthMaxRun(height: 500, width: 1000, lineYs: lineYs,
                           textRows: [(50, 300), (430, 180)])
    let bands = TabVisionAlgorithms.extractLineBands(maxRunPerRow: rows, imageWidth: 1000)
    check("线带数=6(文字行被排除)", bands.count == 6, "实际 \(bands.count): \(bands)")
    var allClose = !bands.isEmpty
    for (i, y) in lineYs.enumerated() where i < bands.count {
        if !approx(bands[i].center, Double(y), 1.0) { allClose = false }
    }
    check("线带中心与真实弦线对齐", allClose, "\(bands.map { $0.center })")
}

do {
    // 全平投影(无谱)。
    let bands = TabVisionAlgorithms.extractLineBands(maxRunPerRow: [Double](repeating: 10, count: 300),
                                                     imageWidth: 400)
    check("平坦投影无线带", bands.isEmpty)
}

// MARK: - 2. fitStringSystems

func bands(at ys: [Double], thickness: Double = 2, strength: Double = 950) -> [TVLineBand] {
    ys.sorted().map { TVLineBand(center: $0, thickness: thickness, strength: strength) }
}

do {
    // 标准单系统 + 一个文字行残留(不在等距网格上)。
    let lineYs: [Double] = [100, 150, 200, 250, 300, 350]
    let cand = bands(at: lineYs + [55])   // 55 是和弦名行残留
    let systems = TabVisionAlgorithms.fitStringSystems(bands: cand, imageHeight: 500)
    check("文字干扰下仍识别 1 个系统", systems.count == 1, "实际 \(systems.count)")
    if let s = systems.first {
        check("弦距正确", approx(s.spacing, 50, 2), "实际 \(s.spacing)")
        check("6 条线全命中", s.lineYs.count == 6 && approx(s.inlierRatio, 1.0, 0.01),
              "inlier=\(s.inlierRatio)")
        check("间距规整 cv≈0", s.spacingCV < 0.05, "cv=\(s.spacingCV)")
        check("文字行未入选", s.lineYs.allSatisfy { !approx($0, 55, 10) }, "\(s.lineYs)")
    }
}

do {
    // 缺一条弦线(第 4 条缺失):应插值补齐,间距仍正确。
    let partial: [Double] = [100, 150, 200, 300, 350]
    let systems = TabVisionAlgorithms.fitStringSystems(bands: bands(at: partial), imageHeight: 500)
    check("缺线时仍成系统", systems.count == 1, "实际 \(systems.count)")
    if let s = systems.first {
        check("缺线插值 y≈250", approx(s.lineYs[3], 250, 6), "\(s.lineYs)")
        check("inlier=5/6", approx(s.inlierRatio, 5.0 / 6.0, 0.01), "\(s.inlierRatio)")
    }
}

do {
    // 两行谱(两个系统)。
    let sys1: [Double] = [80, 130, 180, 230, 280, 330]
    let sys2: [Double] = [430, 480, 530, 580, 630, 680]
    let systems = TabVisionAlgorithms.fitStringSystems(bands: bands(at: sys1 + sys2), imageHeight: 800)
    check("多行谱识别 2 个系统", systems.count == 2, "实际 \(systems.count): \(systems)")
    if systems.count == 2 {
        check("系统顺序自上而下", systems[0].lineYs[0] < systems[1].lineYs[0])
        check("系统 2 弦距正确", approx(systems[1].spacing, 50, 2), "\(systems[1].spacing)")
    }
}

// MARK: - 3. assembleScore

let lineYs: [Double] = [100, 150, 200, 250, 300, 350]
let system = TVStringSystem(lineYs: lineYs, spacing: 50, inlierRatio: 1.0,
                            spacingCV: 0, lineThickness: 2)
func dbox(_ digit: Int, _ x0: Double, _ x1: Double, _ cy: Double, conf: Double = 0.9) -> TVDigitBox {
    TVDigitBox(digit: digit, confidence: conf, x0: x0, x1: x1, cx: (x0 + x1) / 2, cy: cy)
}

do {
    // "12" 合并:d=50,两个数字间隙 2px < 0.5d,基线对齐。
    let digits = [dbox(1, 100, 110, 200), dbox(2, 112, 122, 200)]
    let score = TabVisionAlgorithms.assembleScore(systems: [system], digits: digits, imageWidth: 1000)
    let frets = score.measures.first?.strings[2].map(\.fret) ?? []
    check("两位数合并为 12", frets == [12], "实际 \(frets)")
}

do {
    // 间隙大 → 不合并,且大间距应切分为两个小节(各含 1、2)。
    let digits = [dbox(1, 100, 110, 200), dbox(2, 300, 310, 200)]
    let score = TabVisionAlgorithms.assembleScore(systems: [system], digits: digits, imageWidth: 1000)
    let allFrets = score.measures.flatMap { $0.strings[2].map(\.fret) }
    check("大间隙不合并(仍为 1、2 两个音符)", allFrets == [1, 2], "实际 \(allFrets)")
    check("大间隙切分小节", score.measures.count == 2, "实际 \(score.measures.count)")
}

do {
    // 非法两位数("25" > 24)不合并。
    let digits = [dbox(2, 100, 110, 200), dbox(5, 112, 122, 200)]
    let score = TabVisionAlgorithms.assembleScore(systems: [system], digits: digits, imageWidth: 1000)
    let frets = score.measures.first?.strings[2].map(\.fret) ?? []
    check("25 不合并(超 24 品)", frets == [2, 5], "实际 \(frets)")
}

do {
    // 归弦:顶弦/底弦 + 系统外文字丢弃。
    let digits = [dbox(0, 100, 110, 100),   // 第 1 弦(高音 E)
                  dbox(3, 150, 160, 350),   // 第 6 弦(低音 E)
                  dbox(7, 200, 210, 40)]    // 上方和弦名文字,应丢弃
    let score = TabVisionAlgorithms.assembleScore(systems: [system], digits: digits, imageWidth: 1000)
    check("系统外数字丢弃后仅 1 小节", score.measures.count == 1)
    check("高音 E 弦 fret 0", score.measures[0].strings[0].first?.fret == 0)
    check("低音 E 弦 fret 3", score.measures[0].strings[5].first?.fret == 3)
}

do {
    // 小节切分:x 间距 600px(远超阈值)→ 两个小节。
    let digits = [dbox(0, 100, 110, 200), dbox(5, 700, 710, 250)]
    let score = TabVisionAlgorithms.assembleScore(systems: [system], digits: digits, imageWidth: 1000)
    check("大间距切分小节", score.measures.count == 2, "实际 \(score.measures.count)")
}

do {
    // 多系统拼接:系统 1 的 1 小节 + 系统 2 的 1 小节,顺序正确。
    let system2 = TVStringSystem(lineYs: [430, 480, 530, 580, 630, 680], spacing: 50,
                                 inlierRatio: 1.0, spacingCV: 0, lineThickness: 2)
    let digits = [dbox(1, 100, 110, 100),    // 系统 1
                  dbox(4, 100, 110, 480)]    // 系统 2
    let score = TabVisionAlgorithms.assembleScore(systems: [system, system2], digits: digits, imageWidth: 1000)
    check("两系统各 1 小节", score.measures.count == 2, "实际 \(score.measures.count)")
}

// MARK: - 4. confidence

do {
    check("空输入置信度 0", TabVisionAlgorithms.confidence(systems: [], digits: []) == 0)
    let c = TabVisionAlgorithms.confidence(systems: [system],
                                           digits: [dbox(1, 0, 10, 100), dbox(2, 20, 30, 150)])
    check("规整系统+高分类置信度 → 综合 ≥0.8", c >= 0.8, "实际 \(c)")
}

// MARK: - 5. DigitClassifier 冒烟(合成笔画)

do {
    // "1":窄竖条(紧贴外接框,无留白)。
    var px: [(Int, Int)] = []
    for y in 0..<12 { px.append((0, y)); px.append((1, y)) }
    let r1 = DigitClassifier.classify(DigitClassifier.Blob(width: 2, height: 12, pixels: px))
    check("分类器识别 1", r1.digit == 1, "实际 \(r1.digit)")
    // 模板匹配精度:真实字体渲染 0-9(三种字体),准确率应 ≥ 85%。
    var correct = 0, total = 0
    for font in ["Helvetica-Bold", "TimesNewRomanPS-BoldMT", "Courier-Bold"] {
        for d in 0...9 {
            let ctFont = CTFontCreateWithName(font as CFString, 30, nil)
            let attr = [kCTFontAttributeName: ctFont] as CFDictionary
            let line = CTLineCreateWithAttributedString(
                CFAttributedStringCreate(nil, "\(d)" as CFString, attr)!)
            let w = 128, h = 128
            var px2 = [UInt8](repeating: 255, count: w * h)
            let ctx2 = CGContext(data: &px2, width: w, height: h, bitsPerComponent: 8,
                                 bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                 bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            ctx2.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            ctx2.textPosition = CGPoint(x: 30, y: 90)
            CTLineDraw(line, ctx2)
            var pts: [(Int, Int)] = []
            var mnX = 999, mxX = -1, mnY = 999, mxY = -1
            for y in 0..<h { for x in 0..<w where px2[y * w + x] < 128 {
                pts.append((x, y))
                mnX = min(mnX, x); mxX = max(mxX, x); mnY = min(mnY, y); mxY = max(mxY, y)
            }}
            let blob = DigitClassifier.Blob(width: mxX - mnX + 1, height: mxY - mnY + 1,
                                            pixels: pts.map { ($0.0 - mnX, $0.1 - mnY) })
            if DigitClassifier.classify(blob).digit == d { correct += 1 }
            total += 1
        }
    }
    check("模板匹配精度 ≥85%(真实字体)", Double(correct) / Double(total) >= 0.85,
          "实际 \(correct)/\(total)")
}

// MARK: - 6. 端到端:CoreText 渲染仿真六线谱 → 完整像素管线

import CoreGraphics
import CoreText

do {
    // 6a. 缓冲区方向实验:构造顶黑底白的 CGImage,确认 buffer 第 0 行对应图像顶行。
    let ew = 2, eh = 4
    var src = [UInt8](repeating: 0, count: ew * eh)
    for i in 0..<(ew * eh / 2) { src[i] = 0 }        // 前一半(图像顶行)= 黑
    for i in (ew * eh / 2)..<(ew * eh) { src[i] = 255 }
    let prov = CGDataProvider(data: Data(src) as CFData)!
    let eimg = CGImage(width: ew, height: eh, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: ew, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: prov, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let ebuf = TabVisionAlgorithms.grayscaleBuffer(of: eimg)!
    let topBlack = ebuf[0] < 128 && ebuf[ew - 1] < 128
    check("buffer 第 0 行 = 图像顶行", topBlack,
          "buf=\(ebuf) —— 若失败需调整 grayscaleBuffer 的翻转")

    // 6b. 渲染仿真谱面:6 线(d=50)+ 标题 + 和弦名 + 竖小节线 + 压线数字。
    let W = 1000, H = 500
    let lineYs = [100, 150, 200, 250, 300, 350]
    let d = 50.0
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.setFillColor(gray: 0, alpha: 1)

    // 文本绘制(CoreText 在 y-up 位图上下文中会倒置,需翻转变换;pt 按 y-up 传)。
    func drawText(_ text: String, font: CTFont, at pt: CGPoint) {
        let attr = [kCTFontAttributeName: font] as CFDictionary
        let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attr)!)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(H))
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = CGPoint(x: pt.x, y: CGFloat(H) - pt.y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
    let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 28, nil)
    let digitFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 26, nil)

    // 标题(远离谱面,应被弦线检测排除)与和弦名(谱面上方,应被 0.6d 规则丢弃)。
    drawText("Song Title", font: titleFont, at: CGPoint(x: 380, y: CGFloat(H - 40)))
    drawText("C", font: titleFont, at: CGPoint(x: 120, y: 400))
    drawText("Am", font: titleFont, at: CGPoint(x: 620, y: 400))

    // 弦线(位图上下文 y 向上,弦线 y 直接用下述坐标即可,与翻转后的 buffer 一致性由 6a 保证)。
    for ly in lineYs {
        ctx.fill(CGRect(x: 20, y: CGFloat(ly), width: CGFloat(W - 40), height: 2))
    }
    // 竖小节线(应被高度过滤排除)。
    ctx.fill(CGRect(x: 500, y: 95, width: 3, height: 262))

    // 数字:压线绘制,先垫白底断开弦线,再画字形。
    func drawDigit(_ ch: String, at x: Int, onLine ly: Int) {
        let box = CGRect(x: CGFloat(x), y: CGFloat(ly) - 16, width: 24, height: 34)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(box)
        ctx.setFillColor(gray: 0, alpha: 1)
        drawText(ch, font: digitFont, at: CGPoint(x: CGFloat(x) + 4, y: CGFloat(ly) - 11))
    }
    // 第 1 弦(顶部,y=100):0 3 5;第 4 弦(y=250):"12" 相邻两字;第 6 弦(底部,y=350):7。
    for (i, ch) in ["0", "3", "5"].enumerated() { drawDigit(ch, at: 60 + i * 120, onLine: 100) }
    drawDigit("1", at: 300, onLine: 250)
    drawDigit("2", at: 322, onLine: 250)
    drawDigit("7", at: 700, onLine: 350)

    let img = ctx.makeImage()!
    // 完整像素管线。
    let gray = TabVisionAlgorithms.grayscaleBuffer(of: img)!
    let otsu = TabVisionAlgorithms.otsuThreshold(gray)
    let bin: [UInt8] = gray.map { $0 < UInt8(max(30, min(220, otsu))) ? 1 : 0 }
    let maxRun = TabVisionAlgorithms.rowMaxRuns(bin, width: W, height: H)
    let bands = TabVisionAlgorithms.extractLineBands(maxRunPerRow: maxRun, imageWidth: Double(W))
    let systems = TabVisionAlgorithms.fitStringSystems(bands: bands, imageHeight: Double(H))
    check("端到端:识别 1 个系统", systems.count == 1, "实际 \(systems.count)(bands=\(bands.count))")
    if let sys = systems.first {
        check("端到端:弦距≈50", approx(sys.spacing, 50, 4), "实际 \(sys.spacing)")
        check("端到端:6 线全中", approx(sys.inlierRatio, 1.0, 0.01), "\(sys.inlierRatio)")
    }
    let cleaned = TabVisionAlgorithms.eraseStringLines(bin, width: W, height: H, systems: systems)
    let digits = TabVisionAlgorithms.detectDigitBoxes(cleaned, width: W, height: H, systems: systems)
    print("   端到端数字块: \(digits.map { "(\($0.digit)@x\($0.cx),y\($0.cy))" })")
    // 可归弦(0.5d 内)的数字块应为 6:标题/和弦名/小节线均被排除。
    let d0 = systems[0].spacing
    let assignable = digits.filter { box in
        systems[0].lineYs.contains { abs($0 - box.cy) <= 0.5 * d0 }
    }
    check("端到端:可归弦数字 = 6(排除文字与小节线)", assignable.count == 6,
          "实际 \(assignable.count): \(assignable.map { $0.digit })")
    let score = TabVisionAlgorithms.assembleScore(systems: systems, digits: digits, imageWidth: Double(W))
    print(score.toAsciiTab())
    // "12" 合并后,总音符数 = 5(0,3,5,12,7)。
    let totalNotes = score.measures.reduce(0) { $0 + $1.strings.reduce(0) { $0 + $1.count } }
    check("端到端:两位数合并后总音符 = 5", totalNotes == 5, "实际 \(totalNotes)")
}

print("\n通过 \(passed),失败 \(failures)")
exit(failures == 0 ? 0 : 1)
