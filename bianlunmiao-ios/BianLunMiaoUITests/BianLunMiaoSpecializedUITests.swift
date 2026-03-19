//
//  BianLunMiaoSpecializedUITests.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 启动性能与截图产物专项需求。
//  OUTPUT: App Store 素材与专项性能采样结果。
//  POS: UI 自动化-specialized lane。
//

import XCTest

final class BianLunMiaoSpecializedUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try allowExecutionLanes([.specialized])
    }

    @MainActor
    func testAppStoreScreenshotPack() throws {
        let app = launchMockApp()

        let tournamentTab = tabButton(in: app, tab: .tournament)
        XCTAssertTrue(waitForElement(tournamentTab, in: app, identifier: "main_tab_tournament"))
        tournamentTab.tap()
        attachAppStoreScreenshot(app: app, name: "01_tournament_list")

        let scheduleTab = tabButton(in: app, tab: .schedule)
        XCTAssertTrue(waitForElement(scheduleTab, in: app, identifier: "main_tab_schedule"))
        scheduleTab.tap()
        attachAppStoreScreenshot(app: app, name: "02_schedule_month")

        let syncFab = app.buttons["schedule_sync_fab"]
        XCTAssertTrue(waitForElement(syncFab, in: app, identifier: "schedule_sync_fab"))
        syncFab.tap()
        let syncSheet = app.descendants(matching: .any).matching(identifier: "schedule_sync_sheet").firstMatch
        XCTAssertTrue(waitForElement(syncSheet, in: app, identifier: "schedule_sync_sheet"))
        attachAppStoreScreenshot(app: app, name: "03_schedule_sync_sheet")
        syncSheet.swipeDown()

        let messageTab = tabButton(in: app, tab: .message)
        XCTAssertTrue(waitForElement(messageTab, in: app, identifier: "main_tab_message"))
        messageTab.tap()
        let messageFeed = app.scrollViews["message_feed_scroll"]
        XCTAssertTrue(waitForElement(messageFeed, in: app, identifier: "message_feed_scroll"))
        attachAppStoreScreenshot(app: app, name: "04_message_feed")

        let myTab = tabButton(in: app, tab: .my)
        XCTAssertTrue(waitForElement(myTab, in: app, identifier: "main_tab_my"))
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
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["BLM_UI_TEST_MODE"] = "1"
        app.launchEnvironment["BLM_UI_TEST_RESET_STATE"] = "1"
        app.launchEnvironment["BLM_USE_MOCK_DATA"] = "1"
        app.launchEnvironment["BLM_FORCE_NEW_USER_FLOW"] = "0"
        if let executionLane {
            app.launchEnvironment["BLM_UI_TEST_EXECUTION_LANE"] = executionLane
        }

        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.terminate()
        }
    }
}
