//
//  BianLunMiaoSTGSmokeUITests.swift
//  BianLunMiaoUITests
//
//  Created by Codex on 2026/3/19.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: STG 环境 + 只读 UI 链路。
//  OUTPUT: STG 快速健康验证结果。
//  POS: UI 自动化-stg-smoke lane。
//

import XCTest

final class BianLunMiaoSTGSmokeUITests: BianLunMiaoUIBaseTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireExecutionLane(.stgSmoke)
    }

    @MainActor
    func testSTGSmokeCanReachMainTabs() throws {
        let app = launchSTGSmokeApp()
        assertCanReachMainTabs(in: app, timeout: 20)
    }
}
