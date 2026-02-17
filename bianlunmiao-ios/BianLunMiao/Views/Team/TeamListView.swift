//
//  TeamListView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: TeamListViewModel 提供的队伍列表。
//  OUTPUT: 带创建/申请入口的队伍主页。
//  POS: 队伍 Tab 根页面。
//

import SwiftUI

struct TeamListView: View {
    @StateObject private var viewModel: TeamListViewModel
    private let store: AppStore
    @State private var navigationPath: [UUID] = []
    @State private var showJoinSheet = false
    @State private var showSearchPage = false
    @State private var toast: AppToastPayload?

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    AppTopBar(
                        title: "队伍",
                        style: .team,
                        showsLeadingIcon: false,
                        secondaryActionSystemName: "magnifyingglass",
                        onSecondaryAction: { showSearchPage = true },
                        onAdd: { viewModel.showCreateSheet = true }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.l) {
                            if viewModel.teams.isEmpty {
                                TeamEmptyStateCard(
                                    onCreate: { viewModel.showCreateSheet = true },
                                    onJoin: { showJoinSheet = true }
                                )
                            } else {
                                VStack(spacing: AppSpacing.m) {
                                    ForEach(viewModel.teams) { team in
                                        AppRowTapButton {
                                            navigationPath.append(team.id)
                                        } label: {
                                            TeamCard(team: team, isOwner: viewModel.isOwner(team: team))
                                                .contentShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
                                        }
                                        // 导航型卡片用统一行点击按钮，避免业务层裸 Button。
                                    }
                                }
                            }

                            Text("共 \(viewModel.teams.count) 支")
                                .font(AppFont.caption())
                                .tracking(AppFont.tracking)
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.horizontal, AppSpacing.inset)
                        .padding(.top, AppSpacing.l)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { teamId in
                TeamDetailView(store: store, teamId: teamId)
            }
            .navigationDestination(isPresented: $showSearchPage) {
                TeamSearchView(viewModel: viewModel)
            }
            .toolbar(.hidden, for: .navigationBar)
            .appSheet(isPresented: $viewModel.showCreateSheet) {
                CreateTeamSheet { profile in
                    let team = viewModel.createTeam(
                        name: profile.name,
                        slogan: profile.slogan,
                        avatarImageData: profile.avatarImageData
                    )
                    navigationPath.append(team.id)
                }
            }
            .appSheet(isPresented: $showJoinSheet) {
                JoinTeamSheet(defaultPersonalNote: viewModel.currentUserNickname) { publicId, personalNote, reason in
                    let result = viewModel.submitJoinRequestByPublicId(
                        publicId: publicId,
                        personalNote: personalNote,
                        reason: reason
                    )
                    if case .success = result {
                        toast = AppToastPayload(
                            title: "申请已提交",
                            message: "等待审批",
                            intent: .success
                        )
                    }
                    return result
                }
            }
            .appToast(item: $toast)
        }
    }
}

#Preview {
    TeamListView(store: AppStore())
}

private struct TeamEmptyStateCard: View {
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: AppSpacing.l) {
                AppEmptyState(
                    title: "还没有队伍",
                    subtitle: "创建或加入队伍，开始第一场辩论",
                    systemImage: "flag.checkered"
                )

                VStack(spacing: AppSpacing.s) {
                    AppButton("创建队伍", variant: .primary, action: onCreate)

                    AppButton("加入队伍", variant: .secondary, action: onJoin)
                }
            }
        }
    }
}

private struct TeamCard: View {
    let team: Team
    let isOwner: Bool

    var body: some View {
        AppCard(style: .standard) {
            TeamRow(team: team, isOwner: isOwner)
        }
    }
}
