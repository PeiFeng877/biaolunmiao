//
//  BianLunMiaoUITests.swift
//  BianLunMiaoUITests
//
//  Created by Icarus on 2026/2/3.
//  Updated by Codex on 2026/2/18.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 应用可交互界面与启动行为。
//  OUTPUT: UI 流程断言与性能采样结果。
//  POS: UI 自动化测试入口层。
//

import XCTest

final class BianLunMiaoUITests: XCTestCase {
    private let uiTimeout: TimeInterval = 20

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

        let tournamentTab = app.tabBars.buttons["赛事"]
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
    func testMessageTabShowsFlatFeedAndCanOpenJoinRequestDetail() throws {
        let app = XCUIApplication()
        app.launch()

        let messageTab = app.tabBars.buttons["消息"]
        XCTAssertTrue(messageTab.waitForExistence(timeout: 3))
        messageTab.tap()

        let mySegmented = app.segmentedControls["my_hub_segmented"]
        XCTAssertFalse(mySegmented.exists)

        let messageFeed = app.scrollViews["message_feed_scroll"]
        XCTAssertTrue(messageFeed.waitForExistence(timeout: 3))

        let joinRequestCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "message_card_join_request_")
        ).firstMatch
        XCTAssertTrue(joinRequestCard.waitForExistence(timeout: 3))
        joinRequestCard.tap()

        XCTAssertTrue(app.navigationBars["消息详情"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMySettingsCanEditNickname() throws {
        let app = XCUIApplication()
        app.launch()

        let myTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(myTab.waitForExistence(timeout: 3))
        myTab.tap()

        let editButton = app.buttons["my_edit_profile_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let nicknameInput = app.textFields["profile_nickname_input"]
        XCTAssertTrue(nicknameInput.waitForExistence(timeout: 3))
        nicknameInput.clearAndTypeText("UI测试昵称")

        let saveButton = app.buttons["profile_edit_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["UI测试昵称"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMyMorePageShowsUnifiedInfoAndPolicies() throws {
        let app = XCUIApplication()
        app.launch()

        let myTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(myTab.waitForExistence(timeout: 3))
        myTab.tap()

        let moreButton = app.buttons["my_more_button"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 3))
        moreButton.tap()

        XCTAssertTrue(app.navigationBars["更多"].waitForExistence(timeout: 3))
        let moreList = app.descendants(matching: .any).matching(identifier: "my_more_list").firstMatch
        XCTAssertTrue(moreList.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["当前版本"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["用户协议"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["隐私政策"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.buttons["my_more_row_user_agreement"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["my_more_row_privacy_policy"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testScheduleMonthToDayDetailAndSourceManagement() throws {
        let app = XCUIApplication()
        app.launch()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(scheduleTab.waitForExistence(timeout: uiTimeout))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(todayFab.waitForExistence(timeout: uiTimeout))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if todayCell.waitForExistence(timeout: uiTimeout) {
            todayCell.tap()
        } else {
            let fallbackDayCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_day_cell_")).firstMatch
            XCTAssertTrue(fallbackDayCell.waitForExistence(timeout: uiTimeout))
            fallbackDayCell.tap()
        }

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(dayDetailRoot.waitForExistence(timeout: uiTimeout))

        let sourceFab = app.descendants(matching: .any).matching(identifier: "schedule_source_fab").firstMatch
        if sourceFab.waitForExistence(timeout: uiTimeout) {
            sourceFab.tap()
        } else {
            let backButton = app.buttons["schedule_day_detail_back"]
            if backButton.waitForExistence(timeout: 5) {
                backButton.tap()
            }
            let fallbackSourceFab = app.descendants(matching: .any).matching(identifier: "schedule_source_fab").firstMatch
            XCTAssertTrue(fallbackSourceFab.waitForExistence(timeout: uiTimeout))
            fallbackSourceFab.tap()
        }

        let sourceTabs = app.segmentedControls["schedule_source_tab_segmented"]
        XCTAssertTrue(sourceTabs.waitForExistence(timeout: uiTimeout))
        sourceTabs.buttons["队伍"].tap()

        let addButton = app.buttons["schedule_source_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: uiTimeout))
        addButton.tap()

        let searchInput = app.textFields["schedule_source_picker_search_input"]
        XCTAssertTrue(searchInput.waitForExistence(timeout: uiTimeout))
        searchInput.tap()
        searchInput.typeText("1001")

        let pickerAddButton = app.buttons["schedule_source_picker_add_button"].firstMatch
        XCTAssertTrue(pickerAddButton.waitForExistence(timeout: uiTimeout))
    }

    @MainActor
    func testScheduleSyncSheetSelectionAndScroll() throws {
        let app = XCUIApplication()
        app.launch()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(scheduleTab.waitForExistence(timeout: uiTimeout))
        scheduleTab.tap()

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(syncFab.waitForExistence(timeout: uiTimeout))
        syncFab.tap()

        let sheet = app.otherElements["schedule_sync_sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: uiTimeout))

        let selectAllButton = app.buttons["schedule_sync_select_all_button"]
        XCTAssertTrue(selectAllButton.waitForExistence(timeout: uiTimeout))

        let confirmButton = app.buttons["schedule_sync_confirm_button"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiTimeout))

        // 取消全选后，同步按钮应禁用
        selectAllButton.tap()
        XCTAssertFalse(confirmButton.isEnabled)

        // 再次全选，同步按钮恢复可用
        selectAllButton.tap()
        XCTAssertTrue(confirmButton.isEnabled)

        let firstMatchToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "schedule_sync_match_toggle_")
        ).firstMatch
        XCTAssertTrue(firstMatchToggle.waitForExistence(timeout: uiTimeout))

        let previousValue = (firstMatchToggle.value as? String) ?? ""
        firstMatchToggle.tap()
        let updatedValue = (firstMatchToggle.value as? String) ?? ""
        XCTAssertNotEqual(previousValue, updatedValue)

        let syncScrollView = app.scrollViews["schedule_sync_scroll"]
        XCTAssertTrue(syncScrollView.waitForExistence(timeout: uiTimeout))
        syncScrollView.swipeUp()
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiTimeout))
        syncScrollView.swipeDown()
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiTimeout))
    }

    @MainActor
    func testScheduleTodayAndWeekTimelineSwipe() throws {
        let app = XCUIApplication()
        app.launch()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(scheduleTab.waitForExistence(timeout: uiTimeout))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(todayFab.waitForExistence(timeout: uiTimeout))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if todayCell.waitForExistence(timeout: uiTimeout) {
            todayCell.tap()
        } else {
            let fallbackDayCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_day_cell_")).firstMatch
            XCTAssertTrue(fallbackDayCell.waitForExistence(timeout: uiTimeout))
            fallbackDayCell.tap()
        }

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(dayDetailRoot.waitForExistence(timeout: uiTimeout))

        let dayDetailTopBar = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_topbar").firstMatch
        XCTAssertTrue(dayDetailTopBar.waitForExistence(timeout: uiTimeout))
        let selectedDayBeforeWeekSwipe = app.selectedWeekDayIdentifier()

        let weekPager = app.otherElements["schedule_week_pager"]
        XCTAssertTrue(weekPager.waitForExistence(timeout: uiTimeout))
        weekPager.swipeLeft()
        let selectedDayAfterWeekSwipe = app.selectedWeekDayIdentifier()
        XCTAssertNotEqual(selectedDayBeforeWeekSwipe, selectedDayAfterWeekSwipe)

        let timeline = app.scrollViews["schedule_timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: uiTimeout))
        timeline.swipeLeft()
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

        XCTAssertTrue(selectedDay.waitForExistence(timeout: 20))
        return selectedDay.identifier
    }
}
