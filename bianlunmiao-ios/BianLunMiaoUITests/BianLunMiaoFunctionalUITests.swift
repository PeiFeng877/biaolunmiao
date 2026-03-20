//
//  BianLunMiaoFunctionalUITests.swift
//  BianLunMiaoUITests
//
//  Updated by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 本地模拟器 + Mock 数据的功能回归链路。
//  OUTPUT: 队伍、赛事、日程、消息、我的等长链路功能断言。
//  POS: UI 自动化-full-local functional lane。
//

import XCTest

final class BianLunMiaoFunctionalUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try allowExecutionLanes([.fullLocal])
    }

    @MainActor
    func testTeamSearchCanReachJoinEntry() throws {
        let app = launchMockApp()

        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team"))
        teamTab.tap()

        let searchButton = app.buttons["team_search_button"]
        XCTAssertTrue(waitForElement(searchButton, in: app, identifier: "team_search_button"))
        searchButton.tap()

        let searchRoot = app.descendants(matching: .any).matching(identifier: "team_search_root").firstMatch
        XCTAssertTrue(waitForElement(searchRoot, in: app, identifier: "team_search_root"))

        let searchField = app.textFields.firstMatch
        XCTAssertTrue(waitForElement(searchField, in: app, identifier: "team search field"))
        searchField.tap()
        searchField.typeText("1003")

        let joinButton = app.buttons["申请入队"].firstMatch
        XCTAssertTrue(waitForElement(joinButton, in: app, identifier: "申请入队"))
    }

    @MainActor
    func testTeamSearchSubmitJoinRequestClosesSheetAndKeepsAppUsable() throws {
        let app = launchMockApp()

        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team"))
        teamTab.tap()

        let searchButton = app.buttons["team_search_button"]
        XCTAssertTrue(waitForElement(searchButton, in: app, identifier: "team_search_button"))
        searchButton.tap()

        let searchField = app.textFields.firstMatch
        XCTAssertTrue(waitForElement(searchField, in: app, identifier: "team search field"))
        searchField.tap()
        searchField.typeText("1003")

        let joinButton = app.buttons["申请入队"].firstMatch
        XCTAssertTrue(waitForElement(joinButton, in: app, identifier: "申请入队"))
        joinButton.tap()

        let joinSheet = app.descendants(matching: .any).matching(identifier: "team_join_application_sheet_root").firstMatch
        XCTAssertTrue(waitForElement(joinSheet, in: app, identifier: "team_join_application_sheet_root"))

        let submitButton = app.buttons["提交申请"]
        XCTAssertTrue(waitForElement(submitButton, in: app, identifier: "提交申请"))
        submitButton.tap()

        let dismissExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: joinSheet
        )
        XCTAssertEqual(XCTWaiter().wait(for: [dismissExpectation], timeout: 8), .completed)

        let messageTab = tabButton(in: app, tab: .message)
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "main_tab_message"))

        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my"))
    }

    @MainActor
    func testTournamentFlowFromListToMatchCreation() throws {
        let app = launchMockApp()

        let tournamentTab = tabButton(in: app, tab: .tournament)
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "main_tab_tournament"))
        tournamentTab.tap()

        let addButton = app.buttons["tournament_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "tournament_add_button", timeout: 5))
        addButton.tap()

        let nameInput = app.textFields["tournament_create_name_input"]
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "tournament_create_name_input", timeout: 5))
        nameInput.tap()
        nameInput.typeText("UI自动化闭环赛")

        let createSubmit = app.buttons["tournament_create_submit"]
        XCTAssertTrue(waitForElement(createSubmit, in: app, identifier: "tournament_create_submit", timeout: 5))
        createSubmit.tap()

        let tournamentDetailRoot = app.descendants(matching: .any).matching(identifier: "tournament_detail_root").firstMatch
        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))

        let addMatchButton = app.buttons["tournament_add_match_fab"]
        XCTAssertTrue(waitForElement(addMatchButton, in: app, identifier: "tournament_add_match_fab", timeout: 5))
        addMatchButton.tap()

        let matchNameInput = app.textFields["match_editor_name_input"]
        XCTAssertTrue(waitForElement(matchNameInput, in: app, identifier: "match_editor_name_input", timeout: 5))
        matchNameInput.tap()
        matchNameInput.typeText("自动化创建场次")

        let saveMatchButton = app.buttons["match_editor_save_button"]
        XCTAssertTrue(waitForElement(saveMatchButton, in: app, identifier: "match_editor_save_button", timeout: 5))
        saveMatchButton.tap()

        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts["自动化创建场次"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTournamentDetailCanEditAndSaveTournamentInfo() throws {
        let app = launchMockApp()

        let tournamentTab = tabButton(in: app, tab: .tournament)
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "main_tab_tournament"))
        tournamentTab.tap()

        let addButton = app.buttons["tournament_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "tournament_add_button", timeout: 5))
        addButton.tap()

        let nameInput = app.textFields["tournament_create_name_input"]
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "tournament_create_name_input", timeout: 5))
        nameInput.tap()
        nameInput.typeText("待编辑赛事")

        let createSubmit = app.buttons["tournament_create_submit"]
        XCTAssertTrue(waitForElement(createSubmit, in: app, identifier: "tournament_create_submit", timeout: 5))
        createSubmit.tap()

        let tournamentDetailRoot = app.descendants(matching: .any).matching(identifier: "tournament_detail_root").firstMatch
        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))

        let editButton = app.buttons["tournament_detail_edit_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "tournament_detail_edit_button"))
        editButton.tap()

        let editNameInput = app.textFields["tournament_edit_name_input"]
        XCTAssertTrue(waitForElement(editNameInput, in: app, identifier: "tournament_edit_name_input"))
        editNameInput.clearAndTypeText("已编辑赛事")

        let editIntroInput = app.textViews["tournament_edit_intro_input"]
        XCTAssertTrue(waitForElement(editIntroInput, in: app, identifier: "tournament_edit_intro_input"))
        editIntroInput.clearAndTypeText("这是更新后的赛事简介")

        let saveButton = app.buttons["tournament_edit_save_button"]
        tapButtonHandlingKeyboard(saveButton, in: app, identifier: "tournament_edit_save_button")

        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts["已编辑赛事"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["这是更新后的赛事简介"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMessageTabShowsFlatFeedAndCanOpenJoinRequestDetail() throws {
        let app = launchMockApp()

        let messageTab = tabButton(in: app, tab: .message)
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "main_tab_message"))
        messageTab.tap()

        let mySegmented = app.segmentedControls["my_hub_segmented"]
        XCTAssertFalse(mySegmented.exists)

        let messageFeed = app.scrollViews["message_feed_scroll"]
        XCTAssertTrue(waitForElement(messageFeed, in: app, identifier: "message_feed_scroll"))

        let joinRequestCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "message_card_join_request_")
        ).firstMatch
        XCTAssertTrue(waitForElement(joinRequestCard, in: app, identifier: "message_card_join_request_*"))
        joinRequestCard.tap()

        let messageDetailRoot = app.descendants(matching: .any).matching(identifier: "message_detail_root").firstMatch
        XCTAssertTrue(waitForElement(messageDetailRoot, in: app, identifier: "message_detail_root"))
    }

    @MainActor
    func testMySettingsCanEditNickname() throws {
        let app = launchMockApp()

        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my"))
        myTab.tap()

        let editButton = app.buttons["my_edit_profile_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "my_edit_profile_button"))
        editButton.tap()

        let nicknameInput = app.textFields["profile_nickname_input"]
        XCTAssertTrue(waitForElement(nicknameInput, in: app, identifier: "profile_nickname_input"))
        nicknameInput.clearAndTypeText("UI测试昵称")

        let saveButton = app.buttons["profile_edit_save_button"]
        XCTAssertTrue(waitForElement(saveButton, in: app, identifier: "profile_edit_save_button"))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["UI测试昵称"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMyMorePageShowsUnifiedInfoAndPolicies() throws {
        let app = launchMockApp()

        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my"))
        myTab.tap()

        let moreButton = app.buttons["my_more_button"]
        XCTAssertTrue(waitForElement(moreButton, in: app, identifier: "my_more_button"))
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
        let app = launchMockApp()

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule"))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(waitForElement(todayFab, in: app, identifier: "schedule_today_fab"))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if waitForElement(todayCell, in: app, identifier: "schedule_day_cell_today", timeout: 6, recordFailure: false) {
            todayCell.tap()
        } else {
            let fallbackDayCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_day_cell_")).firstMatch
            XCTAssertTrue(
                waitForElement(
                    fallbackDayCell,
                    in: app,
                    identifier: "schedule_day_cell_*",
                    timeout: 6
                )
            )
            fallbackDayCell.tap()
        }

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(waitForElement(dayDetailRoot, in: app, identifier: "schedule_day_detail_root"))

        let dayDetailTopBar = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_topbar").firstMatch
        XCTAssertTrue(waitForElement(dayDetailTopBar, in: app, identifier: "schedule_day_detail_topbar"))

        app.terminate()

        let sourceApp = launchMockApp()
        let sourceScheduleTab = tabButton(in: sourceApp, tab: .schedule)
        XCTAssertTrue(waitForElement(sourceScheduleTab, in: sourceApp, identifier: "main_tab_schedule"))
        sourceScheduleTab.tap()

        let sourceEntryByIdentifier = sourceApp.descendants(matching: .any).matching(identifier: "schedule_source_fab").firstMatch
        let sourceEntry: XCUIElement
        if waitForElement(
            sourceEntryByIdentifier,
            in: sourceApp,
            identifier: "schedule_source_fab",
            timeout: 3,
            recordFailure: false
        ) {
            sourceEntry = sourceEntryByIdentifier
        } else {
            sourceEntry = sourceApp.buttons["管理订阅源"]
        }
        XCTAssertTrue(waitForElement(sourceEntry, in: sourceApp, identifier: "schedule_source entry", timeout: 8))
        sourceEntry.tap()

        let sourceTabs = sourceApp.segmentedControls["schedule_source_tab_segmented"]
        XCTAssertTrue(waitForElement(sourceTabs, in: sourceApp, identifier: "schedule_source_tab_segmented"))
        sourceTabs.buttons["队伍"].tap()

        let addButton = sourceApp.buttons["schedule_source_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: sourceApp, identifier: "schedule_source_add_button"))
        addButton.tap()

        let searchInput = sourceApp.textFields["schedule_source_picker_search_input"]
        XCTAssertTrue(waitForElement(searchInput, in: sourceApp, identifier: "schedule_source_picker_search_input"))
        searchInput.tap()
        searchInput.typeText("1001")

        let pickerAddButton = sourceApp.buttons["schedule_source_picker_add_button"].firstMatch
        XCTAssertTrue(waitForElement(pickerAddButton, in: sourceApp, identifier: "schedule_source_picker_add_button"))
    }

    @MainActor
    func testScheduleSyncSheetSelectionAndScroll() throws {
        let app = launchMockApp()

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule"))
        scheduleTab.tap()

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(waitForElement(syncFab, in: app, identifier: "schedule_sync_fab"))
        syncFab.tap()

        let sheet = app.descendants(matching: .any).matching(identifier: "schedule_sync_sheet").firstMatch
        XCTAssertTrue(waitForElement(sheet, in: app, identifier: "schedule_sync_sheet"))

        let selectAllButton = app.buttons["schedule_sync_select_all_button"]
        XCTAssertTrue(waitForElement(selectAllButton, in: app, identifier: "schedule_sync_select_all_button"))

        let confirmButton = app.buttons["schedule_sync_confirm_button"]
        XCTAssertTrue(waitForElement(confirmButton, in: app, identifier: "schedule_sync_confirm_button"))

        selectAllButton.tap()
        XCTAssertFalse(confirmButton.isEnabled)

        selectAllButton.tap()
        XCTAssertTrue(confirmButton.isEnabled)

        let firstMatchToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "schedule_sync_match_toggle_")
        ).firstMatch
        XCTAssertTrue(waitForElement(firstMatchToggle, in: app, identifier: "schedule_sync_match_toggle_*"))

        let previousValue = (firstMatchToggle.value as? String) ?? ""
        firstMatchToggle.tap()
        let updatedValue = (firstMatchToggle.value as? String) ?? ""
        XCTAssertNotEqual(previousValue, updatedValue)

        let syncScrollView = app.scrollViews["schedule_sync_scroll"]
        XCTAssertTrue(waitForElement(syncScrollView, in: app, identifier: "schedule_sync_scroll"))
        syncScrollView.swipeUp()
        XCTAssertTrue(waitForElement(confirmButton, in: app, identifier: "schedule_sync_confirm_button"))
        syncScrollView.swipeDown()
        XCTAssertTrue(waitForElement(confirmButton, in: app, identifier: "schedule_sync_confirm_button"))
    }

    @MainActor
    func testScheduleTodayAndWeekTimelineSwipe() throws {
        let app = launchMockApp()

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule"))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(waitForElement(todayFab, in: app, identifier: "schedule_today_fab"))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if waitForElement(todayCell, in: app, identifier: "schedule_day_cell_today", timeout: 6, recordFailure: false) {
            todayCell.tap()
        } else {
            let fallbackDayCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_day_cell_")).firstMatch
            XCTAssertTrue(
                waitForElement(
                    fallbackDayCell,
                    in: app,
                    identifier: "schedule_day_cell_*",
                    timeout: 6
                )
            )
            fallbackDayCell.tap()
        }

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(waitForElement(dayDetailRoot, in: app, identifier: "schedule_day_detail_root"))

        let dayDetailTopBar = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_topbar").firstMatch
        XCTAssertTrue(waitForElement(dayDetailTopBar, in: app, identifier: "schedule_day_detail_topbar"))
        let selectedDayBeforeWeekSwipe = selectedWeekDayIdentifier(in: app)

        let weekPagerByIdentifier = app.descendants(matching: .any).matching(identifier: "schedule_week_pager").firstMatch
        let weekPager: XCUIElement
        if waitForElement(
            weekPagerByIdentifier,
            in: app,
            identifier: "schedule_week_pager",
            timeout: 3,
            recordFailure: false
        ) {
            weekPager = weekPagerByIdentifier
        } else {
            weekPager = app.descendants(matching: .any).matching(identifier: "schedule_week_strip").firstMatch
        }
        XCTAssertTrue(waitForElement(weekPager, in: app, identifier: "schedule_week_pager or schedule_week_strip", timeout: 8))
        weekPager.swipeLeft()
        let selectedDayAfterWeekSwipe = selectedWeekDayIdentifier(in: app)
        XCTAssertNotEqual(selectedDayBeforeWeekSwipe, selectedDayAfterWeekSwipe)

        let timeline = app.scrollViews["schedule_timeline"]
        XCTAssertTrue(waitForElement(timeline, in: app, identifier: "schedule_timeline"))
        timeline.swipeLeft()
        let selectedDayAfterTimelineSwipe = selectedWeekDayIdentifier(in: app)
        XCTAssertNotEqual(selectedDayAfterWeekSwipe, selectedDayAfterTimelineSwipe)
    }

    @MainActor
    func testScheduleDarkModeDayDetailShowsFullDayTimeline() throws {
        let app = launchDarkMockApp()

        openScheduleDayDetail(in: app, dayCellIdentifier: "schedule_day_cell_today", allowFallbackDayCell: true)
        assertTimelineShowsFullDayRange(in: app)
    }

    @MainActor
    func testScheduleEmptyDayStillShowsFullDayTimeline() throws {
        let app = launchMockApp()
        let emptyDayCellIdentifier = scheduleDayCellIdentifier(daysFromToday: 3)

        openScheduleDayDetail(in: app, dayCellIdentifier: emptyDayCellIdentifier)
        assertTimelineShowsFullDayRange(in: app)
    }

    @MainActor
    func testScheduleOpensOnCurrentMonthWithoutTappingToday() throws {
        let app = launchMockApp()

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule"))
        scheduleTab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        XCTAssertTrue(waitForElement(todayCell, in: app, identifier: "schedule_day_cell_today", timeout: 8))
    }

    @MainActor
    private func openScheduleDayDetail(
        in app: XCUIApplication,
        dayCellIdentifier: String,
        allowFallbackDayCell: Bool = false
    ) {
        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule"))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(waitForElement(todayFab, in: app, identifier: "schedule_today_fab"))
        todayFab.tap()

        let targetDayCell = app.buttons[dayCellIdentifier]
        if waitForElement(targetDayCell, in: app, identifier: dayCellIdentifier, timeout: 8, recordFailure: false) {
            targetDayCell.tap()
        } else if allowFallbackDayCell {
            let fallbackDayCell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_day_cell_")).firstMatch
            XCTAssertTrue(waitForElement(fallbackDayCell, in: app, identifier: "schedule_day_cell_*", timeout: 8))
            fallbackDayCell.tap()
        } else {
            XCTFail("无法找到目标日期 cell: \(dayCellIdentifier)")
            return
        }

        let dayDetailRoot = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_root").firstMatch
        XCTAssertTrue(waitForElement(dayDetailRoot, in: app, identifier: "schedule_day_detail_root"))

        let dayDetailTopBar = app.descendants(matching: .any).matching(identifier: "schedule_day_detail_topbar").firstMatch
        XCTAssertTrue(waitForElement(dayDetailTopBar, in: app, identifier: "schedule_day_detail_topbar"))
    }

    @MainActor
    private func assertTimelineShowsFullDayRange(in app: XCUIApplication) {
        let timeline = app.scrollViews["schedule_timeline"]
        XCTAssertTrue(waitForElement(timeline, in: app, identifier: "schedule_timeline"))

        let startHour = app.descendants(matching: .any).matching(identifier: "schedule_timeline_hour_00").firstMatch
        XCTAssertTrue(waitForElement(startHour, in: app, identifier: "schedule_timeline_hour_00"))

        let endcap = app.descendants(matching: .any).matching(identifier: "schedule_timeline_hour_24_endcap").firstMatch
        XCTAssertTrue(waitForElement(endcap, in: app, identifier: "schedule_timeline_hour_24_endcap"))
    }

    private func scheduleDayCellIdentifier(daysFromToday: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.dateFormat = "yyyyMMdd"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .day, value: daysFromToday, to: today) ?? today
        return "schedule_day_cell_\(formatter.string(from: targetDate))"
    }
}
