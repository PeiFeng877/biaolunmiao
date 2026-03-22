//
//  BianLunMiaoLocalRemoteUITests.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 本机后端 + 调试会话兜底。
//  OUTPUT: 本地联调可达性与最小写操作闭环。
//  POS: UI 自动化-local-remote lane。
//

import XCTest

final class BianLunMiaoLocalRemoteUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireExecutionLane(.localRemote)
    }

    @MainActor
    func testLocalRemoteCanReachMainTabs() throws {
        let app = launchLocalRemoteApp()
        assertCanReachMainTabs(in: app, timeout: 20)
    }

    @MainActor
    func testLocalRemoteCanCreateTeam() throws {
        let teamName = uniqueTeamName(prefix: "UILocalTeam")
        let app = launchLocalRemoteApp()
        _ = createManagedTeam(in: app, teamName: teamName, slogan: "local-remote")
    }

    @MainActor
    func testLocalRemoteCanCreateTournamentAndMatch() throws {
        let app = launchLocalRemoteApp()
        let knownNickname = "Lineup\(uniquePhoneNumber(prefix: "139").suffix(4))"
        updateProfileNickname(in: app, nickname: knownNickname)
        _ = createManagedTeam(
            in: app,
            teamName: uniqueTeamName(prefix: "UILocalOwnerTeam"),
            slogan: "local-remote-match"
        )

        let tournamentTab = tabButton(in: app, tab: .tournament)
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "main_tab_tournament", timeout: 20))
        tournamentTab.tap()

        let addButton = app.buttons["tournament_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "tournament_add_button", timeout: 12))
        addButton.tap()

        let tournamentName = uniqueTeamName(prefix: "UILocalTournament")
        let matchName = uniqueTeamName(prefix: "UILocalMatch")

        let nameInput = app.textFields["tournament_create_name_input"]
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "tournament_create_name_input", timeout: 12))
        nameInput.tap()
        nameInput.typeText(tournamentName)

        let createSubmit = app.buttons["tournament_create_submit"]
        tapButtonHandlingKeyboard(createSubmit, in: app, identifier: "tournament_create_submit", timeout: 12)

        let detailRoot = app.descendants(matching: .any).matching(identifier: "tournament_detail_root").firstMatch
        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "tournament_detail_root", timeout: 20))

        let addMatchButton = app.buttons["tournament_add_match_fab"]
        XCTAssertTrue(waitForElement(addMatchButton, in: app, identifier: "tournament_add_match_fab", timeout: 12))
        addMatchButton.tap()

        let matchRoot = app.descendants(matching: .any).matching(identifier: "match_detail_root").firstMatch
        XCTAssertTrue(waitForElement(matchRoot, in: app, identifier: "match_detail_root", timeout: 12))

        let formatButton = app.buttons["1v1"].firstMatch
        XCTAssertTrue(waitForElement(formatButton, in: app, identifier: "1v1", timeout: 12))
        formatButton.tap()

        let matchNameInput = app.textFields["match_editor_name_input"]
        XCTAssertTrue(waitForElement(matchNameInput, in: app, identifier: "match_editor_name_input", timeout: 12))
        matchNameInput.tap()
        matchNameInput.typeText(matchName)

        let lineupInput = app.textFields["match_lineup_input_一辩"]
        XCTAssertTrue(waitForElement(lineupInput, in: app, identifier: "match_lineup_input_一辩", timeout: 12))
        lineupInput.tap()
        lineupInput.typeText(knownNickname)

        let saveMatchButton = app.buttons["match_editor_save_button"]
        XCTAssertTrue(waitForElement(saveMatchButton, in: app, identifier: "match_editor_save_button", timeout: 12))
    }

    @MainActor
    func testLocalRemoteCanOpenScheduleMessageAndMyFlows() throws {
        let app = launchLocalRemoteApp()
        _ = createManagedTeam(
            in: app,
            teamName: uniqueTeamName(prefix: "UILocalScheduleTeam"),
            slogan: "local-remote-schedule"
        )

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule", timeout: 20))
        scheduleTab.tap()

        let scheduleRoot = app.descendants(matching: .any).matching(identifier: "schedule_root").firstMatch
        XCTAssertTrue(waitForElement(scheduleRoot, in: app, identifier: "schedule_root", timeout: 12))

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(waitForElement(syncFab, in: app, identifier: "schedule_sync_fab", timeout: 12))
        syncFab.tap()

        let syncSheet = app.descendants(matching: .any).matching(identifier: "schedule_sync_sheet").firstMatch
        XCTAssertTrue(waitForElement(syncSheet, in: app, identifier: "schedule_sync_sheet", timeout: 12))
        syncSheet.swipeDown()

        let messageTab = tabButton(in: app, tab: .message)
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "main_tab_message", timeout: 20))
        messageTab.tap()

        let messageRoot = app.descendants(matching: .any).matching(identifier: "message_hub_root").firstMatch
        XCTAssertTrue(waitForElement(messageRoot, in: app, identifier: "message_hub_root", timeout: 12))

        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my", timeout: 20))
        myTab.tap()

        let myRoot = app.descendants(matching: .any).matching(identifier: "my_hub_root").firstMatch
        XCTAssertTrue(waitForElement(myRoot, in: app, identifier: "my_hub_root", timeout: 12))

        let editButton = app.buttons["my_edit_profile_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "my_edit_profile_button", timeout: 12))
        editButton.tap()

        let nicknameInput = app.textFields["profile_nickname_input"]
        XCTAssertTrue(waitForElement(nicknameInput, in: app, identifier: "profile_nickname_input", timeout: 12))
        nicknameInput.clearAndTypeText("Remote\(uniquePhoneNumber(prefix: "135").suffix(4))")

        let saveButton = app.buttons["profile_edit_save_button"]
        tapButtonHandlingKeyboard(saveButton, in: app, identifier: "profile_edit_save_button", timeout: 12)

        XCTAssertTrue(waitForElement(myRoot, in: app, identifier: "my_hub_root", timeout: 12))
    }

    @MainActor
    @discardableResult
    private func createManagedTeam(in app: XCUIApplication, teamName: String, slogan: String) -> XCUIElement {
        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team", timeout: 20))
        teamTab.tap()

        let addButton = app.buttons["team_add_button"]
        XCTAssertTrue(waitForElement(addButton, in: app, identifier: "team_add_button", timeout: 12))
        addButton.tap()

        let nameInput = app.textFields["team_create_name_input"]
        XCTAssertTrue(waitForElement(nameInput, in: app, identifier: "team_create_name_input", timeout: 12))
        nameInput.tap()
        nameInput.typeText(teamName)

        let sloganInput = app.textFields["team_create_slogan_input"]
        XCTAssertTrue(waitForElement(sloganInput, in: app, identifier: "team_create_slogan_input", timeout: 12))
        sloganInput.tap()
        sloganInput.typeText(slogan)

        let submitButton = app.buttons["team_create_submit_button"]
        tapButtonHandlingKeyboard(submitButton, in: app, identifier: "team_create_submit_button", timeout: 12)

        let detailRoot = app.descendants(matching: .any).matching(identifier: "team_detail_root").firstMatch
        XCTAssertTrue(waitForElement(detailRoot, in: app, identifier: "team_detail_root", timeout: 20))
        XCTAssertTrue(app.staticTexts[teamName].waitForExistence(timeout: 8))
        return detailRoot
    }

    @MainActor
    private func updateProfileNickname(in app: XCUIApplication, nickname: String) {
        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my", timeout: 20))
        myTab.tap()

        let myRoot = app.descendants(matching: .any).matching(identifier: "my_hub_root").firstMatch
        XCTAssertTrue(waitForElement(myRoot, in: app, identifier: "my_hub_root", timeout: 12))

        let editButton = app.buttons["my_edit_profile_button"]
        XCTAssertTrue(waitForElement(editButton, in: app, identifier: "my_edit_profile_button", timeout: 12))
        editButton.tap()

        let nicknameInput = app.textFields["profile_nickname_input"]
        XCTAssertTrue(waitForElement(nicknameInput, in: app, identifier: "profile_nickname_input", timeout: 12))
        nicknameInput.clearAndTypeText(nickname)

        let saveButton = app.buttons["profile_edit_save_button"]
        tapButtonHandlingKeyboard(saveButton, in: app, identifier: "profile_edit_save_button", timeout: 12)

        XCTAssertTrue(waitForElement(myRoot, in: app, identifier: "my_hub_root", timeout: 12))
    }
}
