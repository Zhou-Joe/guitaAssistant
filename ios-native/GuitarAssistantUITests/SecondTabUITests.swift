import XCTest

/// 验证第二张曲谱（G-Em-C-D）出现并 AI 识别。
final class SecondTabUITests: XCTestCase {

    func testSecondTabRecognized() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-initialTab", "favorites", "-UITest"]
        app.launch()

        // 应有两张曲谱。
        let tab1 = app.staticTexts["示例曲谱（C-Am-F-G）"]
        let tab2 = app.staticTexts["示例曲谱（G-Em-C-D）"]
        XCTAssertTrue(tab2.waitForExistence(timeout: 8), "应有第二张曲谱 G-Em-C-D")

        // 进入第二张。
        tab2.tap()

        // 点识别。
        let recognizeBtn = app.buttons["wand.and.stars"]
        XCTAssertTrue(recognizeBtn.waitForExistence(timeout: 5))
        recognizeBtn.tap()

        // 选 AI。
        let aiButton = app.buttons["仅 AI"]
        if aiButton.waitForExistence(timeout: 3) { aiButton.tap() }
        else { app.buttons.matching(NSPredicate(format: "label CONTAINS 'AI'")).firstMatch.tap() }

        // 轮询等待识别结果（最长 120s）。
        var recognized = false
        for _ in 0..<60 {
            sleep(2)
            let texts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
            if texts.contains(where: { $0.contains("置信度") || $0.contains("Confidence") }) {
                recognized = true
                break
            }
        }
        let finalTexts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        print("🔍 [第二张曲谱 AI 识别结果] \(finalTexts)")
        XCTAssertTrue(recognized, "G-Em-C-D AI 识别应成功")
    }
}
