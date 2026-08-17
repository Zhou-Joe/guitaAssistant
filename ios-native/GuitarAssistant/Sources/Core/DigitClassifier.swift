import Foundation

/// 数字形状分类器（纯算法，无 UI/平台依赖，可单元测试）。
///
/// 基于 Audiveris 维护者的建议：对孤立数字用形状特征分类而非通用 OCR
/// （OCR 设计目标是文本行，对孤立小数字识别率低）。
///
/// 输入：二值化的数字块像素（相对坐标，0/1）+ 外接矩形宽高。
/// 输出：0-9 的识别结果 + 置信度。
public enum DigitClassifier {

    public struct Blob {
        public let width: Int
        public let height: Int
        /// 黑像素的相对坐标 (x in 0..<width, y in 0..<height)。
        public let pixels: [(x: Int, y: Int)]
        public init(width: Int, height: Int, pixels: [(x: Int, y: Int)]) {
            self.width = width
            self.height = height
            self.pixels = pixels
        }
    }

    public struct Result {
        public let digit: Int
        public let confidence: Double
        public init(digit: Int, confidence: Double) {
            self.digit = digit
            self.confidence = confidence
        }
    }

    /// 分类数字块。
    public static func classify(_ blob: Blob) -> Result {
        let w = Double(blob.width)
        let h = Double(blob.height)
        guard h > 0 else { return Result(digit: 0, confidence: 0) }
        let ratio = w / h   // 宽高比
        let fill = Double(blob.pixels.count) / Double(blob.width * blob.height)   // 填充率

        // 构建 2D 像素网格便于特征提取。
        let grid = makeGrid(blob)

        // guard width > 0 防除零。
        guard blob.width > 0 else { return Result(digit: 0, confidence: 0) }

        // 1) 宽高比 < 0.55 且填充率高 → "1"（窄竖条）。
        if ratio < 0.55 && fill > 0.7 {
            return Result(digit: 1, confidence: 0.95)
        }

        // 2) 用孔洞数区分有孔(0/4/6/8/9) vs 无孔(2/3/5/7)。
        let holes = countHoles(grid: grid, width: blob.width, height: blob.height)

        // 区域密度：上/下/左/右/中。
        let topD = rowDensity(grid: grid, width: blob.width, height: blob.height,
                              yStart: 0, yEnd: blob.height / 3)
        let botD = rowDensity(grid: grid, width: blob.width, height: blob.height,
                              yStart: blob.height * 2 / 3, yEnd: blob.height)
        let leftD = columnDensity(grid: grid, width: blob.width, height: blob.height,
                                   xStart: 0, xEnd: blob.width / 3)
        let rightD = columnDensity(grid: grid, width: blob.width, height: blob.height,
                                    xStart: blob.width * 2 / 3, xEnd: blob.width)
        let midD = columnDensity(grid: grid, width: blob.width, height: blob.height,
                                  xStart: blob.width / 3, xEnd: blob.width * 2 / 3)
        let purity = stemPurity(grid: grid, width: blob.width, height: blob.height)
        let brD = regionDensity(grid: grid, width: blob.width, height: blob.height,
                                x0: blob.width / 2, x1: blob.width,
                                y0: blob.height * 2 / 3, y1: blob.height)

        if holes >= 2 {
            // 两个孔 → 8（吉他品位 8/18 较常见）。
            return Result(digit: 8, confidence: 0.7)
        }

        // "7":顶部横杠 + 斜杠左倾 → 顶部密、右下几乎无墨。
        // (放在纯度规则之前:横杠与斜杠会使部分列产生两段,纯度不高。)
        if holes == 0, topD > 0.42, brD < 0.10 {
            return Result(digit: 7, confidence: 0.75)
        }
        // "1":单竖笔画(每列几乎只有一段连续黑)。带旗衬线的字体宽度可到
        // 0.85,旧规则(ratio<0.55)会漏。
        if holes == 0, purity >= 0.72, ratio < 0.9 {
            return Result(digit: 1, confidence: 0.85)
        }

        if holes == 1 {
            // 单孔数字：0/4/6/9。
            // 0：上下左右都较均匀（环形），ratio ≈ 1。
            if abs(topD - botD) < 0.15 && abs(leftD - rightD) < 0.15 {
                return Result(digit: 0, confidence: 0.85)
            }
            // 4：右上有竖线+左上有斜线，孔在右上，底部开放。
            if topD > botD && rightD > leftD {
                return Result(digit: 4, confidence: 0.65)
            }
            // 6：底部有完整弧（botD 高），顶部开放。
            if botD > topD && leftD > 0.3 {
                return Result(digit: 6, confidence: 0.6)
            }
            // 9：顶部有完整弧（topD 高），底部开放。
            if topD > botD && leftD > 0.3 {
                return Result(digit: 9, confidence: 0.6)
            }
            // 默认有孔 → 0（吉他谱最常见）。
            return Result(digit: 0, confidence: 0.55)
        }

        // 无孔数字：2/3/5/7。
        // 7：宽高比小（斜线），topD 高且 leftD 低（从右上到左下）。
        if topD > 0.4 && leftD < 0.15 && botD < 0.2 {
            return Result(digit: 7, confidence: 0.7)
        }
        // 5：上半部分完整弧（topD 高），下半右侧有一条竖线（rightD 中等），
        //   且左下角开放（bottom-left 少）。
        if topD > 0.35 && rightD > leftD && midD < 0.3 {
            return Result(digit: 5, confidence: 0.6)
        }
        // 2 vs 3：2 底部有贯穿横杠（左下象限有墨）；3 开口朝左（左下几乎无墨）。
        let blD = regionDensity(grid: grid, width: blob.width, height: blob.height,
                                x0: 0, x1: blob.width / 2,
                                y0: blob.height * 2 / 3, y1: blob.height)
        // 3：两个向左的半圆，中间列密度高，右侧密度高。
        if midD > 0.35 && rightD > leftD {
            if blD < 0.10 { return Result(digit: 3, confidence: 0.75) }
            return Result(digit: 2, confidence: 0.65)
        }
        // 2：顶部弯+底部横，中间少，右上有笔画。
        if rightD > leftD || midD < 0.35 {
            return Result(digit: 2, confidence: 0.7)
        }
        // 默认。
        return Result(digit: 2, confidence: 0.5)
    }

    // MARK: - 特征提取辅助

    private static func makeGrid(_ blob: Blob) -> [[Bool]] {
        var grid = Array(repeating: Array(repeating: false, count: blob.width), count: blob.height)
        for (x, y) in blob.pixels where y < blob.height && x < blob.width {
            grid[y][x] = true
        }
        return grid
    }

    /// 计算封闭孔洞数（白像素被黑像素完全包围的区域）。
    /// 用"对白像素 flood fill，触及边界的为背景，未触及的为孔"。
    private static func countHoles(grid: [[Bool]], width: Int, height: Int) -> Int {
        guard height > 2 && width > 2 else { return 0 }
        // visitedWhite: 是否已访问的白像素
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        // 从边界白像素 flood fill，标记为"背景"（非孔）
        var stack = [(Int, Int)]()
        for x in 0..<width {
            if !grid[0][x] { stack.append((x, 0)) }
            if !grid[height-1][x] { stack.append((x, height-1)) }
        }
        for y in 0..<height {
            if !grid[y][0] { stack.append((0, y)) }
            if !grid[y][width-1] { stack.append((width-1, y)) }
        }
        while let (x, y) = stack.popLast() {
            if x < 0 || x >= width || y < 0 || y >= height { continue }
            if visited[y][x] || grid[y][x] { continue }
            visited[y][x] = true
            stack.append((x+1, y)); stack.append((x-1, y))
            stack.append((x, y+1)); stack.append((x, y-1))
        }
        // 未访问的白像素 = 孔。
        var holes = 0
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                if !grid[y][x] && !visited[y][x] {
                    holes += 1
                    // 标记同孔的像素避免重复计数。
                    var fillStack = [(x, y)]
                    while let (fx, fy) = fillStack.popLast() {
                        if fx < 0 || fx >= width || fy < 0 || fy >= height { continue }
                        if visited[fy][fx] || grid[fy][fx] { continue }
                        visited[fy][fx] = true
                        fillStack.append((fx+1, fy)); fillStack.append((fx-1, fy))
                        fillStack.append((fx, fy+1)); fillStack.append((fx, fy-1))
                    }
                }
            }
        }
        return holes
    }

    /// 某行范围内黑像素占比。
    private static func rowDensity(grid: [[Bool]], width: Int, height: Int,
                                    yStart: Int, yEnd: Int) -> Double {
        guard yEnd > yStart && width > 0 else { return 0 }
        var black = 0, total = 0
        for y in yStart..<min(yEnd, height) {
            for x in 0..<width {
                total += 1
                if grid[y][x] { black += 1 }
            }
        }
        return total > 0 ? Double(black) / Double(total) : 0
    }

    /// 某列范围内黑像素占比。
    private static func columnDensity(grid: [[Bool]], width: Int, height: Int,
                                       xStart: Int, xEnd: Int) -> Double {
        guard xEnd > xStart && height > 0 else { return 0 }
        var black = 0, total = 0
        for y in 0..<height {
            for x in xStart..<min(xEnd, width) {
                total += 1
                if grid[y][x] { black += 1 }
            }
        }
        return total > 0 ? Double(black) / Double(total) : 0
    }

    /// 每列"单段连续黑"的占比(衡量是否为单一竖笔画;"1"接近 1.0)。
    private static func stemPurity(grid: [[Bool]], width: Int, height: Int) -> Double {
        guard width > 0, height > 0 else { return 0 }
        var cols = 0
        var single = 0
        for x in 0..<width {
            var runs = 0
            var inRun = false
            for y in 0..<height {
                if grid[y][x] {
                    if !inRun { runs += 1; inRun = true }
                } else {
                    inRun = false
                }
            }
            if runs > 0 {
                cols += 1
                if runs == 1 { single += 1 }
            }
        }
        return cols > 0 ? Double(single) / Double(cols) : 0
    }

    /// 任意矩形区域的黑像素占比(y 向下,越界自动裁剪)。
    private static func regionDensity(grid: [[Bool]], width: Int, height: Int,
                                      x0: Int, x1: Int, y0: Int, y1: Int) -> Double {
        let xs = max(0, x0)..<min(width, max(0, x1))
        let ys = max(0, y0)..<min(height, max(0, y1))
        guard !xs.isEmpty, !ys.isEmpty else { return 0 }
        var black = 0
        for y in ys {
            for x in xs where grid[y][x] { black += 1 }
        }
        return Double(black) / Double(xs.count * ys.count)
    }
}
