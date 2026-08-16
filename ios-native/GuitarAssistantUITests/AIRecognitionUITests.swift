import XCTest

/// AI 识别流程 UI 测试：进入示例曲谱 → 点识别 → 选 AI → 验证交互视图出现且含和弦。
final class AIRecognitionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testRecognizeSampleTabWithAI() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-initialTab", "favorites", "-UITest"]
        app.launch()

        // 进入示例曲谱。
        let sampleCell = app.staticTexts["示例曲谱（C-Am-F-G）"]
        XCTAssertTrue(sampleCell.waitForExistence(timeout: 8))
        sampleCell.tap()

        // 点识别按钮。
        let recognizeBtn = app.buttons["wand.and.stars"]
        XCTAssertTrue(recognizeBtn.waitForExistence(timeout: 5))
        recognizeBtn.tap()

        // 选 AI 模式。
        let aiButton = app.buttons["仅 AI"]
        if !aiButton.waitForExistence(timeout: 3) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'AI'")).firstMatch.tap()
        } else {
            aiButton.tap()
        }

        // AI 识别需要较长时间（推理模型），轮询等待识别结果出现。
        // 用手动轮询而非谓词期望（XCTNSPredicateExpectation 不会在 UI 变化时重新评估）。
        var recognized = false
        for _ in 0..<60 {   // 最多等 120 秒（每 2 秒查一次）
            sleep(2)
            let texts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
            if texts.contains(where: { $0.contains("置信度") || $0.contains("Confidence") }) {
                recognized = true
                break
            }
        }
        // 打印最终屏幕文本，无论成败都留证据。
        let finalTexts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        print("🔍 [诊断] 最终屏幕文本: \(finalTexts)")
        XCTAssertTrue(recognized, "AI 识别后应显示置信度")

        // 截图。
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AI识别结果"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
