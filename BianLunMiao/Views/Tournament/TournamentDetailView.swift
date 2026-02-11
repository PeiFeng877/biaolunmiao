//
//  TournamentDetailView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: TournamentDetailViewModel 提供的赛事详情状态。
//  OUTPUT: 赛事管理页。
//  POS: 赛事详情展示层。
//

import SwiftUI

struct TournamentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TournamentDetailViewModel

    @State private var selectedTab: TournamentDetailTab = .overview
    @State private var showMatchManagement = false

    private let store: AppStore

    init(store: AppStore, tournamentId: UUID) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TournamentDetailViewModel(store: store, tournamentId: tournamentId))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                AppDetailTopBar(
                    title: viewModel.tournament.name,
                    onBack: { dismiss() },
                    trailingSystemName: viewModel.canManage ? "square.and.pencil" : nil,
                    onTrailingAction: viewModel.canManage ? { showMatchManagement = true } : nil
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        TournamentDetailHeaderCard(
                            title: viewModel.tournament.name,
                            intro: viewModel.introText,
                            statusText: viewModel.statusText,
                            statusToken: viewModel.statusColor,
                            participantCount: viewModel.participantTeams.count,
                            matchCount: viewModel.matches.count
                        )

                        if viewModel.canManage {
                            AppButton("进入赛程管理", variant: .secondary) {
                                showMatchManagement = true
                            }
                            .accessibilityIdentifier("tournament_match_management_entry")
                        }

                        TournamentDetailTabBar(selected: $selectedTab)

                        tabContent
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showMatchManagement) {
            MatchManagementView(store: store, tournamentId: viewModel.tournament.id)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .schedule:
            scheduleContent
        case .teams:
            teamsContent
        }
    }

    private var overviewContent: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("流程")
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)
                Text("创建赛事 -> 创建赛程 -> 指派参赛队伍 -> 记录赛果")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var scheduleContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader("赛程", trailing: "共 \(viewModel.matches.count) 场")

            if viewModel.matches.isEmpty {
                AppCard {
                    AppEmptyState(
                        title: "暂无赛程",
                        subtitle: "进入赛程管理创建第一场比赛",
                        systemImage: "flag.checkered"
                    )
                }
            } else {
                VStack(spacing: AppSpacing.m) {
                    ForEach(viewModel.matches) { match in
                        TournamentMatchItemCard(
                            match: match,
                            teamAName: viewModel.teamName(for: match.teamAId),
                            teamBName: viewModel.teamName(for: match.teamBId),
                            scoreText: viewModel.scoreText(for: match)
                        )
                    }
                }
            }
        }
    }

    private var teamsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader("参赛队伍", trailing: "共 \(viewModel.participantTeams.count) 支")

            if viewModel.participantTeams.isEmpty {
                AppCard {
                    AppEmptyState(
                        title: "暂无参赛队伍",
                        subtitle: "在赛程中指派 A/B 队后会自动入池",
                        systemImage: "person.2"
                    )
                }
            } else {
                VStack(spacing: AppSpacing.m) {
                    ForEach(viewModel.participantTeams) { team in
                        TournamentParticipantCard(team: team)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TournamentDetailView(
            store: AppStore(),
            tournamentId: MockData.shared.tournaments.first?.id ?? UUID()
        )
    }
}
