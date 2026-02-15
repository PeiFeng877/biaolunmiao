//
//  MyHubView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: MessageInboxViewModel 与 ProfileSettingsViewModel 的状态。
//  OUTPUT: 我的页主入口（消息/设置分段）与消息详情路由。
//  POS: 我的 Tab 根页面。
//

import SwiftUI

private enum MyHubTab: String, CaseIterable, Identifiable {
    case message = "消息"
    case settings = "设置"

    var id: String { rawValue }
}

struct MyHubView: View {
    @StateObject private var messageViewModel: MessageInboxViewModel
    @StateObject private var settingsViewModel: ProfileSettingsViewModel
    @State private var selectedTab: MyHubTab = .message
    @State private var navigationPath: [UUID] = []

    init(store: AppStore) {
        _messageViewModel = StateObject(wrappedValue: MessageInboxViewModel(store: store))
        _settingsViewModel = StateObject(wrappedValue: ProfileSettingsViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    Picker("我的分段", selection: $selectedTab) {
                        ForEach(MyHubTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.s)
                    .accessibilityIdentifier("my_hub_segmented")

                    switch selectedTab {
                    case .message:
                        MessageInboxView(viewModel: messageViewModel) { requestId in
                            navigationPath.append(requestId)
                        }
                    case .settings:
                        ProfileSettingsView(viewModel: settingsViewModel)
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { requestId in
                JoinRequestMessageDetailView(viewModel: messageViewModel, requestId: requestId)
            }
        }
    }
}

#Preview {
    MyHubView(store: AppStore())
}
