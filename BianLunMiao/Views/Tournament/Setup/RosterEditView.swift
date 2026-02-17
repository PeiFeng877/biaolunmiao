//
//  RosterEditView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: Match、Team 与已存在阵容。
//  OUTPUT: 队员指派编辑界面。
//  POS: 赛程指派弹窗。
//

import SwiftUI

struct RosterEditView: View {
    @Environment(\.dismiss) private var dismiss

    let match: Match
    let team: Team
    let onSave: ([RosterAssignment]) -> Bool

    @State private var assignments: [UUID: String]
    @State private var errorMessage: String?

    init(
        match: Match,
        team: Team,
        existingAssignments: [RosterAssignment] = [],
        onSave: @escaping ([RosterAssignment]) -> Bool
    ) {
        self.match = match
        self.team = team
        self.onSave = onSave
        _assignments = State(
            initialValue: Dictionary(uniqueKeysWithValues: existingAssignments.map { ($0.userId, $0.position) })
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        Text("选择上场队员（\(match.format.rawValue)）")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.danger)
                        }

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
                                                    .foregroundStyle(AppColor.textSecondary)
                                            }

                                            Spacer()

                                            if let position = assignments[member.userId] {
                                                AppBadge(text: position, color: AppColor.primary)
                                            } else {
                                                AppTag(text: "未上场", color: AppColor.textSecondary)
                                            }
                                        }
                                        .padding(.vertical, AppSpacing.m)
                                    }

                                    if member.id != team.members.last?.id {
                                        Divider().overlay(AppColor.stroke)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.l)
                        }

                        AppButton("保存指派", variant: .primary) {
                            let payload = assignments.map { RosterAssignment(userId: $0.key, position: $0.value) }
                            let success = onSave(payload)
                            if success {
                                dismiss()
                            } else {
                                errorMessage = "保存失败，请检查阵容和权限"
                            }
                        }
                        .accessibilityIdentifier("roster_save_button")
                        .disabled(assignments.isEmpty)
                        .opacity(assignments.isEmpty ? 0.56 : 1)
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

    private func toggleSelection(for userId: UUID) {
        if assignments[userId] != nil {
            assignments.removeValue(forKey: userId)
            return
        }

        let usedPositions = Set(assignments.values)
        guard let nextPosition = match.format.positions.first(where: { !usedPositions.contains($0) }) else {
            errorMessage = "当前赛制最多 \(match.format.positions.count) 人"
            return
        }

        assignments[userId] = nextPosition
        errorMessage = nil
    }
}
