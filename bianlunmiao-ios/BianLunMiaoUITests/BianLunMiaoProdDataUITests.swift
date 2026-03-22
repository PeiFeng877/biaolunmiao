//
//  BianLunMiaoProdDataUITests.swift
//  BianLunMiaoUITests
//
//  Updated by Codex on 2026/3/22.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: FC 默认域名 + 真机已登录会话。
//  OUTPUT: 正式服队伍、赛事、场次 CRUD 预演断言。
//  POS: UI 自动化-prod-data lane。
//

import XCTest

final class BianLunMiaoProdDataUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireExecutionLane(.prodData)
    }

    @MainActor
    func testProdDataCanSearchFixtureTeamAndSubmitJoinRequest() throws {
        let fixtureTeamPublicID = try requiredEnvironmentValue("BLM_UI_TEST_PROD_JOIN_TEAM_PUBLIC_ID")
        let fixtureTeamName = try requiredEnvironmentValue("BLM_UI_TEST_PROD_JOIN_TEAM_NAME")
        let app = launchProdDataApp()

        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team", timeout: 20))
        teamTab.tap()

        let searchButton = app.buttons["team_search_button"]
        XCTAssertTrue(waitForElement(searchButton, in: app, identifier: "team_search_button"))
        searchButton.tap()

        let searchRoot = app.descendants(matching: .any).matching(identifier: "team_search_root").firstMatch
        XCTAssertTrue(waitForElement(searchRoot, in: app, identifier: "team_search_root"))

        let searchField = app.textFields["team_search_input"]
        XCTAssertTrue(waitForElement(searchField, in: app, identifier: "team_search_input"))
        searchField.tap()
        searchField.typeText(fixtureTeamPublicID)

        XCTAssertTrue(app.staticTexts[fixtureTeamName].waitForExistence(timeout: 12))

        let resultTitle = app.staticTexts[fixtureTeamName].firstMatch
        XCTAssertTrue(waitForElement(resultTitle, in: app, identifier: fixtureTeamName))
        resultTitle.tap()

        let detailRoot = app.descendants(matching: .any).matching(identifier: "team_detail_root").firstMatch
        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "team_detail_root"))

        let detailBackButton = app.buttons["team_detail_back_button"]
        XCTAssertTrue(waitForElement(detailBackButton, in: app, identifier: "team_detail_back_button"))
        detailBackButton.tap()

        let joinButton = app.buttons["申请入队"].firstMatch
        XCTAssertTrue(waitForElement(joinButton, in: app, identifier: "申请入队"))
        joinButton.tap()

        let joinSheet = app.descendants(matching: .any).matching(identifier: "team_join_application_sheet_root").firstMatch
        XCTAssertTrue(waitForElement(joinSheet, in: app, identifier: "team_join_application_sheet_root"))

        let submitButton = app.buttons["提交申请"]
        tapButtonHandlingKeyboard(submitButton, in: app, identifier: "提交申请")

        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: joinSheet
        )
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: 12), .completed)

        let messageTab = tabButton(in: app, tab: .message)
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "main_tab_message"))
        messageTab.tap()
        let messageRoot = app.descendants(matching: .any).matching(identifier: "message_hub_root").firstMatch
        XCTAssertTrue(waitForElement(messageRoot, in: app, identifier: "message_hub_root"))
    }

    @MainActor
    func testProdDataCanCreateEditAndDissolveTeam() throws {
        let app = launchProdDataApp()

        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team", timeout: 20))
        teamTab.tap()

        let addButton = app.buttons["team_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "team_add_button"))
        addButton.tap()

        let teamName = uniqueName(prefix: "PROD队伍专项")
        let slogan = uniqueName(prefix: "PROD队伍口号")

        let nameInput = app.textFields["team_create_name_input"]
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "team_create_name_input"))
        nameInput.tap()
        nameInput.typeText(teamName)

        let sloganInput = app.textFields["team_create_slogan_input"]
        XCTAssertTrue(waitForElement(sloganInput, in: app, identifier: "team_create_slogan_input"))
        sloganInput.tap()
        sloganInput.typeText(slogan)

        let submitButton = app.buttons["team_create_submit_button"]
        tapButtonHandlingKeyboard(submitButton, in: app, identifier: "team_create_submit_button")

        let detailRoot = app.descendants(matching: .any).matching(identifier: "team_detail_root").firstMatch
        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "team_detail_root", timeout: 20))
        XCTAssertTrue(app.staticTexts[teamName].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts[slogan].waitForExistence(timeout: 8))

        let editButton = app.buttons["team_detail_edit_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "team_detail_edit_button"))
        editButton.tap()

        let editedTeamName = "\(teamName)-已编辑"
        let editedSlogan = "\(slogan)-已更新"
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "team_create_name_input"))
        nameInput.clearAndTypeText(editedTeamName)
        XCTAssertTrue(waitForElement(sloganInput, in: app, identifier: "team_create_slogan_input"))
        sloganInput.clearAndTypeText(editedSlogan)
        tapButtonHandlingKeyboard(submitButton, in: app, identifier: "team_create_submit_button")

        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "team_detail_root"))
        XCTAssertTrue(app.staticTexts[editedTeamName].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts[editedSlogan].waitForExistence(timeout: 8))

        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "team_detail_edit_button"))
        editButton.tap()

        let dangerButton = app.buttons["team_danger_action_button"]
        XCTAssertTrue(waitForElement(dangerButton, in: app, identifier: "team_danger_action_button"))
        dangerButton.tap()

        let confirmButton = app.buttons["解散队伍"]
        XCTAssertTrue(waitForElement(confirmButton, in: app, identifier: "解散队伍"))
        confirmButton.tap()

        let teamListRoot = app.descendants(matching: .any).matching(identifier: "team_list_root").firstMatch
        XCTAssertTrue(waitForElement(teamListRoot, in: app, identifier: "team_list_root", timeout: 12))
        XCTAssertFalse(app.staticTexts[editedTeamName].exists)
    }

    @MainActor
    func testProdDataCanCreateSearchEditTournamentAndMatch() throws {
        let app = launchProdDataApp()

        let tournamentTab = tabButton(in: app, tab: .tournament)
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "main_tab_tournament", timeout: 20))
        tournamentTab.tap()

        let created = createTournamentAndFirstMatch(in: app)
        let tournamentName = created.tournamentName
        let tournamentIntro = created.tournamentIntro
        let detailRoot = created.detailRoot

        let backButton = app.buttons["tournament_detail_back_button"]
        XCTAssertTrue(waitForElement(backButton, in: app, identifier: "tournament_detail_back_button"))
        backButton.tap()

        let listRoot = app.descendants(matching: .any).matching(identifier: "tournament_list_root").firstMatch
        XCTAssertTrue(waitForElement(listRoot, in: app, identifier: "tournament_list_root"))

        let searchField = app.textFields["tournament_search_input"]
        XCTAssertTrue(waitForElement(searchField, in: app, identifier: "tournament_search_input"))
        searchField.tap()
        searchField.typeText(tournamentName)

        let tournamentTitle = app.staticTexts[tournamentName].firstMatch
        XCTAssertTrue(waitForElement(tournamentTitle, in: app, identifier: tournamentName))
        tournamentTitle.tap()

        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root"))

        let editButton = app.buttons["tournament_detail_edit_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "tournament_detail_edit_button"))
        editButton.tap()

        let editedTournamentName = "\(tournamentName)-已编辑"
        let editedTournamentIntro = "\(tournamentIntro)-已更新"
        let editNameInput = app.textFields["tournament_edit_name_input"]
        XCTAssertTrue(waitForElement(editNameInput, in: app, identifier: "tournament_edit_name_input"))
        editNameInput.clearAndTypeText(editedTournamentName)

        let editIntroInput = app.textViews["tournament_edit_intro_input"]
        XCTAssertTrue(waitForElement(editIntroInput, in: app, identifier: "tournament_edit_intro_input"))
        editIntroInput.clearAndTypeText(editedTournamentIntro)

        let saveTournamentButton = app.buttons["tournament_edit_save_button"]
        tapButtonHandlingKeyboard(saveTournamentButton, in: app, identifier: "tournament_edit_save_button")

        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts[editedTournamentName].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts[editedTournamentIntro].waitForExistence(timeout: 8))

        let addMatchButton = app.buttons["tournament_add_match_fab"]
        XCTAssertTrue(waitForElement(addMatchButton, in: app, identifier: "tournament_add_match_fab"))
        addMatchButton.tap()

        let matchRoot = app.descendants(matching: .any).matching(identifier: "match_detail_root").firstMatch
        XCTAssertTrue(waitForElement(matchRoot, in: app, identifier: "match_detail_root"))

        let matchName = uniqueName(prefix: "PROD场次专项")
        let matchNameInput = app.textFields["match_editor_name_input"]
        XCTAssertTrue(waitForElement(matchNameInput, in: app, identifier: "match_editor_name_input"))
        matchNameInput.tap()
        matchNameInput.typeText(matchName)

        let saveMatchButton = app.buttons["match_editor_save_button"]
        tapButtonHandlingKeyboard(saveMatchButton, in: app, identifier: "match_editor_save_button")

        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts[matchName].waitForExistence(timeout: 8))

        let matchRow = app.staticTexts[matchName].firstMatch
        XCTAssertTrue(waitForElement(matchRow, in: app, identifier: matchName))
        matchRow.tap()

        XCTAssertTrue(waitForElement(matchRoot, in: app, identifier: "match_detail_root"))
        let editedMatchName = "\(matchName)-已编辑"
        XCTAssertTrue(waitForElement(matchNameInput, in: app, identifier: "match_editor_name_input"))
        matchNameInput.clearAndTypeText(editedMatchName)
        tapButtonHandlingKeyboard(saveMatchButton, in: app, identifier: "match_editor_save_button")

        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts[editedMatchName].waitForExistence(timeout: 8))
    }

    @MainActor
    func testProdDataCanSyncMatchToCalendar() throws {
        let app = launchProdDataApp()

        let tournamentTab = tabButton(in: app, tab: .tournament)
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "main_tab_tournament", timeout: 20))
        tournamentTab.tap()

        let created = createTournamentAndFirstMatch(in: app)
        let matchName = created.matchName

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule", timeout: 20))
        scheduleTab.tap()

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(waitForElement(syncFab, in: app, identifier: "schedule_sync_fab", timeout: 20))
        syncFab.tap()

        let syncSheet = app.descendants(matching: .any).matching(identifier: "schedule_sync_sheet").firstMatch
        XCTAssertTrue(waitForElement(syncSheet, in: app, identifier: "schedule_sync_sheet"))

        let matchToggle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule_sync_match_toggle_")).firstMatch
        XCTAssertTrue(waitForElement(matchToggle, in: app, identifier: "schedule_sync_match_toggle_*"))
        XCTAssertTrue(app.staticTexts[matchName].waitForExistence(timeout: 8))

        let confirmButton = app.buttons["schedule_sync_confirm_button"]
        XCTAssertTrue(waitForElement(confirmButton, in: app, identifier: "schedule_sync_confirm_button"))
        XCTAssertTrue(confirmButton.isEnabled)
        confirmButton.tap()

        handleCalendarPermissionIfNeeded()

        let successToast = app.otherElements["app_toast_success"]
        let infoToast = app.otherElements["app_toast_info"]
        let warningToast = app.otherElements["app_toast_warning"]
        let blockingAlert = app.alerts["提示"]

        let appeared = waitForAnyElement(
            [successToast, infoToast, warningToast, blockingAlert],
            timeout: 20
        )
        XCTAssertTrue(appeared, "预期看到日历同步反馈，但未出现 toast 或阻塞弹窗。")

        if blockingAlert.exists {
            XCTFail("日历同步出现权限或阻塞弹窗，未完成同步。")
        }

        XCTAssertFalse(syncSheet.exists, "同步成功后应关闭同步面板。")
    }

    private func requiredEnvironmentValue(_ key: String) throws -> String {
        let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else {
            throw XCTSkip("缺少 PROD 数据专项环境变量：\(key)")
        }
        return value
    }

    private func uniqueName(prefix: String) -> String {
        uniqueTeamName(prefix: prefix)
    }

    @MainActor
    private func createTournamentAndFirstMatch(in app: XCUIApplication) -> (tournamentName: String, tournamentIntro: String, matchName: String, detailRoot: XCUIElement) {
        let addButton = app.buttons["tournament_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "tournament_add_button"))
        addButton.tap()

        let tournamentName = uniqueName(prefix: "PROD赛事专项")
        let tournamentIntro = uniqueName(prefix: "PROD赛事简介")

        let nameInput = app.textFields["tournament_create_name_input"]
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "tournament_create_name_input"))
        nameInput.tap()
        nameInput.typeText(tournamentName)

        let introInput = app.textViews["tournament_create_intro_input"]
        if waitForElement(introInput, in: app, identifier: "tournament_create_intro_input", timeout: 3, recordFailure: false) {
            introInput.tap()
            introInput.typeText(tournamentIntro)
        }

        let createSubmit = app.buttons["tournament_create_submit"]
        tapButtonHandlingKeyboard(createSubmit, in: app, identifier: "tournament_create_submit")

        let detailRoot = app.descendants(matching: .any).matching(identifier: "tournament_detail_root").firstMatch
        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root", timeout: 20))

        let addMatchButton = app.buttons["tournament_add_match_fab"]
        XCTAssertTrue(waitForElement(addMatchButton, in: app, identifier: "tournament_add_match_fab"))
        addMatchButton.tap()

        let matchRoot = app.descendants(matching: .any).matching(identifier: "match_detail_root").firstMatch
        XCTAssertTrue(waitForElement(matchRoot, in: app, identifier: "match_detail_root"))

        let matchName = uniqueName(prefix: "PROD场次专项")
        let matchNameInput = app.textFields["match_editor_name_input"]
        XCTAssertTrue(waitForElement(matchNameInput, in: app, identifier: "match_editor_name_input"))
        matchNameInput.tap()
        matchNameInput.typeText(matchName)

        let saveMatchButton = app.buttons["match_editor_save_button"]
        tapButtonHandlingKeyboard(saveMatchButton, in: app, identifier: "match_editor_save_button")

        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root"))
        XCTAssertTrue(app.staticTexts[matchName].waitForExistence(timeout: 8))

        return (tournamentName, tournamentIntro, matchName, detailRoot)
    }

    @MainActor
    private func handleCalendarPermissionIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButtons = ["允许完全访问", "允许", "好", "OK", "Allow Full Access", "Allow"]

        for title in allowButtons {
            let button = springboard.buttons[title]
            if button.waitForExistence(timeout: 4) {
                button.tap()
                return
            }
        }
    }

    @MainActor
    private func waitForAnyElement(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if elements.contains(where: \.exists) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return elements.contains(where: \.exists)
    }
}
