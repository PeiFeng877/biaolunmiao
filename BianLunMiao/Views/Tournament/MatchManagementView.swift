//
//  MatchManagementView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: MatchManagementViewModel 提供的赛程列表。
//  OUTPUT: 赛程管理与指派入口。
//  POS: 赛事详情页。
//

import SwiftUI

struct MatchManagementView: View {
    @StateObject private var viewModel: MatchManagementViewModel

    init(store: AppStore, tournamentId: UUID) {
        _viewModel = StateObject(wrappedValue: MatchManagementViewModel(store: store, tournamentId: tournamentId))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    AppSectionHeader("全部场次", trailing: "共 \(viewModel.matches.count) 场")

                    if viewModel.matches.isEmpty {
                        AppCard {
                            AppEmptyState(title: "暂无赛程", subtitle: "先创建一场比赛", systemImage: "flag")
                        }
                    } else {
                        AppCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(viewModel.matches) { match in
                                    Button {
                                        viewModel.selectMatchIfCaptain(match)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(match.name)
                                                    .font(AppFont.body())
                                                    .foregroundStyle(AppColor.textPrimary)
                                                Spacer()
                                                AppTag(text: match.format.rawValue, color: AppColor.primary)
                                            }

                                            Text(match.startTime.formatted(date: .numeric, time: .shortened))
                                                .font(AppFont.caption())
                                                .foregroundStyle(AppColor.textMuted)

                                            HStack(spacing: 6) {
                                                Text(match.teamA?.name ?? "待定")
                                                    .font(AppFont.body())
                                                Text("VS")
                                                    .font(AppFont.caption())
                                                    .foregroundStyle(AppColor.textMuted)
                                                Text(match.teamB?.name ?? "待定")
                                                    .font(AppFont.body())
                                            }
                                            .foregroundStyle(AppColor.textSecondary)
                                        }
                                        .padding(.vertical, AppSpacing.m)
                                    }
                                    .buttonStyle(.plain)

                                    if match.id != viewModel.matches.last?.id {
                                        Divider().overlay(AppColor.outline)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.l)
                        }
                    }

                    Button("添加赛程") {
                        viewModel.addMatch()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationTitle("赛程")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.selectedMatchForRoster) { match in
            if let team = viewModel.myTeamInMatch {
                RosterEditView(match: match, team: team) { rosters in
                    viewModel.saveRosters(rosters)
                }
            }
        }
    }
}
