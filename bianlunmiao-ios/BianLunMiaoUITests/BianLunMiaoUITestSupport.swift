//
//  BianLunMiaoUITestSupport.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 应用 UI 锚点、测试执行 lane 与目标环境。
//  OUTPUT: UI 自动化公共启动、等待、诊断与 lane 约束能力。
//  POS: UI 自动化支撑层。
//

import XCTest

enum BianLunMiaoUITestExecutionLane: String {
    case smokeLocal = "smoke-local"
    case fullLocal = "full-local"
    case localRemote = "local-remote"
    case stgSmoke = "stg-smoke"
    case deviceSpecial = "device-special"
    case specialized = "specialized"
}

enum BianLunMiaoMainTab: CaseIterable {
    case team
    case tournament
    case schedule
    case message
    case my

    var title: String {
        switch self {
        case .team:
            return "队伍"
        case .tournament:
            return "赛事"
        case .schedule:
            return "日程"
        case .message:
            return "消息"
        case .my:
            return "我的"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .team:
            return "main_tab_team"
        case .tournament:
            return "main_tab_tournament"
        case .schedule:
            return "main_tab_schedule"
        case .message:
            return "main_tab_message"
        case .my:
            return "main_tab_my"
        }
    }

    var rootIdentifier: String {
        switch self {
        case .team:
            return "team_list_root"
        case .tournament:
            return "tournament_list_root"
        case .schedule:
            return "schedule_root"
        case .message:
            return "message_hub_root"
        case .my:
            return "my_hub_root"
        }
    }
}

class BianLunMiaoUIBaseTestCase: XCTestCase {
    let uiTimeout: TimeInterval = 12
    let uiPollInterval: TimeInterval = 1
    let localRemoteBaseURL = "http://127.0.0.1:8000/api/v1"
    let stagingRemoteBaseURL = "http://120.55.115.147/api/v1"

    var executionLane: String? {
        let value = ProcessInfo.processInfo.environment["BLM_UI_TEST_EXECUTION_LANE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == true ? nil : value
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func allowExecutionLanes(_ lanes: [BianLunMiaoUITestExecutionLane]) throws {
        guard let executionLane else { return }
        guard lanes.map(\.rawValue).contains(executionLane) else {
            throw XCTSkip("当前执行 lane 为 \(executionLane)，跳过非匹配测试。")
        }
    }

    func requireExecutionLane(_ lane: BianLunMiaoUITestExecutionLane) throws {
        guard executionLane == lane.rawValue else {
            throw XCTSkip("当前执行 lane 非 \(lane.rawValue)，跳过专项测试。")
        }
    }

    @MainActor
    func launchMockApp() -> XCUIApplication {
        launchApp(
            useMockData: true,
            launchLane: .smokeLocal
        )
    }

    @MainActor
    func launchSignedOutApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = "0"
        app.launchEnvironment["BLM_REMOTE_DISABLED"] = "1"
        app.launchEnvironment["BLM_FORCE_NEW_USER_FLOW"] = "0"
        if let executionLane {
            app.launchEnvironment["BLM_UI_TEST_EXECUTION_LANE"] = executionLane
        }
        app.launch()
        return app
    }

    @MainActor
    func launchLocalRemoteApp(teamName: String? = nil, teamSlogan: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = "0"
        app.launchEnvironment["BLM_UI_TEST_ALLOW_REMOTE"] = "1"
        app.launchEnvironment["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] = "1"
        app.launchEnvironment["BLM_FORCE_NEW_USER_FLOW"] = "0"
        app.launchEnvironment["BLM_API_BASE_URL"] = resolvedRemoteBaseURL(defaultValue: localRemoteBaseURL)
        app.launchEnvironment["BLM_UI_TEST_EXECUTION_LANE"] = BianLunMiaoUITestExecutionLane.localRemote.rawValue
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

    @MainActor
    func launchSTGSmokeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = "0"
        app.launchEnvironment["BLM_UI_TEST_ALLOW_REMOTE"] = "1"
        app.launchEnvironment["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] = "1"
        app.launchEnvironment["BLM_FORCE_NEW_USER_FLOW"] = "0"
        app.launchEnvironment["BLM_API_BASE_URL"] = resolvedRemoteBaseURL(defaultValue: stagingRemoteBaseURL)
        app.launchEnvironment["BLM_UI_TEST_EXECUTION_LANE"] = BianLunMiaoUITestExecutionLane.stgSmoke.rawValue
        app.launch()
        return app
    }

    @MainActor
    private func launchApp(
        useMockData: Bool,
        launchLane: BianLunMiaoUITestExecutionLane?
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = useMockData ? "1" : "0"
        app.launchEnvironment["BLM_FORCE_NEW_USER_FLOW"] = "0"
        if let executionLane {
            app.launchEnvironment["BLM_UI_TEST_EXECUTION_LANE"] = executionLane
        } else if let launchLane {
            app.launchEnvironment["BLM_UI_TEST_EXECUTION_LANE"] = launchLane.rawValue
        }
        app.launch()
        return app
    }

    func resolvedRemoteBaseURL(defaultValue: String) -> String {
        let env = ProcessInfo.processInfo.environment
        guard let value = env["BLM_TEST_REMOTE_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return defaultValue
        }
        return value
    }

    func uniqueTeamName(prefix: String) -> String {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        return "\(prefix)-\(suffix)"
    }

    @discardableResult
    @MainActor
    func waitForElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval? = nil,
        recordFailure: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let waitTimeout = timeout ?? uiTimeout
        let deadline = Date().addingTimeInterval(waitTimeout)
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
            XCTFail("Element '\(identifier)' did not appear within \(Int(waitTimeout))s", file: file, line: line)
        }
        return false
    }

    @MainActor
    func attachFailureDiagnostics(app: XCUIApplication, identifier: String) {
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
    func attachAppStoreScreenshot(app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "appstore-\(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func tabButton(in app: XCUIApplication, tab: BianLunMiaoMainTab) -> XCUIElement {
        let buttonByIdentifier = app.tabBars.buttons[tab.accessibilityIdentifier]
        if buttonByIdentifier.exists {
            return buttonByIdentifier
        }
        return app.tabBars.buttons[tab.title]
    }

    @MainActor
    func assertCanReachMainTabs(
        in app: XCUIApplication,
        timeout: TimeInterval = 20
    ) {
        for tab in BianLunMiaoMainTab.allCases {
            let tabButton = tabButton(in: app, tab: tab)
            XCTAssertTrue(waitForElement(tabButton, in: app, identifier: tab.accessibilityIdentifier, timeout: timeout))
            tabButton.tap()

            let root = app.descendants(matching: .any).matching(identifier: tab.rootIdentifier).firstMatch
            XCTAssertTrue(waitForElement(root, in: app, identifier: tab.rootIdentifier, timeout: 8))
        }
    }

    @MainActor
    func selectedWeekDayIdentifier(in app: XCUIApplication) -> String {
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
    func dismissKeyboardIfPresent(in app: XCUIApplication) {
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
    func waitForKeyboardToDisappear(
        in app: XCUIApplication,
        timeout: TimeInterval = 2
    ) -> Bool {
        let predicate = NSPredicate(format: "count == 0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.keyboards)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func tapButtonHandlingKeyboard(
        _ button: XCUIElement,
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(waitForElement(button, in: app, identifier: identifier, timeout: timeout), file: file, line: line)
        if !button.isHittable {
            dismissKeyboardIfPresent(in: app)
            _ = waitForKeyboardToDisappear(in: app)
        }
        XCTAssertTrue(button.isHittable, "Button '\(identifier)' was still not hittable after dismissing keyboard", file: file, line: line)
        button.tap()
    }
}

extension XCUIElement {
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
