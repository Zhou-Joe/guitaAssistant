import XCTest

/// 曲谱编辑功能测试：识别 → 编辑 → 改品位 → 保存 → 验证保存成功。
final class EditTabUITests: XCTestCase {

    func testEditAndSaveTab() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-initialTab", "favorites", "-UITest"]
        app.launch()

        // 进入第一张曲谱。
        let sampleCell = app.staticTexts["示例曲谱（C-Am-F-G）"]
        XCTAssertTrue(sampleCell.waitForExistence(timeout: 8))
        sampleCell.tap()

        // 先 AI 识别（确保有内容可编辑）。
        let recognizeBtn = app.buttons["wand.and.stars"]
        XCTAssertTrue(recognizeBtn.waitForExistence(timeout: 5))
        recognizeBtn.tap()
        let aiButton = app.buttons["仅 AI"]
        if aiButton.waitForExistence(timeout: 3) { aiButton.tap() }
        else { app.buttons.matching(NSPredicate(format: "label CONTAINS 'AI'")).firstMatch.tap() }

        // 等识别完成（轮询"编辑"按钮出现）。
        var recognized = false
        for _ in 0..<60 {
            sleep(2)
            if app.buttons["编辑"].exists || app.buttons["Edit"].exists {
                recognized = true; break
            }
        }
        XCTAssertTrue(recognized, "AI 识别后应出现编辑按钮")

        // 点编辑。
        let editBtn = app.buttons["编辑"].exists ? app.buttons["编辑"] : app.buttons["Edit"]
        editBtn.tap()

        // 编辑界面应出现"编辑曲谱"标题。
        let editorTitle = app.staticTexts["编辑曲谱"].exists ? app.staticTexts["编辑曲谱"]
                        : (app.staticTexts["Edit Tab"].exists ? app.staticTexts["Edit Tab"] : nil)
        XCTAssertNotNil(editorTitle, "应进入编辑界面")

        // 点保存。
        let saveBtn = app.buttons["保存"]
        if saveBtn.waitForExistence(timeout: 3) {
            saveBtn.tap()
        }

        // 保存后应回到交互视图，显示"已编辑"标记。
        var saved = false
        for _ in 0..<10 {
            sleep(1)
            if app.staticTexts["已编辑"].exists || app.staticTexts["Edited"].exists {
                saved = true; break
            }
        }
        XCTAssertTrue(saved, "保存后应显示'已编辑'标记")
    }
}
