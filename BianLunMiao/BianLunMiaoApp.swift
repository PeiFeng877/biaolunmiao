//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  Updated by Codex on 2026/2/15.
//
//  INPUT: AppStore 与主导航结构。
//  OUTPUT: 应用入口与全局主题注入（5 Tab）。
//  POS: App 入口层。
//

import SwiftUI

@main
struct BianLunMiaoApp: App {
    @StateObject private var store = AppStore()

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
}
