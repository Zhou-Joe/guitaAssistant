// 在 sample 图的"系统上方条带"跑 Vision OCR,验证本地和弦名提取。
import Foundation
import CoreGraphics
import ImageIO
import Vision

for path in CommandLine.arguments.dropFirst() {
    print("===== \((path as NSString).lastPathComponent)")
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { print("加载失败"); continue }
    let W = img.width, H = img.height
    guard let gray = TabVisionAlgorithms.grayscaleBuffer(of: img) else { continue }
    let bin: [UInt8] = gray.map { $0 < 134 ? 1 : 0 }
    let maxRun = TabVisionAlgorithms.rowMaxRuns(bin, width: W, height: H)
    let bands = TabVisionAlgorithms.extractLineBands(maxRunPerRow: maxRun, imageWidth: Double(W))
    let systems = TabVisionAlgorithms.fitStringSystems(bands: bands, imageHeight: Double(H))
    print("系统 \(systems.count) 个")
    // 行墨量分布(找和弦文字真实位置)。
    let rowCount = bin.count / W
    var rowInk = [Int](repeating: 0, count: rowCount)
    for y in 0..<rowCount {
        var c = 0
        let base = y * W
        for x in 0..<W where bin[base + x] == 1 { c += 1 }
        rowInk[y] = c
    }
    // 每 5 行聚合打印。
    var y = 0
    while y < min(rowCount, 130) {
        let sum = rowInk[y..<min(y + 5, rowCount)].reduce(0, +)
        if sum > 20 { print("  rows \(y)-\(y + 4): ink=\(sum)") }
        y += 5
    }
    for (si, sys) in systems.enumerated() {
        let d = sys.spacing
        // 条带:上一个系统底线(首个系统取图顶)到本系统顶线上方 0.15d。
        let prevBottom = si == 0 ? 0.0 : systems[si - 1].lineYs.last!
        let bandTop = max(0, Int(prevBottom + 0.1 * d))
        let bandBottom = min(H - 1, Int(sys.lineYs[0] - 0.15 * d))
        let bandH = bandBottom - bandTop
        guard bandH > 8, let crop = img.cropping(to: CGRect(x: 0, y: bandTop, width: W, height: bandH)) else { continue }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        // 双尺度(1x + 3x)分别 OCR,并集提高小字召回。
        if si == 0, path.contains("sample_tab.png") {
            let outURL = URL(fileURLWithPath: "/tmp/fullband1.png")
            let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)
            CGImageDestinationAddImage(dest!, crop, nil)
            CGImageDestinationFinalize(dest!)
        }
        var lines: [String] = []
        for scale in [1, 3] {
            let sw = crop.width * scale, sh = crop.height * scale
            var big = [UInt8](repeating: 255, count: sw * sh)
            guard let bctx = CGContext(data: &big, width: sw, height: sh,
                                       bitsPerComponent: 8, bytesPerRow: sw,
                                       space: CGColorSpaceCreateDeviceGray(),
                                       bitmapInfo: CGImageAlphaInfo.none.rawValue) else { continue }
            bctx.interpolationQuality = .none
            bctx.draw(crop, in: CGRect(x: 0, y: 0, width: sw, height: sh))
            guard let bigImg = bctx.makeImage() else { continue }
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            req.customWords = ["C", "G", "D", "A", "E", "F", "B",
                               "Am", "Em", "Dm", "Bm", "F#m", "C#m", "Gm",
                               "C7", "D7", "E7", "G7", "A7", "B7",
                               "Cmaj7", "Fmaj7", "Dm7", "Em7", "Am7",
                               "Csus4", "Dsus2", "Asus4", "Cadd9",
                               "D/F#", "G/B", "C/E", "A/E", "E/G#"]
            let handler = VNImageRequestHandler(cgImage: bigImg, options: [:])
            try? handler.perform([req])
            lines += (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }
        print("系统\(si) 条带[y\(bandTop)+\(bandH)] OCR: \(lines)")
    }
}
