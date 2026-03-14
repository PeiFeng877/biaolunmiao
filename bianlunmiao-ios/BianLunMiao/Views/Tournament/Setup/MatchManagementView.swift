//
//  MatchManagementView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: MatchManagementViewModel 提供的赛程、参赛队伍与权限状态。
//  OUTPUT: 赛程管理与阵容/赛果操作入口。
//  POS: 赛事管理页。
//

import SwiftUI

struct MatchManagementView: View {
    @StateObject private var viewModel: MatchManagementViewModel
    @State private var toast: AppToastPayload?
    @State private var matchEditorContext: MatchEditorContext?
    @State private var rosterContext: RosterContext?
    @State private var resultContext: ResultContext?

    init(store: AppStore, tournamentId: UUID) {
        _viewModel = StateObject(wrappedValue: MatchManagementViewModel(store: store, tournamentId: tournamentId))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    AppSectionHeader("赛程管理", trailing: "共 \(viewModel.matches.count) 场")

                    if viewModel.canManageTournament {
                        AppButton("新增场次", variant: .secondary) {
                            matchEditorContext = MatchEditorContext(
                                editingMatchId: nil,
                                title: "新增场次",
                                form: viewModel.createForm()
                            )
                        }
                        .accessibilityIdentifier("match_add_button")
                    }

                    if viewModel.matches.isEmpty {
                        AppCard {
                            AppEmptyState(
                                title: "暂无赛程",
                                subtitle: viewModel.canManageTournament ? "点击“新增场次”开始创建" : "等待管理员创建赛程",
                                systemImage: "flag"
                            )
                        }
                    } else {
                        VStack(spacing: AppSpacing.m) {
                            ForEach(viewModel.matches) { match in
                                matchCard(match)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.inset)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationTitle("赛程管理")
        .navigationBarTitleDisplayMode(.inline)
        .appSheet(item: $matchEditorContext) { context in
            MatchEditorSheet(
                title: context.title,
                initialForm: context.form,
                teams: viewModel.assignableTeams
            ) { form in
                let success = viewModel.saveMatch(form: form, editingMatchId: context.editingMatchId)
                if success {
                    toast = AppToastPayload(title: "赛程已保存", intent: .success)
                } else {
                    toast = AppToastPayload(title: "保存失败", message: "请检查时间与队伍设置", intent: .error)
                }
                return success
            }
        }
        .appSheet(item: $rosterContext) { context in
            if let team = viewModel.teamEntity(teamId: context.teamId) {
                RosterEditView(
                    match: context.match,
                    team: team,
                    existingAssignments: viewModel.existingRosterAssignments(matchId: context.match.id, teamId: context.teamId)
                ) { assignments in
                    let success = viewModel.saveRoster(matchId: context.match.id, teamId: context.teamId, assignments: assignments)
                    toast = success
                        ? AppToastPayload(title: "阵容已保存", intent: .success)
                        : AppToastPayload(title: "保存失败", message: "请确认权限与阵容完整性", intent: .error)
                    return success
                }
            }
        }
        .appSheet(item: $resultContext) { context in
            MatchResultSheet(match: context.match, teamAName: viewModel.teamName(teamId: context.match.teamAId), teamBName: viewModel.teamName(teamId: context.match.teamBId)) { winnerTeamId, teamAScore, teamBScore in
                let success = viewModel.recordResult(
                    matchId: context.match.id,
                    winnerTeamId: winnerTeamId,
                    teamAScore: teamAScore,
                    teamBScore: teamBScore
                )
                toast = success
                    ? AppToastPayload(title: "赛果已录入", intent: .success)
                    : AppToastPayload(title: "录入失败", message: "请检查胜方与比分", intent: .error)
                return success
            }
        }
        .appToast(item: $toast)
    }

    private func matchCard(_ match: Match) -> some View {
        AppCard(style: .standard) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                    Text(match.name)
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    AppTag(text: statusTitle(match.status), color: statusColor(match.status))
                }

                Text(match.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)

                Text("\(viewModel.teamName(teamId: match.teamAId)) VS \(viewModel.teamName(teamId: match.teamBId))")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary)

                HStack(spacing: AppSpacing.s) {
                    let required = viewModel.requiredRosterCount(for: match)
                    Text("A队阵容 \(viewModel.rosterCount(matchId: match.id, teamId: match.teamAId))/\(required)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text("B队阵容 \(viewModel.rosterCount(matchId: match.id, teamId: match.teamBId))/\(required)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                }

                if match.status == .finished {
                    HStack(spacing: AppSpacing.s) {
                        Text("胜方：\(viewModel.teamName(teamId: match.winnerTeamId))")
                            .font(AppFont.caption())
                        Text("比分：\(matchScoreText(match))")
                            .font(AppFont.caption())
                    }
                    .foregroundStyle(AppColor.textSecondary)
                }

                if viewModel.canManageTournament {
                    Divider().overlay(AppColor.stroke)

                    VStack(spacing: AppSpacing.s) {
                        HStack(spacing: AppSpacing.s) {
                            AppButton("编辑赛程", variant: .toolbarText) {
                                matchEditorContext = MatchEditorContext(
                                    editingMatchId: match.id,
                                    title: "编辑场次",
                                    form: viewModel.editForm(for: match)
                                )
                            }

                            AppButton(statusActionTitle(match.status), variant: .toolbarText) {
                                handleStatusAction(match)
                            }
                            .disabled(match.status == .finished)
                            .opacity(match.status == .finished ? 0.5 : 1)

                            AppButton("录入赛果", variant: .toolbarText) {
                                guard match.status == .finished else {
                                    toast = AppToastPayload(
                                        title: "请先结束比赛",
                                        message: "仅“已结束”状态可录入赛果",
                                        intent: .warning
                                    )
                                    return
                                }
                                guard match.teamAId != nil, match.teamBId != nil else {
                                    toast = AppToastPayload(title: "请先指派参赛队伍", intent: .warning)
                                    return
                                }
                                resultContext = ResultContext(match: match)
                            }
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("A队阵容", variant: .toolbarText) {
                                openRoster(match: match, teamId: match.teamAId)
                            }

                            AppButton("B队阵容", variant: .toolbarText) {
                                openRoster(match: match, teamId: match.teamBId)
                            }
                        }
                    }
                }
            }
        }
    }

    private func openRoster(match: Match, teamId: UUID?) {
        guard let teamId else {
            toast = AppToastPayload(title: "请先在编辑中指派 A/B 队", intent: .warning)
            return
        }
        guard viewModel.canManageTeam(teamId: teamId) else {
            toast = AppToastPayload(title: "无权限指派该队阵容", intent: .warning)
            return
        }
        rosterContext = RosterContext(match: match, teamId: teamId)
    }

    private func handleStatusAction(_ match: Match) {
        let target: MatchStatus
        switch match.status {
        case .scheduled, .ready:
            target = .ongoing
        case .ongoing:
            target = .finished
        case .finished:
            return
        }

        let success = viewModel.advanceStatus(matchId: match.id, to: target)
        toast = success
            ? AppToastPayload(title: "状态已更新", intent: .success)
            : AppToastPayload(title: "状态更新失败", message: "当前状态不可切换", intent: .error)
    }

    private func statusTitle(_ status: MatchStatus) -> String {
        switch status {
        case .scheduled:
            return "待排阵"
        case .ready:
            return "名单就绪"
        case .ongoing:
            return "进行中"
        case .finished:
            return "已结束"
        }
    }

    private func statusColor(_ status: MatchStatus) -> Color {
        switch status {
        case .scheduled:
            return AppColor.textSecondary
        case .ready:
            return AppColor.primaryStrong
        case .ongoing:
            return AppColor.infoBlue
        case .finished:
            return AppColor.textSecondary
        }
    }

    private func statusActionTitle(_ status: MatchStatus) -> String {
        switch status {
        case .scheduled, .ready:
            return "开始比赛"
        case .ongoing:
            return "结束比赛"
        case .finished:
            return "已结束"
        }
    }

    private func matchScoreText(_ match: Match) -> String {
        guard let teamAScore = match.teamAScore, let teamBScore = match.teamBScore else { return "未录入" }
        return "\(teamAScore) : \(teamBScore)"
    }
}

private struct MatchEditorContext: Identifiable {
    let id = UUID()
    let editingMatchId: UUID?
    let title: String
    let form: MatchManagementViewModel.MatchForm
}

private struct RosterContext: Identifiable {
    let id = UUID()
    let match: Match
    let teamId: UUID
}

private struct ResultContext: Identifiable {
    let id = UUID()
    let match: Match
}

private struct MatchEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let teams: [Team]
    let onSave: (MatchManagementViewModel.MatchForm) -> Bool

    @State private var form: MatchManagementViewModel.MatchForm
    @State private var errorMessage: String?

    init(
        title: String,
        initialForm: MatchManagementViewModel.MatchForm,
        teams: [Team],
        onSave: @escaping (MatchManagementViewModel.MatchForm) -> Bool
    ) {
        self.title = title
        self.teams = teams
        self.onSave = onSave
        _form = State(initialValue: initialForm)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(title: "场次名称", error: errorMessage) {
                            AppTextField(placeholder: "例如：初赛第一场", text: $form.name)
                                .accessibilityIdentifier("match_editor_name_input")
                        }

                        AppFormField(title: "开始时间") {
                            DatePicker("", selection: $form.startTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                        }

                        AppFormField(title: "比赛时长") {
                            Text("固定 1 小时 30 分钟")
                                .font(AppFont.body())
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        AppFormField(title: "赛制") {
                            Picker("赛制", selection: $form.format) {
                                ForEach(MatchFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        AppFormField(title: "比赛地点") {
                            AppTextField(placeholder: "线下教室或线上会议链接", text: $form.location)
                                .accessibilityIdentifier("match_editor_location_input")
                        }

                        AppFormField(title: "A 队") {
                            Picker("A 队", selection: $form.teamAId) {
                                Text("未选择").tag(UUID?.none)
                                ForEach(teams) { team in
                                    Text(team.name).tag(Optional(team.id))
                                }
                            }
                        }

                        AppFormField(title: "B 队") {
                            Picker("B 队", selection: $form.teamBId) {
                                Text("未选择").tag(UUID?.none)
                                ForEach(teams) { team in
                                    Text(team.name).tag(Optional(team.id))
                                }
                            }
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) {
                                dismiss()
                            }

                            AppButton("保存", variant: .primary) {
                                if onSave(form) {
                                    dismiss()
                                } else {
                                    errorMessage = "请确认名称与队伍配置"
                                }
                            }
                            .accessibilityIdentifier("match_editor_save_button")
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MatchResultSheet: View {
    @Environment(\.dismiss) private var dismiss

    let match: Match
    let teamAName: String
    let teamBName: String
    let onSave: (UUID, Int, Int) -> Bool

    @State private var winnerTeamId: UUID?
    @State private var teamAScoreText: String = ""
    @State private var teamBScoreText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(title: "胜方", error: errorMessage) {
                            Picker("胜方", selection: $winnerTeamId) {
                                Text("请选择").tag(UUID?.none)
                                if let teamAId = match.teamAId {
                                    Text(teamAName).tag(Optional(teamAId))
                                }
                                if let teamBId = match.teamBId {
                                    Text(teamBName).tag(Optional(teamBId))
                                }
                            }
                        }

                        AppFormField(title: "A 队得分") {
                            AppTextField(placeholder: "整数", text: $teamAScoreText)
                                .accessibilityIdentifier("match_result_team_a_score")
                        }

                        AppFormField(title: "B 队得分") {
                            AppTextField(placeholder: "整数", text: $teamBScoreText)
                                .accessibilityIdentifier("match_result_team_b_score")
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) {
                                dismiss()
                            }

                            AppButton("保存赛果", variant: .primary) {
                                guard let winnerTeamId,
                                      let teamAScore = Int(teamAScoreText),
                                      let teamBScore = Int(teamBScoreText) else {
                                    errorMessage = "请填写完整的胜方与比分"
                                    return
                                }

                                if onSave(winnerTeamId, teamAScore, teamBScore) {
                                    dismiss()
                                } else {
                                    errorMessage = "赛果保存失败，请重试"
                                }
                            }
                            .accessibilityIdentifier("match_result_save_button")
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("录入赛果")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
