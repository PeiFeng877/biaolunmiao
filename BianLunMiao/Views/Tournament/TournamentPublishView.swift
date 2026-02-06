//
//  TournamentPublishView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: TournamentPublishViewModel 提供的发布摘要。
//  OUTPUT: 发布赛事页面。
//  POS: 赛事发布流程页面。
//

import SwiftUI

struct TournamentPublishView: View {
    @StateObject private var viewModel: TournamentPublishViewModel
    @Environment(\.dismiss) private var dismiss

    init(summary: TournamentPublishViewModel.Summary) {
        _viewModel = StateObject(wrappedValue: TournamentPublishViewModel(summary: summary))
    }

    var body: some View {
        ZStack {
            AppColor.eventBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TournamentSetupTopBar(title: "发布赛事", onBack: { dismiss() })
                TournamentSetupProgress(step: 3, total: 3, title: "确认发布")

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        summaryCard

                        AppCard(
                            style: .standard,
                            stroke: AppColor.eventStroke,
                            background: { AppColor.eventCard }
                        ) {
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                Text("发布提示")
                                    .font(AppFont.section())
                                    .foregroundStyle(AppColor.eventText)
                                Text("发布后赛事将对外展示，赛程与队伍信息可继续在管理页调整。")
                                    .font(AppFont.body())
                                    .foregroundStyle(AppColor.eventMuted)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            TournamentPublishBottomBar(
                leftText: "准备就绪",
                actionTitle: "立即发布",
                action: {}
            )
        }
    }

    private var summaryCard: some View {
        AppCard(
            style: .standard,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text(viewModel.summary.tournamentName)
                    .font(AppFont.title())
                    .foregroundStyle(AppColor.eventText)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.m) {
                    Label(viewModel.summary.dateRange, systemImage: "calendar")
                    Label("\(viewModel.summary.roundsCount) 轮赛程", systemImage: "flag.checkered")
                }
                .font(AppFont.caption())
                .foregroundStyle(AppColor.eventMuted)

                HStack(spacing: AppSpacing.m) {
                    Label(viewModel.summary.location, systemImage: "mappin.and.ellipse")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.eventMuted)
                }
            }
        }
    }
}

#Preview {
    TournamentPublishView(
        summary: TournamentPublishViewModel.Summary(
            tournamentName: "2024 夏季全国辩论锦标赛",
            roundsCount: 2,
            dateRange: "2023-11-15 - 2023-11-20",
            location: "线上 - 腾讯会议 A厅"
        )
    )
}
