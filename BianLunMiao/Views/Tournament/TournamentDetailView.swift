//
//  TournamentDetailView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: TournamentDetailViewModel 提供的赛事详情状态。
//  OUTPUT: 赛事详情页面。
//  POS: 赛事详情展示层。
//

import SwiftUI

struct TournamentDetailView: View {
    @StateObject private var viewModel: TournamentDetailViewModel
    @State private var selectedTab: TournamentDetailTab = .overview
    @State private var selectedDayId: UUID? = nil

    init(store: AppStore, card: TournamentListViewModel.TournamentCard) {
        _viewModel = StateObject(wrappedValue: TournamentDetailViewModel(store: store, card: card))
    }

    var body: some View {
        ZStack {
            AppColor.eventBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TournamentDetailTopBar(
                    onBack: { dismiss() },
                    onShare: {}
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        TournamentDetailHeader(
                            title: viewModel.card.headline,
                            statusText: statusText,
                            statusColor: statusColor,
                            dateRange: viewModel.dateRangeText,
                            teamCount: viewModel.teams.count
                        )

                        TournamentDetailTabBar(
                            tabs: TournamentDetailTab.allCases,
                            selected: $selectedTab
                        )

                        detailContent
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .overview:
            TournamentOverviewCard(text: viewModel.overviewText)
        case .schedule:
            TournamentScheduleView(
                days: viewModel.scheduleDays,
                selectedDayId: $selectedDayId
            )
        case .teams:
            TournamentTeamsView(teams: viewModel.teamEntries)
        }
    }

    private var statusText: String {
        switch viewModel.card.status {
        case .draft:
            return "待发布"
        case .open:
            return "报名中"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        case .cancelled:
            return "已取消"
        }
    }

    private var statusColor: Color {
        switch viewModel.card.status {
        case .draft:
            return AppColor.eventMuted
        case .open:
            return AppColor.eventAccentStrong
        case .ongoing:
            return AppColor.eventAccentStrong
        case .ended:
            return AppColor.textSecondary
        case .cancelled:
            return AppColor.danger
        }
    }
}

#Preview {
    TournamentDetailView(
        store: AppStore(),
        card: TournamentListViewModel.TournamentCard(
            id: UUID(),
            headline: "2024 夏季全国辩论锦标赛",
            subheadline: "校园赛海选 · 热血开战",
            status: .open,
            participantCount: 128,
            dateText: "10月24日 - 11月01日",
            locationText: "线上 · 腾讯会议",
            isFeatured: true
        )
    )
}
