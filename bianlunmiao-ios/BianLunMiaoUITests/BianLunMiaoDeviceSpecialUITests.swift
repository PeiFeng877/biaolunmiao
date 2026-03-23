//
//  BianLunMiaoDeviceSpecialUITests.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  Updated by Codex on 2026/3/22.
//  INPUT: 真机启动、Apple / 手机号登录入口与手机号真机联调闭环。
//  OUTPUT: 真机专项可达性与手机号登录闭环结果。
//  POS: UI 自动化-device-special lane。
//

import XCTest

final class BianLunMiaoDeviceSpecialUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireExecutionLane(.deviceSpecial)
    }

    @MainActor
    func testDeviceSpecialShowsLoginEntries() throws {
        let app = launchSignedOutApp()

        let title = app.staticTexts["login_gate_title"]
        XCTAssertTrue(waitForElement(title, in: app, identifier: "login_gate_title"))

        let appleSignInButton = app.buttons["auth_sign_in_with_apple_button"]
        XCTAssertTrue(waitForElement(appleSignInButton, in: app, identifier: "auth_sign_in_with_apple_button"))

        let phoneSignInButton = app.buttons["auth_sign_in_with_phone_button"]
        XCTAssertTrue(waitForElement(phoneSignInButton, in: app, identifier: "auth_sign_in_with_phone_button"))

        let debugState = app.staticTexts["auth_debug_state"]
        XCTAssertTrue(waitForElement(debugState, in: app, identifier: "auth_debug_state"))
        XCTAssertEqual(debugState.label, "idle")
    }

    @MainActor
    func testDeviceSpecialPhoneSignInCanCompleteNewUserFlow() throws {
        let phone = uniquePhoneNumber()
        let app = launchDeviceSpecialRemoteApp()
        signInWithPhone(in: app, phone: phone, code: "1234")
        completeNewUserProfileIfNeeded(in: app, nickname: "device\(phone.suffix(4))")
        assertReachedTeamHome(in: app)
    }

    @MainActor
    func testDeviceSpecialPhoneSignInRejectsWrongCode() throws {
        let app = launchDeviceSpecialRemoteApp()
        let phone = uniquePhoneNumber(prefix: "137")

        openPhoneLogin(in: app)
        fillPhoneLoginForm(in: app, phone: phone, code: "6543")

        let submitButton = app.buttons["phone_login_submit_button"]
        XCTAssertTrue(waitForElement(submitButton, in: app, identifier: "phone_login_submit_button", timeout: 12))
        submitButton.tap()

        let errorMessage = app.staticTexts["phone_login_error_message"]
        XCTAssertTrue(waitForElement(errorMessage, in: app, identifier: "phone_login_error_message", timeout: 12))
        XCTAssertEqual(errorMessage.label, "验证码错误，请重试。")
        XCTAssertTrue(app.textFields["phone_login_code_input"].exists)
    }

    @MainActor
    func testDeviceSpecialPhoneSignInExistingUserCanReturnDirectlyToTeamHome() throws {
        let phone = uniquePhoneNumber(prefix: "136")
        let app = launchDeviceSpecialRemoteApp()

        signInWithPhone(in: app, phone: phone, code: "1234")
        completeNewUserProfileIfNeeded(in: app, nickname: "repeat\(phone.suffix(4))")
        signOutCurrentUser(in: app)

        signInWithPhone(in: app, phone: phone, code: "1234")
        assertReachedTeamHome(in: app)
        XCTAssertFalse(app.textFields["profile_nickname_input"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openPhoneLogin(in app: XCUIApplication) {
        handleLocalNetworkPermissionIfNeeded()
        let phoneEntryButton = app.buttons["auth_sign_in_with_phone_button"]
        XCTAssertTrue(waitForElement(phoneEntryButton, in: app, identifier: "auth_sign_in_with_phone_button", timeout: 20))
        phoneEntryButton.tap()
        let phoneInput = app.textFields["phone_login_phone_input"]
        XCTAssertTrue(waitForElement(phoneInput, in: app, identifier: "phone_login_phone_input", timeout: 12))
    }

    @MainActor
    private func fillPhoneLoginForm(in app: XCUIApplication, phone: String, code: String) {
        let phoneInput = app.textFields["phone_login_phone_input"]
        XCTAssertTrue(waitForElement(phoneInput, in: app, identifier: "phone_login_phone_input", timeout: 12))
        phoneInput.tap()
        phoneInput.typeText(phone)

        let sendCodeButton = app.buttons["phone_login_send_code_button"]
        XCTAssertTrue(waitForElement(sendCodeButton, in: app, identifier: "phone_login_send_code_button", timeout: 12))
        sendCodeButton.tap()
        handleLocalNetworkPermissionIfNeeded()

        let codeInput = app.textFields["phone_login_code_input"]
        XCTAssertTrue(waitForElement(codeInput, in: app, identifier: "phone_login_code_input", timeout: 12))
        codeInput.tap()
        codeInput.typeText(code)
    }

    @MainActor
    private func signInWithPhone(in app: XCUIApplication, phone: String, code: String) {
        openPhoneLogin(in: app)
        fillPhoneLoginForm(in: app, phone: phone, code: code)

        let submitButton = app.buttons["phone_login_submit_button"]
        XCTAssertTrue(waitForElement(submitButton, in: app, identifier: "phone_login_submit_button", timeout: 12))
        submitButton.tap()
        handleLocalNetworkPermissionIfNeeded()
    }

    @MainActor
    private func completeNewUserProfileIfNeeded(in app: XCUIApplication, nickname: String) {
        let nicknameInput = app.textFields["profile_nickname_input"]
        guard waitForElement(
            nicknameInput,
            in: app,
            identifier: "profile_nickname_input",
            timeout: 8,
            recordFailure: false
        ) else {
            return
        }
        nicknameInput.tap()
        nicknameInput.clearAndTypeText(nickname)

        let saveButton = app.buttons["new_user_profile_save_button"]
        XCTAssertTrue(waitForElement(saveButton, in: app, identifier: "new_user_profile_save_button", timeout: 12))
        saveButton.tap()
    }

    @MainActor
    private func assertReachedTeamHome(in app: XCUIApplication) {
        let teamTab = tabButton(in: app, tab: .team)
        XCTAssertTrue(waitForElement(teamTab, in: app, identifier: "main_tab_team", timeout: 20))

        let teamRoot = app.descendants(matching: .any).matching(identifier: "team_list_root").firstMatch
        XCTAssertTrue(waitForElement(teamRoot, in: app, identifier: "team_list_root", timeout: 20))
    }

    @MainActor
    private func signOutCurrentUser(in app: XCUIApplication) {
        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my", timeout: 20))
        myTab.tap()

        let moreButton = app.buttons["my_more_button"]
        XCTAssertTrue(waitForElement(moreButton, in: app, identifier: "my_more_button", timeout: 12))
        moreButton.tap()

        let signOutRow = app.buttons["my_more_row_sign_out"]
        XCTAssertTrue(waitForElement(signOutRow, in: app, identifier: "my_more_row_sign_out", timeout: 12))
        signOutRow.tap()

        let confirmButton = app.buttons["退出登录"]
        XCTAssertTrue(waitForElement(confirmButton, in: app, identifier: "退出登录", timeout: 12))
        confirmButton.tap()

        let title = app.staticTexts["login_gate_title"]
        XCTAssertTrue(waitForElement(title, in: app, identifier: "login_gate_title", timeout: 20))
    }
}
