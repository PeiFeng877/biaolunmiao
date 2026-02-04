//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
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
                        Label("我的", systemImage: "person.crop.circle")
                    }
                
                TournamentListView(store: store)
                    .tabItem {
                        Label("赛事", systemImage: "trophy")
                    }
                
                ScheduleView(store: store)
                    .tabItem {
                        Label("日程", systemImage: "calendar")
                    }
            }
        }
    }
}
