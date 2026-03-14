//
//  BianLunMiaoUITests.swift
//  BianLunMiaoUITests
//
//  Created by Icarus on 2026/2/3.
//  Updated by Codex on 2026/2/18.
//  Updated by Codex on 2026/3/3.
//  Updated by Codex on 2026/3/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 应用可交互界面与启动行为。
//  OUTPUT: UI 流程断言与性能采样结果。
//  POS: UI 自动化测试入口层。
//

import XCTest

final class BianLunMiaoUITests: XCTestCase {
    private let uiTimeout: TimeInterval = 12
    private let uiPollInterval: TimeInterval = 1
    private let defaultRemoteBaseURL = "http://127.0.0.1:8000/api/v1"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        launchApp(useMockData: true)
    }

    @MainActor
    private func launchSignedOutApp() -> XCUIApplication {
        launchApp(useMockData: false)
    }

    @MainActor
    private func launchRemoteDebugApp() -> XCUIApplication {
        launchRemoteDebugApp(teamName: nil, teamSlogan: nil)
    }

    @MainActor
    private func launchRemoteDebugApp(teamName: String?, teamSlogan: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = "0"
        app.launchEnvironment["BLM_UI_TEST_ALLOW_REMOTE"] = "1"
        app.launchEnvironment["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] = "1"
        app.launchEnvironment["BLM_API_BASE_URL"] = remoteBaseURL()
        if let teamName {
            app.launchEnvironment["BLM_UI_TEST_TEAM_NAME"] = teamName
            app.launchEnvironment["BLM_UI_TEST_REMOTE_TEAM_CREATE"] = "1"
        }
        if let teamSlogan {
            app.launchEnvironment["BLM_UI_TEST_TEAM_SLOGAN"] = teamSlogan
        }
        app.launch()
        return app
    }

    private func remoteBaseURL() -> String {
        let env = ProcessInfo.processInfo.environment
        guard let value = env["BLM_TEST_REMOTE_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return defaultRemoteBaseURL
        }
        return value
    }

    @MainActor
    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        let keyboardButtons = [
            app.keyboards.buttons["Return"],
            app.keyboards.buttons["Done"],
            app.keyboards.buttons["完成"],
            app.keyboards.buttons["收起键盘"],
        ]

        for button in keyboardButtons where button.exists && button.isHittable {
            button.tap()
            return
        }

        let titleBar = app.navigationBars.firstMatch
        if titleBar.exists && titleBar.isHittable {
            titleBar.tap()
            return
        }

        app.tap()
    }

    @discardableResult
    @MainActor
    private func waitForKeyboardToDisappear(
        in app: XCUIApplication,
        timeout: TimeInterval = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "count == 0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.keyboards)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result == .completed {
            return true
        }

        attachFailureDiagnostics(app: app, identifier: "keyboard-still-present")
        XCTFail("Keyboard did not disappear within \(timeout)s", file: file, line: line)
        return false
    }

    @MainActor
    private func launchApp(useMockData: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = useMockData ? "1" : "0"
        app.launch()
        return app
    }

    @discardableResult
    @MainActor
    private func waitForElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval = 12,
        recordFailure: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if element.exists {
                return true
            }

            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                break
            }

            _ = element.waitForExistence(timeout: min(uiPollInterval, remaining))
            if element.exists {
                return true
            }
        }

        if recordFailure {
            attachFailureDiagnostics(app: app, identifier: identifier)
            XCTFail("Element '\(identifier)' did not appear within \(Int(timeout))s", file: file, line: line)
        }
        return false
    }

    @MainActor
    private func selectedWeekDayIdentifier(in app: XCUIApplication) -> String {
        let selectedDay = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "schedule_week_day_", "selected")
        ).firstMatch

        _ = waitForElement(
            selectedDay,
            in: app,
            identifier: "selected schedule week day",
            timeout: 8
        )
        return selectedDay.identifier
    }

    @MainActor
    private func attachFailureDiagnostics(app: XCUIApplication, identifier: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "failure-\(identifier)-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "failure-\(identifier)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    @MainActor
    private func attachAppStoreScreenshot(app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "appstore-\(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testExample() throws {
        _ = launchApp()
    }

    @MainActor
    func testAppleSignInButtonStartsAuthorizationFlow() throws {
        let app = launchSignedOutApp()

        let title = app.staticTexts["login_gate_title"]
        XCTAssertTrue(waitForElement(title, in: app, identifier: "login gate title"))

        let signInButton = app.buttons["auth_sign_in_with_apple_button"]
        XCTAssertTrue(waitForElement(signInButton, in: app, identifier: "auth_sign_in_with_apple_button"))

        let userAgreement = app.descendants(matching: .any).matching(identifier: "login_gate_user_agreement_link").firstMatch
        XCTAssertTrue(waitForElement(userAgreement, in: app, identifier: "login_gate_user_agreement_link"))

        let privacyPolicy = app.descendants(matching: .any).matching(identifier: "login_gate_privacy_policy_link").firstMatch
        XCTAssertTrue(waitForElement(privacyPolicy, in: app, identifier: "login_gate_privacy_policy_link"))

        let debugState = app.staticTexts["auth_debug_state"]
        XCTAssertTrue(waitForElement(debugState, in: app, identifier: "auth_debug_state"))
        XCTAssertEqual(debugState.label, "idle")

        signInButton.tap()

        let nonIdlePredicate = NSPredicate(format: "label != %@", "idle")
        expectation(for: nonIdlePredicate, evaluatedWith: debugState)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testAppleSignInButtonStartsAuthorizationFlowDirect() throws {
        let app = launchSignedOutApp()

        XCTAssertTrue(app.staticTexts["login_gate_title"].waitForExistence(timeout: 12))

        let signInButton = app.buttons["auth_sign_in_with_apple_button"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 12))

        let debugState = app.staticTexts["auth_debug_state"]
        XCTAssertTrue(debugState.waitForExistence(timeout: 12))
        XCTAssertEqual(debugState.label, "idle")
    }

    @MainActor
    func testAppStoreScreenshotPack() throws {
        let app = launchApp()

        let tournamentTab = app.tabBars.buttons["赛事"]
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "赛事 tab"))
        tournamentTab.tap()
        attachAppStoreScreenshot(app: app, name: "01_tournament_list")

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "日程 tab"))
        scheduleTab.tap()
        attachAppStoreScreenshot(app: app, name: "02_schedule_month")

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(waitForElement(syncFab, in: app, identifier: "schedule_sync_fab"))
        syncFab.tap()
        let syncSheet = app.descendants(matching: .any).matching(identifier: "schedule_sync_sheet").firstMatch
        XCTAssertTrue(waitForElement(syncSheet, in: app, identifier: "schedule_sync_sheet"))
        attachAppStoreScreenshot(app: app, name: "03_schedule_sync_sheet")
        syncSheet.swipeDown()

        let messageTab = app.tabBars.buttons["消息"]
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "消息 tab"))
        messageTab.tap()
        let messageFeed = app.scrollViews["message_feed_scroll"]
        XCTAssertTrue(waitForElement(messageFeed, in: app, identifier: "message_feed_scroll"))
        attachAppStoreScreenshot(app: app, name: "04_message_feed")

        let myTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "我的 tab"))
        myTab.tap()
        let editButton = app.buttons["my_edit_profile_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "my_edit_profile_button"))
        attachAppStoreScreenshot(app: app, name: "05_my_profile")

        let moreButton = app.buttons["my_more_button"]
        XCTAssertTrue(waitForElement(moreButton, in: app, identifier: "my_more_button"))
        moreButton.tap()
        let moreList = app.descendants(matching: .any).matching(identifier: "my_more_list").firstMatch
        XCTAssertTrue(waitForElement(moreList, in: app, identifier: "my_more_list"))
        attachAppStoreScreenshot(app: app, name: "06_my_more")
    }

    @MainActor
    func testRemoteDebugSessionCanReachMainTabs() throws {
        let app = launchRemoteDebugApp()

        let teamTab = app.tabBars.buttons["队伍"]
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "队伍 tab", timeout: 20))

        let tournamentTab = app.tabBars.buttons["赛事"]
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "赛事 tab", timeout: 8))
        tournamentTab.tap()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "日程 tab", timeout: 8))
        scheduleTab.tap()

        let messageTab = app.tabBars.buttons["消息"]
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "消息 tab", timeout: 8))
        messageTab.tap()

        let myTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "我的 tab", timeout: 8))
        myTab.tap()

        let editProfileButton = app.buttons["my_edit_profile_button"]
        XCTAssertTrue(waitForElement(editProfileButton, in: app, identifier: "my_edit_profile_button", timeout: 8))
    }

    @MainActor
    func testRemoteDebugSessionCanCreateTeam() throws {
        let teamName = "UIRemoteTeam"
        let teamSlogan = "debug-auto"
        let app = launchRemoteDebugApp(teamName: teamName, teamSlogan: teamSlogan)

        let teamTab = app.tabBars.buttons["队伍"]
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "队伍 tab", timeout: 20))
        teamTab.tap()

        let addButton = app.buttons["team_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "team_add_button", timeout: 8))
        addButton.tap()

        let teamDetailRoot = app.descendants(matching: .any).matching(identifier: "team_detail_root").firstMatch
        XCTAssertTrue(waitForElement(teamDetailRoot, in: app, identifier: "team_detail_root", timeout: 12))
    }

    @MainActor
    func testTeamSearchCanReachJoinEntry() throws {
        let app = launchApp()

        let teamTab = app.tabBars.buttons["队伍"]
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "队伍 tab"))
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
    func testTournamentFlowFromListToMatchCreation() throws {
        let app = launchApp()

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

        let tournamentDetailRoot = app.descendants(matching: .any).matching(identifier: "tournament_detail_root").firstMatch
        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))

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

        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts["自动化创建场次"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTournamentDetailCanEditAndSaveTournamentInfo() throws {
        let app = launchApp()

        let tournamentTab = app.tabBars.buttons["赛事"]
        XCTAssertTrue(tournamentTab.waitForExistence(timeout: 3))
        tournamentTab.tap()

        let addButton = app.buttons["tournament_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let nameInput = app.textFields["tournament_create_name_input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 3))
        nameInput.tap()
        nameInput.typeText("待编辑赛事")

        let createSubmit = app.buttons["tournament_create_submit"]
        XCTAssertTrue(createSubmit.waitForExistence(timeout: 3))
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

        dismissKeyboardIfPresent(in: app)
        _ = waitForKeyboardToDisappear(in: app)

        let saveButton = app.buttons["tournament_edit_save_button"]
        XCTAssertTrue(waitForElement(saveButton, in: app, identifier: "tournament_edit_save_button"))
        saveButton.tap()

        XCTAssertTrue(waitForElement(tournamentDetailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts["已编辑赛事"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["这是更新后的赛事简介"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.terminate()
        }
    }

    @MainActor
    func testMessageTabShowsFlatFeedAndCanOpenJoinRequestDetail() throws {
        let app = launchApp()

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

        let messageDetailRoot = app.descendants(matching: .any).matching(identifier: "message_detail_root").firstMatch
        XCTAssertTrue(waitForElement(messageDetailRoot, in: app, identifier: "message_detail_root"))
    }

    @MainActor
    func testMySettingsCanEditNickname() throws {
        let app = launchApp()

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
        let app = launchApp()

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
        let app = launchApp()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "日程 tab"))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(waitForElement(todayFab, in: app, identifier: "schedule_today_fab"))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if waitForElement(todayCell, in: app, identifier: "schedule_day_cell_today", timeout: 6) {
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

        let sourceApp = launchApp()
        let sourceScheduleTab = sourceApp.tabBars.buttons["日程"]
        XCTAssertTrue(waitForElement(sourceScheduleTab, in: sourceApp, identifier: "日程 tab"))
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
        let app = launchApp()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "日程 tab"))
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

        // 取消全选后，同步按钮应禁用
        selectAllButton.tap()
        XCTAssertFalse(confirmButton.isEnabled)

        // 再次全选，同步按钮恢复可用
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
        let app = launchApp()

        let scheduleTab = app.tabBars.buttons["日程"]
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "日程 tab"))
        scheduleTab.tap()

        let todayFab = app.buttons["schedule_today_fab"]
        XCTAssertTrue(waitForElement(todayFab, in: app, identifier: "schedule_today_fab"))
        todayFab.tap()

        let todayCell = app.buttons["schedule_day_cell_today"]
        if waitForElement(todayCell, in: app, identifier: "schedule_day_cell_today", timeout: 6) {
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
