//
//  TeamSearchView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: TeamListViewModel 提供的队伍搜索与入队申请能力。
//  OUTPUT: 队伍搜索页（结果卡片 + 入队申请弹窗）。
//  POS: 队伍列表的二级页面。
//

import SwiftUI

struct TeamSearchView: View {
    @ObservedObject var viewModel: TeamListViewModel

    @State private var query = ""
    @State private var targetTeam: Team?
    @State private var toast: AppToastPayload?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    AppSearchBar(
                        text: $query,
                        placeholder: "输入队伍名称或队伍 ID",
                        style: .standard
                    )

                    if results.isEmpty {
                        AppCard {
                            AppEmptyState(
                                title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请输入关键词" : "没有找到匹配队伍",
                                subtitle: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "你可以按队伍名或 ID 进行搜索" : "试试更短的关键词，或直接输入完整队伍 ID",
                                systemImage: "magnifyingglass"
                            )
                        }
                    } else {
                        VStack(spacing: AppSpacing.m) {
                            ForEach(results) { team in
                                TeamSearchResultCard(
                                    team: team,
                                    intro: intro(for: team),
                                    isMember: viewModel.isMember(team: team),
                                    onApply: { targetTeam = team }
                                )
                            }
                        }

                        Text("找到 \(results.count) 支")
                            .font(AppFont.caption())
                            .tracking(AppFont.tracking)
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, AppSpacing.inset)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationTitle("搜索队伍")
        .navigationBarTitleDisplayMode(.inline)
        .appSheet(item: $targetTeam) { team in
            JoinTeamApplicationSheet(
                team: team,
                defaultPersonalNote: viewModel.currentUserNickname
            ) { personalNote, reason in
                _ = try await viewModel.submitJoinRequestByTeamId(
                    teamId: team.id,
                    personalNote: personalNote,
                    reason: reason
                )
                toast = AppToastPayload(
                    title: "申请已提交",
                    message: team.name,
                    intent: .success
                )
            }
        }
        .appToast(item: $toast)
    }

    private var results: [Team] {
        viewModel.searchableTeams(query: query)
    }

    private func intro(for team: Team) -> String {
        let slogan = team.slogan?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !slogan.isEmpty {
            return slogan
        }
        return "暂无队伍 Slogan"
    }
}

private struct TeamSearchResultCard: View {
    let team: Team
    let intro: String
    let isMember: Bool
    let onApply: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(alignment: .top, spacing: AppSpacing.m) {
                    NavigationLink(value: team.id) {
                        HStack(alignment: .top, spacing: AppSpacing.m) {
                            TeamAvatarView(team: team, size: 44)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(team.name)
                                    .font(AppFont.body())
                                    .foregroundStyle(AppColor.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("ID: \(team.publicId)")
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppColor.textMuted)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                        }
                    }
                    .buttonStyle(AppRowTapButtonStyle())

                    Spacer(minLength: 0)

                    if !isMember {
                        AppButton("申请入队", variant: .compactSecondary, action: onApply)
                    }
                }

                Text(intro)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct JoinTeamApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let team: Team
    let onSubmit: (String, String) async throws -> Void

    @State private var personalNote: String
    @State private var reason = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    init(
        team: Team,
        defaultPersonalNote: String,
        onSubmit: @escaping (String, String) async throws -> Void
    ) {
        self.team = team
        self.onSubmit = onSubmit
        _personalNote = State(initialValue: defaultPersonalNote)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                Text(team.name)
                                    .font(AppFont.section())
                                    .foregroundStyle(AppColor.textPrimary)
                                Text("ID: \(team.publicId)")
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppColor.textMuted)
                                    .monospacedDigit()
                            }
                        }

                        AppFormField(
                            title: "个人备注（必填）",
                            error: errorMessage
                        ) {
                            AppTextField(placeholder: "请输入个人备注", text: $personalNote)
                        }

                        AppFormField(title: "申请理由（选填）") {
                            AppTextEditor(placeholder: "补充你的申请理由", text: $reason)
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) { dismiss() }

                            AppButton("提交申请", variant: .primary) {
                                Task {
                                    await submit()
                                }
                            }
                            .disabled(personalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                            .opacity((personalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting) ? 0.56 : 1)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("申请入队")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await onSubmit(
                personalNote.trimmingCharacters(in: .whitespacesAndNewlines),
                reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

#Preview {
    NavigationStack {
        TeamSearchView(viewModel: TeamListViewModel(store: AppStore()))
    }
}
