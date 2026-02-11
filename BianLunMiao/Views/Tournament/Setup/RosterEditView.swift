//
//  RosterEditView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: Match 与 Team 信息。
//  OUTPUT: 队员指派选择界面。
//  POS: 赛程指派弹窗。
//

import SwiftUI

struct RosterEditView: View {
    @Environment(\.dismiss) var dismiss
    let match: Match
    let team: Team

    @State private var assignments: [UUID: String] = [:]
    var onSave: ([Roster]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        Text("选择上场队员 (\(match.format.rawValue))")
                            .font(AppFont.caption())
                            .foregroundColor(AppColor.textMuted)

                        AppCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(team.members) { member in
                                    AppRowTapButton {
                                        toggleSelection(for: member.userId)
                                    } label: {
                                        HStack(spacing: AppSpacing.m) {
                                            Circle()
                                                .fill(AppColor.surface)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Text(member.user.nickname.prefix(1))
                                                        .font(AppFont.body())
                                                        .foregroundStyle(AppColor.textSecondary)
                                                )

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(member.user.nickname)
                                                    .font(AppFont.body())
                                                    .foregroundStyle(AppColor.textPrimary)
                                                Text(member.role.title)
                                                    .font(AppFont.caption())
                                                    .foregroundStyle(AppColor.textMuted)
                                            }

                                            Spacer()

                                            if let pos = assignments[member.userId] {
                                                AppBadge(text: pos, color: AppColor.primary)
                                            } else {
                                                AppTag(text: "待定", color: AppColor.textMuted)
                                            }
                                        }
                                        .padding(.vertical, AppSpacing.m)
                                    }

                                    if member.id != team.members.last?.id {
                                        Divider().overlay(AppColor.outline)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.l)
                        }

                        AppButton("保存指派", variant: .primary) {
                            let rosters = assignments.map { (uid, pos) in
                                Roster(id: UUID(), matchId: match.id, teamId: team.id, userId: uid, position: pos)
                            }
                            onSave(rosters)
                            dismiss()
                        }
                        .disabled(assignments.isEmpty)
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("排兵布阵")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppButton("取消", variant: .toolbarText) { dismiss() }
                }
            }
        }
    }

    private func toggleSelection(for uid: UUID) {
        if assignments[uid] != nil {
            assignments.removeValue(forKey: uid)
        } else {
            let count = assignments.count
            let positions = match.format.positions
            if count < positions.count {
                assignments[uid] = positions[count]
            }
        }
    }
}
