import XCTest

/// 录音流程 UI 测试。
/// 验证修复后的三态控制条 + 保存链路：开始录音 → 停止保存 → 列表生成新记录。
final class RecordingUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testRecordStopCreatesEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-initialTab", "settings", "-UITest"]
        app.launch()

        // 进入录音页。
        let entry = app.buttons["recordingEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8), "设置页应有录音入口")
        entry.tap()

        // 主按钮（空闲态 = 开始）。
        let toggle = app.buttons["recordToggleButton"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "录音主按钮应存在")
        toggle.tap()   // 开始录制

        // 录制 2 秒。
        sleep(2)

        // 停止保存按钮（录制中显示）。
        let stop = app.buttons["stopSaveButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3), "录制中应显示停止保存按钮")
        stop.tap()

        // 列表应出现一条新记录（时长格式 m:ss）。
        let duration = app.staticTextsmatchingFormat() // 见下方扩展
        XCTAssertTrue(duration.waitForExistence(timeout: 5), "停止保存后应生成一条录音记录")
    }
}

private extension XCUIElementQuery {
    /// 匹配 m:ss 格式的时长文本。
    var durationText: XCUIElement {
        staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d+:\\d{2}$")).firstMatch
    }
}

private extension XCUIApplication {
    func staticTextsmatchingFormat() -> XCUIElement {
        staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d+:\\d{2}$")).firstMatch
    }
}
