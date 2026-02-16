//
//  MessageHubView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/15.
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: MessageInboxViewModel 的消息流状态与详情路由。
//  OUTPUT: 消息 Tab 根页面（收件箱 + 详情导航）。
//  POS: 消息 Tab 根页面。
//

import SwiftUI

struct MessageHubView: View {
    @StateObject private var viewModel: MessageInboxViewModel
    @State private var navigationPath: [UUID] = []

    init(store: AppStore) {
        _viewModel = StateObject(wrappedValue: MessageInboxViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

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
                }
            }
            .navigationDestination(for: UUID.self) { requestId in
                JoinRequestMessageDetailView(viewModel: viewModel, requestId: requestId)
                    .toolbar(.visible, for: .navigationBar)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    MessageHubView(store: AppStore())
}
