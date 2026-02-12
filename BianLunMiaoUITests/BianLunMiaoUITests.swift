//
//  BianLunMiaoUITests.swift
//  BianLunMiaoUITests
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 应用可交互界面与启动行为。
//  OUTPUT: UI 流程断言与性能采样结果。
//  POS: UI 自动化测试入口层。
//

import XCTest

final class BianLunMiaoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testTournamentFlowFromListToMatchCreation() throws {
        let app = XCUIApplication()
        app.launch()

        let tournamentTab = app.tabBars.buttons["trophy"]
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

        XCTAssertTrue(app.staticTexts["自动化创建场次"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
