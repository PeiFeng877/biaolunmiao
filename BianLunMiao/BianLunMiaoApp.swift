//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  Updated by Codex on 2026/2/15.
//
//  INPUT: AppStore 与主导航结构。
//  OUTPUT: 应用入口与全局主题注入（5 Tab）。
//  POS: App 入口层。
//

import SwiftUI
import UIKit

@main
struct BianLunMiaoApp: App {
    @StateObject private var store: AppStore

    init() {
        Self.applyUITestRuntimeConfiguration()
        _store = StateObject(wrappedValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                TeamListView(store: store)
                    .tabItem {
                        Label("队伍", systemImage: "person.crop.circle")
                    }

                TournamentListView(store: store)
                    .tabItem {
                        Label("赛事", systemImage: "trophy")
                    }

                ScheduleView(store: store)
                    .tabItem {
                        Label("日程", systemImage: "calendar")
                    }

                MessageHubView(store: store)
                    .tabItem {
                        Label("消息", systemImage: "bubble.left.and.bubble.right")
                    }

                MyHubView(store: store)
                    .tabItem {
                        Label("我的", systemImage: "person.text.rectangle")
                    }
            }
            .tint(AppColor.eventAccentStrong)
            .toolbar(.visible, for: .tabBar)
            .dismissKeyboardOnTap()
        }
    }

    private static func applyUITestRuntimeConfiguration() {
        let env = ProcessInfo.processInfo.environment
        guard env["BLM_UI_TEST_MODE"] == "1" else { return }

        UIView.setAnimationsEnabled(false)

        guard env["BLM_UI_TEST_RESET_STATE"] == "1",
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        UserDefaults.standard.synchronize()
    }
}
