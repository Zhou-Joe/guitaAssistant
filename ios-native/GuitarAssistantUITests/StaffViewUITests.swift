import XCTest

/// 截图六线谱视图：识别 → 切换 staff 视图 → 截图。
final class StaffViewUITests: XCTestCase {

    func testStaffViewScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-initialTab", "favorites", "-UITest"]
        app.launch()

        // 进入第二张曲谱（G-Em-C-D）。
        let sampleCell = app.staticTexts["示例曲谱（G-Em-C-D）"]
        XCTAssertTrue(sampleCell.waitForExistence(timeout: 8))
        sampleCell.tap()

        // AI 识别。
        let recognizeBtn = app.buttons["wand.and.stars"]
        XCTAssertTrue(recognizeBtn.waitForExistence(timeout: 5))
        recognizeBtn.tap()
        let aiButton = app.buttons["仅 AI"]
        if aiButton.waitForExistence(timeout: 3) { aiButton.tap() }
        else { app.buttons.matching(NSPredicate(format: "label CONTAINS 'AI'")).firstMatch.tap() }

        // 等识别完成（轮询"六线谱"或"卡片"切换器出现）。
        var recognized = false
        for _ in 0..<60 {
            sleep(2)
            if app.buttons["六线谱"].exists || app.buttons["Staff"].exists {
                recognized = true; break
            }
        }
        XCTAssertTrue(recognized, "识别后应出现视图切换器")

        // 切换到六线谱视图。
        let staffBtn = app.buttons["六线谱"].exists ? app.buttons["六线谱"] : app.buttons["Staff"]
        staffBtn.tap()
        sleep(2)

        // 截图。
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "六线谱视图"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
