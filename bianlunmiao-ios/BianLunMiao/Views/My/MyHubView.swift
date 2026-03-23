//
//  MyHubView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: ProfileSettingsViewModel 的状态。
//  OUTPUT: 我的页主入口（资料、记录与更多路由）。
//  POS: 我的 Tab 根页面。
//

import SwiftUI

struct MyHubView: View {
    @StateObject private var settingsViewModel: ProfileSettingsViewModel
    private let store: AppStore
    @State private var showMorePage = false
    @State private var toast: AppToastPayload?

    init(store: AppStore) {
        self.store = store
        _settingsViewModel = StateObject(wrappedValue: ProfileSettingsViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("my_hub_root")

                VStack(spacing: 0) {
                    AppTopBar(
                        title: "我的",
                        style: .brand,
                        showsLeadingIcon: false,
                        secondaryActionSystemName: "ellipsis.circle",
                        secondaryActionAccessibilityTitle: "更多",
                        secondaryActionAccessibilityId: "my_more_button",
                        onSecondaryAction: { showMorePage = true },
                        showsAddAction: true,
                        addActionSystemName: "square.and.pencil",
                        addAccessibilityTitle: "编辑资料",
                        addAccessibilityId: "my_edit_profile_button",
                        onAdd: { settingsViewModel.beginEditProfile() }
                    )

                    ProfileSettingsView(viewModel: settingsViewModel)
                        .refreshable {
                            await refreshAppData()
                        }
                }
            }
            .navigationDestination(isPresented: $showMorePage) {
                ProfileMoreView(viewModel: settingsViewModel)
            }
            .toolbar(.hidden, for: .navigationBar)
            .appToast(item: $toast)
        }
    }

    @MainActor
    private func refreshAppData() async {
        do {
            try await store.refreshNow(force: true)
        } catch {
            toast = AppToastPayload(
                title: "刷新失败",
                message: error.localizedDescription,
                intent: .error
            )
        }
    }
}

#Preview {
    MyHubView(store: AppStore())
}
