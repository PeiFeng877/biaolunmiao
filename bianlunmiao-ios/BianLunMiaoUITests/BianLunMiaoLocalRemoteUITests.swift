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
        let app = launchLocalRemoteApp(teamName: teamName, teamSlogan: "local-remote")

        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team", timeout: 20))
        teamTab.tap()

        let teamDetailRoot = app.descendants(matching: .any).matching(identifier: "team_detail_root").firstMatch
        XCTAssertTrue(waitForElement(teamDetailRoot, in: app, identifier: "team_detail_root", timeout: 16))
    }
}
