//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: AppStore 与主导航结构。
//  OUTPUT: 应用入口与全局主题注入。
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
                        Image(systemName: "person.crop.circle")
                    }

                TournamentListView(store: store)
                    .tabItem {
                        Image(systemName: "trophy")
                    }

                MessageInboxView(store: store)
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }

                ScheduleView(store: store)
                    .tabItem {
                        Image(systemName: "calendar")
                    }
            }
            .tint(AppColor.eventAccentStrong)
            .toolbar(.visible, for: .tabBar)
            .dismissKeyboardOnTap()
        }
    }
}
