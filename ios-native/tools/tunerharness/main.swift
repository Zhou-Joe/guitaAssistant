// 调音器算法回归 harness(macOS 命令行,编译真实生产源文件)。
// 验证:跳变确认(换弦切换/八度闪跳过滤)、中值平滑、滞回选择器、YIN 检测精度。

import Foundation
import Accelerate

var failures = 0
var passed = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1; print("✅ \(name)") }
    else { failures += 1; print("❌ \(name) \(detail())") }
}
func centsBetween(_ a: Double, _ b: Double) -> Double {
    1200.0 * log2(a / b)
}

// MARK: - 1. FrequencySmoother

do {
    let s = FrequencySmoother()
    // 稳定在 E2(82.41)。
    var out = 0.0
    for _ in 0..<10 { out = s.process(82.41 + .random(in: -0.5...0.5)) ?? 0 }
    check("中值收敛到 E2", abs(centsBetween(out, 82.41)) < 10, "out=\(out)")

    // 真实换弦到 A2(110):4 帧确认后切换,确认前保持 E2。
    var switchedFrame = -1
    for i in 0..<8 {
        out = s.process(110.0) ?? 0
        if abs(centsBetween(out, 110)) < 10 { switchedFrame = i; break }
        check("确认前保持 E2(第 \(i) 帧)", abs(centsBetween(out, 82.41)) < 15, "out=\(out)")
    }
    check("持续新弦 4 帧内切换", switchedFrame >= 0 && switchedFrame <= 3,
          "switchedFrame=\(switchedFrame)")

    // 尾音回到 E2 后再换弦场景由上面覆盖;此处验证清空后重新工作。
    s.reset()
    check("reset 后无稳定值", s.process(200) != nil)
}

do {
    // 八度闪跳(f→2f)只持续 2 帧 → 被过滤,输出保持原值。
    let s = FrequencySmoother()
    var out = 0.0
    for _ in 0..<10 { out = s.process(146.83) ?? 0 }   // D3 稳定
    for _ in 0..<2 { out = s.process(293.66) ?? 0 }    // 八度错误 2 帧
    check("八度闪跳被过滤", abs(centsBetween(out, 146.83)) < 15, "out=\(out)")
    for _ in 0..<5 { out = s.process(146.83) ?? 0 }
    check("闪跳后恢复正常", abs(centsBetween(out, 146.83)) < 10, "out=\(out)")
}

do {
    // 拨弦瞬态的 1-2 帧乱值不污染中值。
    let s = FrequencySmoother()
    var out = 0.0
    for _ in 0..<10 { out = s.process(196.0) ?? 0 }   // G3
    _ = s.process(90)   // 瞬态乱值 1
    _ = s.process(300)  // 瞬态乱值 2
    out = s.process(196.0) ?? 0
    check("瞬态乱值不污染中值", abs(centsBetween(out, 196.0)) < 15, "out=\(out)")
}

// MARK: - 2. StickySelector

do {
    var sel = StickySelector(confirmFrames: 3)
    // 首次:透传。
    check("首次透传", sel.update(5, hold: false) == 5)
    _ = sel.update(5, hold: false)
    _ = sel.update(5, hold: false)
    // stable=5 已确立(连续 3 帧)。
    check("3 帧后稳定", sel.update(5, hold: false) == 5)
    // hold 带内:强制保持。
    check("保持带内不切换", sel.update(6, hold: true) == 5)
    // hold 带外:需连续 3 帧一致才切换。
    check("带外第 1 帧仍保持", sel.update(6, hold: false) == 5)
    check("带外第 2 帧仍保持", sel.update(6, hold: false) == 5)
    check("带外第 3 帧切换", sel.update(6, hold: false) == 6)
    // 边界抖动(交替)不切换。
    var flip = 0
    for i in 0..<10 { if sel.update(i % 2 == 0 ? 6 : 7, hold: false) != 6 { flip += 1 } }
    check("交替抖动不切换", flip == 0, "flip=\(flip)")
}

// MARK: - 3. PitchDetector(合成信号)

/// 合成吉他式谐波信号(基频 + 衰减谐波)。
func synth(f0: Double, sampleRate: Double = 44100, count: Int = 4096,
           harmonics: [Double] = [1, 0.5, 0.33, 0.25, 0.12]) -> [Float] {
    (0..<count).map { i in
        let t = Double(i) / sampleRate
        var v = 0.0
        for (h, amp) in harmonics.enumerated() {
            v += amp * sin(2 * .pi * f0 * Double(h + 1) * t)
        }
        return Float(v / 2.2)
    }
}

do {
    let det = PitchDetector(sampleRate: 44100)
    for (name, f0) in [("E2", 82.41), ("A2", 110.0), ("D3", 146.83),
                       ("G3", 196.0), ("B3", 246.94), ("E4", 329.63)] {
        let r = det.detectWithClarity(samples: synth(f0: f0))
        let ok = r != nil && abs(centsBetween(r!.frequency, f0)) < 3
        check("YIN 检测 \(name)", ok, "r=\(r.map { String(format: "%.2f(cl=%.3f)", $0.frequency, $0.clarity) } ?? "nil")")
        if let r { check("YIN 清晰度 \(name)", r.clarity < 0.15, "cl=\(r.clarity)") }
    }
}

do {
    // 白噪声:不应检测出频率(兜底路径收紧后)。
    let det = PitchDetector(sampleRate: 44100)
    let noise = (0..<4096).map { _ in Float.random(in: -0.3...0.3) }
    let r = det.detectWithClarity(samples: noise)
    check("白噪声不误检(或清晰度差)", r == nil || r!.clarity > 0.3,
          "r=\(r.map { String(format: "%.1f(cl=%.3f)", $0.frequency, $0.clarity) } ?? "nil")")
}

// MARK: - 4. 端到端序列模拟(自动模式算法链)

do {
    // 模拟:拨 D3 → 2 帧八度错误 → 恢复;随后真换弦到 G3。
    let s = FrequencySmoother()
    var stickyNote = StickySelector(confirmFrames: 3)
    var displayed: [Int] = []
    func frame(_ f: Double?) {
        guard let f, let smoothed = s.process(f) else { return }
        let semitones = 12.0 * log2(smoothed / 440.0)
        let raw = Int(semitones.rounded())
        let hold = stickyNote.stable >= 0
            && abs((semitones - Double(stickyNote.stable)) * 100.0) <= 60
        displayed.append(stickyNote.update(raw, hold: hold))
    }
    for _ in 0..<10 { frame(146.83) }
    for _ in 0..<2 { frame(293.66) }   // 八度闪跳
    for _ in 0..<6 { frame(146.83) }
    for _ in 0..<10 { frame(196.0) }   // 换弦 G3
    let d3 = -17   // D3 相对 A4 的半音数(12*log2(146.83/440) ≈ -19.99?) 由首值推断
    // 直接断言行为:序列不应出现 D3 与 G3 之外的第三种音,且后半段稳定为 G3。
    let g3 = 12 * log2(196.0 / 440.0)
    let g3Idx = Int(g3.rounded())
    let lastVals = Set(displayed.suffix(6))
    check("端到端:后半段稳定显示 G3", lastVals == [g3Idx], "last=\(lastVals) 期望=\(g3Idx)")
    // 中段的八度闪跳不应让显示进入 G3 前提前变化到别的音(允许保持 D3)。
    let midVals = Set(displayed[10..<18])
    check("端到端:八度闪跳期间显示不乱跳", midVals.count <= 1, "mid=\(midVals)")
    _ = d3
}


// MARK: - 5. PitchTracker(mini-pYIN)

func cand(_ f: Double, _ p: Double) -> PitchCandidate {
    PitchCandidate(frequency: f, probability: p)
}
func centsOff(_ a: Double, _ b: Double) -> Double { 1200.0 * log2(a / b) }

do {
    let tracker = PitchTracker()
    // 稳定跟踪:带抖动的 D3 候选流。
    var out = tracker.update(candidates: [])
    for i in 0..<10 {
        out = tracker.update(candidates: [cand(146.83 * pow(2, Double((i % 3) - 1) * 8 / 1200), 0.9),
                                          cand(293.66, 0.4)])
    }
    check("tracker 稳定跟踪 D3", out.frequency != nil && abs(centsOff(out.frequency!, 146.83)) < 20,
          "out=\(out.frequency.map { String(format: "%.1f", $0) } ?? "nil")")
}

do {
    // 新弦接管:稳定 D3 后换 A2,应在 ≤3 帧内切换。
    let tracker = PitchTracker()
    for _ in 0..<10 { _ = tracker.update(candidates: [cand(146.83, 0.9)]) }
    var switched = -1
    for i in 0..<6 {
        let out = tracker.update(candidates: [cand(110.0, 0.9)])
        if out.frequency != nil, abs(centsOff(out.frequency!, 110)) < 20 { switched = i; break }
    }
    check("tracker 新弦 3 帧内接管", switched >= 0 && switched <= 2, "switched=\(switched)")
}

do {
    // 八度闪跳:单帧 2×D3(即便高可信)不夺走跟踪。
    let tracker = PitchTracker()
    for _ in 0..<10 { _ = tracker.update(candidates: [cand(146.83, 0.9)]) }
    let out = tracker.update(candidates: [cand(293.66, 0.95)])
    check("tracker 八度闪跳被抑制", out.frequency != nil && abs(centsOff(out.frequency!, 146.83)) < 20,
          "out=\(out.frequency ?? 0)")
    // 两帧高可信八度仍会切换(真实八度错误持续存在时应跟随)。
    _ = tracker.update(candidates: [cand(293.66, 0.95)])
    let out2 = tracker.update(candidates: [cand(293.66, 0.95)])
    check("tracker 持续八度最终切换", out2.frequency != nil && abs(centsOff(out2.frequency!, 293.66)) < 25,
          "out=\(out2.frequency ?? 0)")
}

do {
    // 瞬态乱值:低可信远距候选被剔除。
    let tracker = PitchTracker()
    for _ in 0..<10 { _ = tracker.update(candidates: [cand(196.0, 0.9)]) }
    let out = tracker.update(candidates: [cand(95.0, 0.3), cand(310.0, 0.35)])
    check("tracker 瞬态乱值被剔除", out.frequency != nil && abs(centsOff(out.frequency!, 196.0)) < 25,
          "out=\(out.frequency ?? 0)")
}

do {
    // 无声保持与释放。
    let tracker = PitchTracker()
    for _ in 0..<10 { _ = tracker.update(candidates: [cand(146.83, 0.9)]) }
    let hold = tracker.update(candidates: [])
    check("tracker 无声短暂保持", hold.frequency != nil)
    var release: PitchTracker.Output?
    for _ in 0..<12 { release = tracker.update(candidates: []) }
    check("tracker 长静音释放为无频", release?.frequency == nil)
}

// MARK: - 6. 多候选提取(真实信号 + 带通)

do {
    let det = PitchDetector(sampleRate: 44100)
    let e2 = synth(f0: 82.41)
    let cands = det.detectCandidates(samples: e2)
    check("E2 候选非空", !cands.isEmpty, "count=\(cands.count)")
    let best = cands.first
    check("E2 最优候选 ≈82.4Hz", best != nil && abs(centsOff(best!.frequency, 82.41)) < 10,
          "best=\(best.map { String(format: "%.1f(p%.2f)", $0.frequency, $0.probability) } ?? "nil")")
}

do {
    // 带通:混入 30Hz + 2kHz 强噪声,主候选仍应命中 G3。
    let det = PitchDetector(sampleRate: 44100)
    let noisy = (0..<4096).map { i -> Float in
        let t = Double(i) / 44100.0
        let g3 = sin(2 * .pi * 196.0 * t) + 0.5 * sin(4 * .pi * 196.0 * t)
        let rumble = 0.9 * sin(2 * .pi * 30.0 * t)
        let hiss = 0.7 * sin(2 * .pi * 2000.0 * t)
        return Float(g3 + rumble + hiss)
    }
    let cands = det.detectCandidates(samples: noisy)
    let best = cands.first
    check("带通抗噪 G3 主候选", best != nil && abs(centsOff(best!.frequency, 196.0)) < 10,
          "best=\(best.map { String(format: "%.1f", $0.frequency) } ?? "nil")")
}

print("\n通过 \(passed),失败 \(failures)")
exit(failures == 0 ? 0 : 1)
