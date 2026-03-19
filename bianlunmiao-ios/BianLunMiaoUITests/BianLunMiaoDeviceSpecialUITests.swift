//
//  BianLunMiaoDeviceSpecialUITests.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 真机启动与 Apple 登录入口。
//  OUTPUT: 真机专项可达性结果。
//  POS: UI 自动化-device-special lane。
//

import XCTest

final class BianLunMiaoDeviceSpecialUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireExecutionLane(.deviceSpecial)
    }

    @MainActor
    func testDeviceSpecialShowsAppleEntry() throws {
        let app = launchSignedOutApp()

        let title = app.staticTexts["login_gate_title"]
        XCTAssertTrue(waitForElement(title, in: app, identifier: "login_gate_title"))

        let signInButton = app.buttons["auth_sign_in_with_apple_button"]
        XCTAssertTrue(waitForElement(signInButton, in: app, identifier: "auth_sign_in_with_apple_button"))

        let debugState = app.staticTexts["auth_debug_state"]
        XCTAssertTrue(waitForElement(debugState, in: app, identifier: "auth_debug_state"))
        XCTAssertEqual(debugState.label, "idle")
    }
}
