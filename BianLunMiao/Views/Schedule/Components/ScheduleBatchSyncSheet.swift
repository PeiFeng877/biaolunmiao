//
//  ScheduleBatchSyncSheet.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 待同步赛程列表与赛事/队伍展示字段。
//  OUTPUT: 批量同步选择面板与确认动作。
//  POS: 日程页批量同步组件。
//

import SwiftUI

struct ScheduleBatchSyncSheet: View {
    @Environment(\.dismiss) private var dismiss

    let matches: [Match]
    let tournamentNameProvider: (Match) -> String?
    let teamsLineProvider: (Match) -> String
    let onSync: ([Match]) -> Void

    @State private var selectedMatchIDs: Set<UUID>

    init(
        matches: [Match],
        tournamentNameProvider: @escaping (Match) -> String?,
        teamsLineProvider: @escaping (Match) -> String,
        onSync: @escaping ([Match]) -> Void
    ) {
        self.matches = matches
        self.tournamentNameProvider = tournamentNameProvider
        self.teamsLineProvider = teamsLineProvider
        self.onSync = onSync
        _selectedMatchIDs = State(initialValue: Set(matches.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    header

                    if matches.isEmpty {
                        ScrollView {
                            AppCard {
                                AppEmptyState(
                                    title: "暂无赛程可同步",
                                    subtitle: "添加赛事或关注数据源后再来试试",
                                    systemImage: "calendar"
                                )
                            }
                            .padding(.horizontal, AppSpacing.inset)
                            .padding(.top, AppSpacing.l)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: AppSpacing.s) {
                                ForEach(matches) { match in
                                    matchRow(match)
                                }
                            }
                            .padding(.horizontal, AppSpacing.inset)
                            .padding(.top, AppSpacing.s)
                            .padding(.bottom, AppSpacing.l)
                        }
                        .accessibilityIdentifier("schedule_sync_scroll")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                syncActionBar
            }
            .navigationTitle("同步数据")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("schedule_sync_sheet")
    }

    private var header: some View {
        HStack(spacing: AppSpacing.s) {
            Text("共 \(matches.count) 条赛程")
                .font(AppFont.body())
                .foregroundStyle(AppColor.textSecondary)

            Spacer()

            AppButton(allSelected ? "取消全选" : "全选", variant: .toolbarText) {
                if allSelected {
                    selectedMatchIDs.removeAll()
                } else {
                    selectedMatchIDs = Set(matches.map(\.id))
                }
            }
            .accessibilityIdentifier("schedule_sync_select_all_button")
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.top, AppSpacing.s)
    }

    private var syncActionBar: some View {
        VStack(spacing: AppSpacing.s) {
            AppButton("同步到日历 (\(selectedMatches.count))", variant: .primary) {
                onSync(selectedMatches)
                dismiss()
            }
            .disabled(selectedMatches.isEmpty)
            .padding(.horizontal, AppSpacing.inset)
            .padding(.bottom, AppSpacing.l)
            .accessibilityIdentifier("schedule_sync_confirm_button")
        }
        .padding(.top, AppSpacing.s)
        .background(
            AppColor.background.opacity(0.96)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColor.stroke.opacity(0.24))
                        .frame(height: 1)
                }
        )
    }

    private var selectedMatches: [Match] {
        matches.filter { selectedMatchIDs.contains($0.id) }
    }

    private var allSelected: Bool {
        !matches.isEmpty && selectedMatchIDs.count == matches.count
    }

    private func matchRow(_ match: Match) -> some View {
        let isSelected = selectedMatchIDs.contains(match.id)
        let tournamentName = tournamentNameProvider(match) ?? "未关联赛事"
        let teamsLine = teamsLineProvider(match)

        return AppCard(style: .standard, padding: AppSpacing.m) {
            AppRowTapButton {
                if isSelected {
                    selectedMatchIDs.remove(match.id)
                } else {
                    selectedMatchIDs.insert(match.id)
                }
            } label: {
                HStack(alignment: .top, spacing: AppSpacing.s) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(AppFont.icon())
                        .foregroundStyle(isSelected ? AppColor.primaryStrong : AppColor.textSecondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.name)
                            .font(AppFont.body().weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(2)

                        Text(tournamentName)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)

                        Text(teamsLine)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textMuted)
                            .lineLimit(1)

                        Text("\(match.startTime.formatted(.dateTime.month().day().hour().minute())) - \(match.endTime.formatted(.dateTime.hour().minute()))")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)

                        if let location = match.location,
                           !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("地点：\(location)")
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.textMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .accessibilityIdentifier("schedule_sync_match_toggle_\(match.id.uuidString)")
            .accessibilityValue(isSelected ? "已选中" : "未选中")
        }
    }
}
