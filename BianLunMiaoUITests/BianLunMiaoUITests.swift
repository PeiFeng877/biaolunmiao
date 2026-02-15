//
//  BianLunMiaoUITests.swift
//  BianLunMiaoUITests
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 应用可交互界面与启动行为。
//  OUTPUT: UI 流程断言与性能采样结果。
//  POS: UI 自动化测试入口层。
//

import XCTest

final class BianLunMiaoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testTournamentFlowFromListToMatchCreation() throws {
        let app = XCUIApplication()
        app.launch()

        let tournamentTab = app.tabBars.buttons["trophy"]
        XCTAssertTrue(tournamentTab.waitForExistence(timeout: 3))
        tournamentTab.tap()

        let addButton = app.buttons["tournament_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let nameInput = app.textFields["tournament_create_name_input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 3))
        nameInput.tap()
        nameInput.typeText("UI自动化闭环赛")

        let createSubmit = app.buttons["tournament_create_submit"]
        XCTAssertTrue(createSubmit.waitForExistence(timeout: 3))
        createSubmit.tap()

        let addMatchButton = app.buttons["tournament_add_match_fab"]
        XCTAssertTrue(addMatchButton.waitForExistence(timeout: 5))
        addMatchButton.tap()

        let matchNameInput = app.textFields["match_editor_name_input"]
        XCTAssertTrue(matchNameInput.waitForExistence(timeout: 3))
        matchNameInput.tap()
        matchNameInput.typeText("自动化创建场次")

        let saveMatchButton = app.buttons["match_editor_save_button"]
        XCTAssertTrue(saveMatchButton.waitForExistence(timeout: 3))
        saveMatchButton.tap()

        XCTAssertTrue(app.staticTexts["自动化创建场次"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testMyTabDefaultsToMessageAndCanAcknowledgeNotification() throws {
        let app = XCUIApplication()
        app.launch()

        let myTab = app.tabBars.buttons["person.text.rectangle"]
        XCTAssertTrue(myTab.waitForExistence(timeout: 3))
        myTab.tap()

        let mySegmented = app.segmentedControls["my_hub_segmented"]
        XCTAssertTrue(mySegmented.waitForExistence(timeout: 3))
        XCTAssertTrue(mySegmented.buttons["消息"].exists)

        let notificationButton = app.buttons["通知"].firstMatch
        XCTAssertTrue(notificationButton.waitForExistence(timeout: 3))
        notificationButton.tap()

        let confirmButton = app.buttons["消息确认"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()

        XCTAssertTrue(app.staticTexts["已确认"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMySettingsCanEditNickname() throws {
        let app = XCUIApplication()
        app.launch()

        let myTab = app.tabBars.buttons["person.text.rectangle"]
        XCTAssertTrue(myTab.waitForExistence(timeout: 3))
        myTab.tap()

        let settingsSegmentButton = app.buttons["设置"].firstMatch
        XCTAssertTrue(settingsSegmentButton.waitForExistence(timeout: 3))
        settingsSegmentButton.tap()

        let editButton = app.buttons["编辑资料"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let nicknameInput = app.textFields["profile_nickname_input"]
        XCTAssertTrue(nicknameInput.waitForExistence(timeout: 3))
        nicknameInput.clearAndTypeText("UI测试昵称")

        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["UI测试昵称"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testScheduleMonthToDayDetailAndSourceManagement() throws {
        let app = XCUIApplication()
        app.launch()

        let scheduleTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(scheduleTab.waitForExistence(timeout: 3))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(todayFab.waitForExistence(timeout: 3))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if todayCell.waitForExistence(timeout: 3) {
            todayCell.tap()
        } else {
            let fallbackDayCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_day_cell_")).firstMatch
            XCTAssertTrue(fallbackDayCell.waitForExistence(timeout: 3))
            fallbackDayCell.tap()
        }

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(dayDetailRoot.waitForExistence(timeout: 3))

        let sourceFab = app.buttons["schedule_source_fab"]
        XCTAssertTrue(sourceFab.waitForExistence(timeout: 3))
        sourceFab.tap()

        let sourceTabs = app.segmentedControls["schedule_source_tab_segmented"]
        XCTAssertTrue(sourceTabs.waitForExistence(timeout: 3))
        sourceTabs.buttons["队伍"].tap()

        let addButton = app.buttons["schedule_source_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let searchInput = app.textFields["schedule_source_picker_search_input"]
        XCTAssertTrue(searchInput.waitForExistence(timeout: 3))
        searchInput.tap()
        searchInput.typeText("1001")

        let pickerAddButton = app.buttons["schedule_source_picker_add_button"].firstMatch
        XCTAssertTrue(pickerAddButton.waitForExistence(timeout: 3))
    }

    @MainActor
    func testScheduleSyncSheetSelectionAndScroll() throws {
        let app = XCUIApplication()
        app.launch()

        let scheduleTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(scheduleTab.waitForExistence(timeout: 3))
        scheduleTab.tap()

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(syncFab.waitForExistence(timeout: 3))
        syncFab.tap()

        let sheet = app.otherElements["schedule_sync_sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))

        let selectAllButton = app.buttons["schedule_sync_select_all_button"]
        XCTAssertTrue(selectAllButton.waitForExistence(timeout: 3))

        let confirmButton = app.buttons["schedule_sync_confirm_button"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))

        // 取消全选后，同步按钮应禁用
        selectAllButton.tap()
        XCTAssertFalse(confirmButton.isEnabled)

        // 再次全选，同步按钮恢复可用
        selectAllButton.tap()
        XCTAssertTrue(confirmButton.isEnabled)

        let firstMatchToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "schedule_sync_match_toggle_")
        ).firstMatch
        XCTAssertTrue(firstMatchToggle.waitForExistence(timeout: 3))

        let previousValue = (firstMatchToggle.value as? String) ?? ""
        firstMatchToggle.tap()
        let updatedValue = (firstMatchToggle.value as? String) ?? ""
        XCTAssertNotEqual(previousValue, updatedValue)

        let syncScrollView = app.scrollViews["schedule_sync_scroll"]
        XCTAssertTrue(syncScrollView.waitForExistence(timeout: 3))
        syncScrollView.swipeUp()
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        syncScrollView.swipeDown()
        XCTAssertTrue(confirmButton.isHittable)
    }

    @MainActor
    func testScheduleTodayAndWeekTimelineSwipe() throws {
        let app = XCUIApplication()
        app.launch()

        let scheduleTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(scheduleTab.waitForExistence(timeout: 3))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(todayFab.waitForExistence(timeout: 3))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        XCTAssertTrue(todayCell.waitForExistence(timeout: 3))
        todayCell.tap()

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(dayDetailRoot.waitForExistence(timeout: 3))

        let dayLabel = app.staticTexts["schedule_day_detail_date"]
        XCTAssertTrue(dayLabel.waitForExistence(timeout: 3))
        let selectedDayBeforeWeekSwipe = app.selectedWeekDayIdentifier()

        let weekPager = app.otherElements["schedule_week_pager"]
        XCTAssertTrue(weekPager.waitForExistence(timeout: 3))
        weekPager.swipeLeft()
        XCTAssertTrue(dayLabel.waitForExistence(timeout: 3))
        let selectedDayAfterWeekSwipe = app.selectedWeekDayIdentifier()
        XCTAssertNotEqual(selectedDayBeforeWeekSwipe, selectedDayAfterWeekSwipe)

        let timeline = app.scrollViews["schedule_timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 3))
        timeline.swipeLeft()
        XCTAssertTrue(dayLabel.waitForExistence(timeout: 3))
        let selectedDayAfterTimelineSwipe = app.selectedWeekDayIdentifier()
        XCTAssertNotEqual(selectedDayAfterWeekSwipe, selectedDayAfterTimelineSwipe)
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()

        let currentValue = (value as? String) ?? ""
        guard !currentValue.isEmpty else {
            typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
        typeText(text)
    }
}

private extension XCUIApplication {
    func selectedWeekDayIdentifier() -> String {
        let selectedDay = buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "schedule_week_day_", "selected")
        ).firstMatch

        XCTAssertTrue(selectedDay.waitForExistence(timeout: 3))
        return selectedDay.identifier
    }
}
