//
//  TournamentScheduleSetupView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: TournamentScheduleSetupViewModel 提供的轮次配置。
//  OUTPUT: 赛程设定页面。
//  POS: 赛事设定流程页面。
//

import SwiftUI

struct TournamentScheduleSetupView: View {
    @StateObject private var viewModel: TournamentScheduleSetupViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPublish = false

    init(tournamentName: String) {
        _viewModel = StateObject(wrappedValue: TournamentScheduleSetupViewModel(tournamentName: tournamentName))
    }

    var body: some View {
        ZStack {
            AppColor.eventBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TournamentSetupTopBar(title: "赛程设定", onBack: { dismiss() })
                TournamentSetupProgress(step: 2, total: 3, title: "安排赛程")

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        HStack {
                            Text("比赛轮次")
                                .font(AppFont.section())
                                .foregroundStyle(AppColor.eventText)
                            Spacer()
                            AppButton("重置", variant: .toolbarText) {
                                viewModel.resetRounds()
                            }
                        }

                        ForEach($viewModel.rounds) { $round in
                            TournamentRoundCard(
                                round: $round,
                                onDelete: { viewModel.removeRound(id: round.id) },
                                canDelete: viewModel.rounds.count > 1
                            )
                        }

                        TournamentAddRoundButton {
                            viewModel.addRound()
                        }

                        HStack(alignment: .top, spacing: AppSpacing.s) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(AppColor.eventMuted)
                            Text("赛程设定仅用于基础框架，详细辩题与评委分配可在赛事管理中继续完善。")
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.eventMuted)
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
                leftText: "总计轮次 \(viewModel.rounds.count) 场",
                actionTitle: "立即发布",
                action: { showPublish = true }
            )
        }
        .navigationDestination(isPresented: $showPublish) {
            TournamentPublishView(summary: viewModel.summary)
        }
    }
}

#Preview {
    TournamentScheduleSetupView(tournamentName: "2024 夏季全国辩论锦标赛")
}
