//
//  MessageHubView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/15.
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: MessageInboxViewModel 的消息流状态与详情路由。
//  OUTPUT: 消息 Tab 根页面（收件箱 + 详情导航）。
//  POS: 消息 Tab 根页面。
//

import SwiftUI

struct MessageHubView: View {
    @StateObject private var viewModel: MessageInboxViewModel
    private let store: AppStore
    @State private var navigationPath: [UUID] = []
    @State private var toast: AppToastPayload?

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: MessageInboxViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("message_hub_root")

                VStack(spacing: 0) {
                    AppTopBar(
                        title: "消息",
                        style: .brand,
                        showsLeadingIcon: false,
                        showsAddAction: false,
                        onAdd: {}
                    )

                    MessageInboxView(viewModel: viewModel) { requestId in
                        navigationPath.append(requestId)
                    }
                    .refreshable {
                        await refreshAppData()
                    }
                }
            }
            .navigationDestination(for: UUID.self) { requestId in
                JoinRequestMessageDetailView(viewModel: viewModel, requestId: requestId)
                    .toolbar(.visible, for: .navigationBar)
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
    MessageHubView(store: AppStore())
}
