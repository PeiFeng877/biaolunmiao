//
//  BianLunMiaoSmokeLocalUITests.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 本地模拟器 + Mock 数据。
//  OUTPUT: 最短 UI 冒烟结果，用于快速判断 App 是否明显损坏。
//  POS: UI 自动化-smoke-local lane。
//

import XCTest

final class BianLunMiaoSmokeLocalUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try allowExecutionLanes([.smokeLocal, .fullLocal])
    }

    @MainActor
    func testSmokeLaunchesMockDataHome() throws {
        let app = launchMockApp()
        let teamRoot = app.descendants(matching: .any).matching(identifier: "team_list_root").firstMatch
        XCTAssertTrue(waitForElement(teamRoot, in: app, identifier: "team_list_root"))
    }

    @MainActor
    func testSmokeSignedOutShowsLoginGate() throws {
        let app = launchSignedOutApp()

        let title = app.staticTexts["login_gate_title"]
        XCTAssertTrue(waitForElement(title, in: app, identifier: "login_gate_title"))

        let signInButton = app.buttons["auth_sign_in_with_apple_button"]
        XCTAssertTrue(waitForElement(signInButton, in: app, identifier: "auth_sign_in_with_apple_button"))

        let userAgreement = app.descendants(matching: .any).matching(identifier: "login_gate_user_agreement_link").firstMatch
        XCTAssertTrue(waitForElement(userAgreement, in: app, identifier: "login_gate_user_agreement_link"))

        let privacyPolicy = app.descendants(matching: .any).matching(identifier: "login_gate_privacy_policy_link").firstMatch
        XCTAssertTrue(waitForElement(privacyPolicy, in: app, identifier: "login_gate_privacy_policy_link"))
    }

    @MainActor
    func testSmokeMockDataCanReachMainTabs() throws {
        let app = launchMockApp()
        assertCanReachMainTabs(in: app)
    }
}
