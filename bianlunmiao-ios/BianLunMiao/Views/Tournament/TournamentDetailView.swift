//
//  TournamentDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: TournamentDetailViewModel 提供的赛事详情状态。
//  OUTPUT: 赛事管理页。
//  POS: 赛事详情展示层。
//

import SwiftUI

struct TournamentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TournamentDetailViewModel

    @State private var tournamentEditorContext: TournamentEditorContext?
    @State private var matchRoute: MatchDetailRoute?
    @State private var toast: AppToastPayload?

    init(store: AppStore, tournamentId: UUID) {
        _viewModel = StateObject(wrappedValue: TournamentDetailViewModel(store: store, tournamentId: tournamentId))
    }

    var body: some View {
        ZStack {
            AppBackground()
            accessibilityMarker("tournament_detail_root")

            VStack(spacing: AppSpacing.m) {
                AppDetailTopBar(
                    title: "赛事详情",
                    onBack: { dismiss() },
                    trailingSystemName: viewModel.canManage ? "square.and.pencil" : nil,
                    trailingAccessibilityId: viewModel.canManage ? "tournament_detail_edit_button" : nil,
                    onTrailingAction: viewModel.canManage ? {
                        tournamentEditorContext = TournamentEditorContext(tournament: viewModel.tournament)
                    } : nil
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        TournamentDetailHeaderCard(
                            title: viewModel.tournament.name,
                            intro: viewModel.introText,
                            statusText: viewModel.statusText,
                            statusToken: viewModel.statusColor,
                            participantCount: viewModel.participantTeams.count,
                            matchCount: viewModel.matches.count
                        )

                        matchSection
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }

            if viewModel.canManageSchedule {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addMatchFloatingButton
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .appSheet(item: $tournamentEditorContext) { context in
            TournamentInfoEditorSheet(
                initialName: context.name,
                initialIntro: context.intro,
                initialStatus: context.status
            ) { name, intro, status in
                _ = try await viewModel.updateTournamentInfo(name: name, intro: intro, status: status)
                toast = AppToastPayload(title: "赛事信息已更新", intent: .success)
            }
        }
        .navigationDestination(item: $matchRoute) { route in
            MatchDetailPage(
                viewModel: viewModel,
                route: route
            ) { didSave in
                if didSave {
                    toast = AppToastPayload(title: "场次已保存", intent: .success)
                }
            }
        }
        .appToast(item: $toast)
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader("场次", trailing: "共 \(viewModel.matches.count) 场")

            if viewModel.matches.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        AppEmptyState(
                            title: "暂无场次",
                            subtitle: viewModel.canManageSchedule ? "点击右下角 + 或下方按钮新建第一场场次" : "等待赛事管理员创建场次",
                            systemImage: "flag.checkered"
                        )

                        if viewModel.canManageSchedule {
                            AppButton("新建场次", variant: .secondary) {
                                matchRoute = MatchDetailRoute(mode: .create)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: AppSpacing.m) {
                    ForEach(viewModel.matches) { match in
                        AppRowTapButton {
                            matchRoute = MatchDetailRoute(
                                mode: viewModel.canManageSchedule ? .edit(match.id) : .view(match.id)
                            )
                        } label: {
                            TournamentMatchItemCard(
                                match: match,
                                teamAName: viewModel.teamAName(for: match),
                                teamBName: viewModel.teamBName(for: match),
                                scoreText: viewModel.scoreText(for: match)
                            )
                        }
                    }
                }
            }
        }
    }

    private var addMatchFloatingButton: some View {
        AppRowTapButton {
            matchRoute = MatchDetailRoute(mode: .create)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: 54, height: 54)
                .background(AppColor.primaryStrong)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.stroke, lineWidth: 2))
                .shadow(
                    color: AppShadow.standard.color,
                    radius: 0,
                    x: AppShadow.standard.x,
                    y: AppShadow.standard.y
                )
        }
        .accessibilityIdentifier("tournament_add_match_fab")
    }

    private func accessibilityMarker(_ id: String) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(id)
    }
}

private struct MatchDetailRoute: Identifiable, Hashable {
    enum Mode: Hashable {
        case create
        case edit(UUID)
        case view(UUID)
    }

    let id = UUID()
    let mode: Mode
}

private struct TournamentEditorContext: Identifiable {
    let id = UUID()
    let name: String
    let intro: String
    let status: TournamentStatus

    init(tournament: Tournament) {
        self.name = tournament.name
        self.intro = tournament.intro ?? ""
        self.status = tournament.status
    }
}

private struct MatchDetailPage: View {
    enum Tab: String, CaseIterable {
        case info = "场次信息"
        case result = "场次结果"
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TournamentDetailViewModel

    let route: MatchDetailRoute
    let onComplete: (Bool) -> Void

    @State private var selectedTab: Tab = .info
    @State private var form: TournamentDetailViewModel.MatchForm
    @State private var baselineForm: TournamentDetailViewModel.MatchForm
    @State private var memberSearchText: [String: String]
    @State private var showDiscardAlert = false
    @State private var showSaveError = false
    @State private var showBestDebaterDropdown = false
    @FocusState private var focusedLineupPosition: String?

    init(
        viewModel: TournamentDetailViewModel,
        route: MatchDetailRoute,
        onComplete: @escaping (Bool) -> Void
    ) {
        self.viewModel = viewModel
        self.route = route
        self.onComplete = onComplete

        let initialForm: TournamentDetailViewModel.MatchForm = {
            switch route.mode {
            case .create:
                return viewModel.createMatchForm()
            case .edit(let matchId), .view(let matchId):
                guard let match = viewModel.matches.first(where: { $0.id == matchId }) else {
                    return viewModel.createMatchForm()
                }
                return viewModel.editMatchForm(for: match)
            }
        }()

        _form = State(initialValue: initialForm)
        _baselineForm = State(initialValue: initialForm)
        _memberSearchText = State(
            initialValue: Dictionary(uniqueKeysWithValues: initialForm.lineup.map { slot in
                let selectedName = viewModel.managedTeamMembers
                    .first(where: { $0.userId == slot.userId })?
                    .user
                    .nickname ?? ""
                return (slot.position, selectedName)
            })
        )
    }

    var body: some View {
        ZStack {
            AppBackground()
            accessibilityMarker("match_detail_root")

            VStack(spacing: AppSpacing.m) {
                matchEditorTopBar

                Picker("场次子页签", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.inset)
                .padding(.top, AppSpacing.s)

                ScrollView {
                    switch selectedTab {
                    case .info:
                        infoTab
                    case .result:
                        resultTab
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .appAlert("信息将丢失", isPresented: $showDiscardAlert) {
            AppMenuAction("继续返回", role: .destructive) {
                dismiss()
            }
            AppMenuAction("继续编辑", role: .cancel) {}
        } message: {
            Text("当前场次内容尚未保存，返回后修改将丢失。")
        }
        .appAlert("保存失败", isPresented: $showSaveError) {
            AppMenuAction("我知道了", role: .cancel) {}
        } message: {
            Text("请检查场次信息、上场队员和结果配置是否完整。")
        }
        .onChange(of: form.format) { _, _ in
            viewModel.syncLineupSlots(&form)
            let options = Set(viewModel.bestDebaterOptions(for: form.format))
            if let selected = form.bestDebaterPosition, !options.contains(selected) {
                form.bestDebaterPosition = nil
            }
            for slot in form.lineup where memberSearchText[slot.position] == nil {
                let selectedName = viewModel.managedTeamMembers
                    .first(where: { $0.userId == slot.userId })?
                    .user
                    .nickname ?? ""
                memberSearchText[slot.position] = selectedName
            }
        }
        .onChange(of: form.winnerResult) { _, newValue in
            if newValue == .none {
                form.resultNote = ""
                form.bestDebaterPosition = nil
                showBestDebaterDropdown = false
            }
        }
        .onChange(of: selectedTab) { _, _ in
            showBestDebaterDropdown = false
            focusedLineupPosition = nil
        }
    }

    private var matchEditorTopBar: some View {
        ZStack {
            Text(pageTitle)
                .font(AppFont.section())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)

            HStack(spacing: AppSpacing.m) {
                AppTopBarButton(
                    systemName: "arrow.left",
                    foreground: AppColor.textPrimary,
                    background: AppColor.primarySoft,
                    stroke: AppColor.stroke,
                    accessibilityId: "match_editor_back_button",
                    action: handleBack
                )

                Spacer(minLength: AppSpacing.s)

                if canEdit {
                    AppTopBarButton(
                        systemName: "checkmark",
                        foreground: AppColor.primaryStrong,
                        background: AppColor.primarySoft,
                        stroke: AppColor.stroke,
                        accessibilityTitle: "保存",
                        accessibilityId: "match_editor_save_button",
                        action: handleSave
                    )
                } else {
                    Color.clear
                        .frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.top, AppSpacing.s)
    }

    private var canEdit: Bool {
        switch route.mode {
        case .view:
            return false
        case .create, .edit:
            return viewModel.canManageSchedule
        }
    }

    private var editingMatchId: UUID? {
        switch route.mode {
        case .create:
            return nil
        case .edit(let id), .view(let id):
            return id
        }
    }

    private var pageTitle: String {
        switch route.mode {
        case .create:
            return "新建场次"
        case .edit:
            return "编辑场次"
        case .view:
            return "场次详情"
        }
    }

    private var infoTab: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            AppFormField(title: "场次名称") {
                AppTextField(placeholder: "例如：初赛第一场", text: $form.name)
                    .accessibilityIdentifier("match_editor_name_input")
                    .disabled(!canEdit)
                    .opacity(canEdit ? 1 : 0.65)
            }

            AppFormField(title: "辩题") {
                AppTextField(placeholder: "例如：效率与公平何者更重要", text: $form.topic)
                    .accessibilityIdentifier("match_editor_topic_input")
                    .disabled(!canEdit)
                    .opacity(canEdit ? 1 : 0.65)
            }

            AppFormField(title: "开始时间") {
                DatePicker("", selection: $form.startTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .disabled(!canEdit)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }

            AppFormField(title: "赛制") {
                Picker("赛制", selection: $form.format) {
                    ForEach(MatchFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canEdit)
            }

            AppFormField(title: "比赛地点") {
                AppTextField(placeholder: "线下教室或线上会议链接", text: $form.location)
                    .accessibilityIdentifier("match_editor_location_input")
                    .disabled(!canEdit)
                    .opacity(canEdit ? 1 : 0.65)
            }

            AppFormField(title: "我方持方") {
                Picker("我方持方", selection: $form.mySide) {
                    ForEach(TournamentDetailViewModel.TeamSide.allCases, id: \.self) { side in
                        Text(side.rawValue).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canEdit)
            }

            lineupField

            AppFormField(title: "对方队伍名称") {
                AppTextField(placeholder: "输入对手队伍名称", text: $form.opponentTeamName)
                    .accessibilityIdentifier("match_editor_opponent_input")
                    .disabled(!canEdit)
                    .opacity(canEdit ? 1 : 0.65)
            }
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.bottom, AppSpacing.xxl)
    }

    private var resultTab: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            AppFormField(title: "胜负结果") {
                Picker("胜负结果", selection: $form.winnerResult) {
                    ForEach(TournamentDetailViewModel.WinnerResult.allCases, id: \.self) { result in
                        Text(result.rawValue).tag(result)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canEdit)
            }

            if form.winnerResult != .none {
                AppFormField(title: "结果备注") {
                    AppTextEditor(placeholder: "补充说明本场次结果", text: $form.resultNote)
                        .disabled(!canEdit)
                        .opacity(canEdit ? 1 : 0.65)
                }

                AppFormField(title: "最佳辩手") {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        AppRowTapButton {
                            guard canEdit else { return }
                            showBestDebaterDropdown.toggle()
                        } label: {
                            HStack(spacing: AppSpacing.s) {
                                Text(form.bestDebaterPosition ?? "未选择")
                                    .font(AppFont.body())
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                Image(systemName: showBestDebaterDropdown ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(AppColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                                    .stroke(AppColor.stroke, lineWidth: 2)
                            )
                            .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
                        }
                        .disabled(!canEdit)

                        if showBestDebaterDropdown {
                            bestDebaterDropdown
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.bottom, AppSpacing.xxl)
    }

    private var lineupField: some View {
        AppFormField(title: "上场队员") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                ForEach(form.lineup) { slot in
                    lineupRow(slot: slot)
                }
            }
        }
    }

    private func lineupRow(slot: TournamentDetailViewModel.LineupSlot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .center, spacing: AppSpacing.s) {
                Text(slot.position)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 46, alignment: .leading)

                HStack(spacing: AppSpacing.s) {
                    TextField(
                        "",
                        text: searchBinding(position: slot.position),
                        prompt: Text("搜索队员昵称")
                            .font(AppFont.body())
                            .tracking(AppFont.tracking)
                            .foregroundStyle(AppColor.textSecondary)
                    )
                    .font(AppFont.body())
                    .tracking(AppFont.tracking)
                    .foregroundStyle(AppColor.textPrimary)
                    .tint(AppColor.primaryStrong)
                    .disabled(!canEdit)
                    .focused($focusedLineupPosition, equals: slot.position)

                    if canEdit && (slot.userId != nil || !(memberSearchText[slot.position] ?? "").isEmpty) {
                        AppRowTapButton {
                            setLineupMember(position: slot.position, userId: nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .background(focusedLineupPosition == slot.position ? AppColor.primarySoft : AppColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                        .stroke(AppColor.stroke, lineWidth: 2)
                )
                .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
                .shadow(
                    color: focusedLineupPosition == slot.position ? AppShadow.accent.color : AppShadow.standard.color,
                    radius: 0,
                    x: focusedLineupPosition == slot.position ? AppShadow.accent.x : AppShadow.standard.x,
                    y: focusedLineupPosition == slot.position ? AppShadow.accent.y : AppShadow.standard.y
                )
            }

            if canEdit {
                let suggestions = Array(filteredMembers(for: slot.position).prefix(4))
                if !suggestions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(suggestions, id: \.id) { member in
                                AppRowTapButton {
                                    setLineupMember(position: slot.position, userId: member.userId)
                                } label: {
                                    Text(member.user.nickname)
                                        .font(AppFont.caption())
                                        .foregroundStyle(AppColor.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 128)
                    .background(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                            .stroke(AppColor.stroke, lineWidth: 1.2)
                    )
                    .clipShape(.rect(cornerRadius: AppRadius.s, style: .continuous))
                    .padding(.leading, 54)
                }
            }
        }
    }

    private func searchBinding(position: String) -> Binding<String> {
        Binding(
            get: { memberSearchText[position] ?? "" },
            set: { newValue in
                memberSearchText[position] = newValue
                guard let targetIndex = form.lineup.firstIndex(where: { $0.position == position }) else { return }
                guard let selectedUserId = form.lineup[targetIndex].userId else { return }
                let selectedName = viewModel.managedTeamMembers
                    .first(where: { $0.userId == selectedUserId })?
                    .user
                    .nickname ?? ""
                if newValue != selectedName {
                    form.lineup[targetIndex].userId = nil
                }
            }
        )
    }

    private func filteredMembers(for position: String) -> [TeamMember] {
        let keyword = (memberSearchText[position] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }

        if let selectedName = selectedMemberName(for: position), selectedName == keyword {
            return []
        }

        let selectedInOthers = Set(
            form.lineup
                .filter { $0.position != position }
                .compactMap(\.userId)
        )

        return viewModel.managedTeamMembers.filter { member in
            guard !selectedInOthers.contains(member.userId) else { return false }
            return member.user.nickname.localizedStandardContains(keyword)
        }
    }

    private func setLineupMember(position: String, userId: UUID?) {
        if let userId {
            for index in form.lineup.indices where form.lineup[index].position != position && form.lineup[index].userId == userId {
                memberSearchText[form.lineup[index].position] = ""
                form.lineup[index].userId = nil
            }
        }

        guard let targetIndex = form.lineup.firstIndex(where: { $0.position == position }) else { return }
        form.lineup[targetIndex].userId = userId
        let selectedName = viewModel.managedTeamMembers
            .first(where: { $0.userId == userId })?
            .user
            .nickname ?? ""
        memberSearchText[position] = selectedName
    }

    private func selectedMemberName(for position: String) -> String? {
        guard let slot = form.lineup.first(where: { $0.position == position }) else { return nil }
        guard let userId = slot.userId else { return nil }
        return viewModel.managedTeamMembers
            .first(where: { $0.userId == userId })?
            .user
            .nickname
    }

    private var bestDebaterDropdown: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                bestDebaterOptionRow(label: "未选择", value: nil)
                ForEach(viewModel.bestDebaterOptions(for: form.format), id: \.self) { option in
                    bestDebaterOptionRow(label: option, value: option)
                }
            }
        }
        .frame(maxHeight: 220)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .stroke(AppColor.stroke, lineWidth: 1.2)
        )
        .clipShape(.rect(cornerRadius: AppRadius.s, style: .continuous))
    }

    private func bestDebaterOptionRow(label: String, value: String?) -> some View {
        AppRowTapButton {
            form.bestDebaterPosition = value
            showBestDebaterDropdown = false
        } label: {
            HStack(spacing: AppSpacing.s) {
                Text(label)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                if form.bestDebaterPosition == value {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColor.primaryStrong)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func handleBack() {
        guard canEdit, form != baselineForm else {
            dismiss()
            return
        }
        showDiscardAlert = true
    }

    private func handleSave() {
        guard canEdit else { return }
        let success = viewModel.saveMatch(form: form, editingMatchId: editingMatchId)
        if success {
            baselineForm = form
            onComplete(true)
            dismiss()
        } else {
            showSaveError = true
        }
    }

    private func accessibilityMarker(_ id: String) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(id)
    }
}

private struct TournamentInfoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: @MainActor @Sendable (String, String, TournamentStatus) async throws -> Void

    @State private var name: String
    @State private var intro: String
    @State private var status: TournamentStatus
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    init(
        initialName: String,
        initialIntro: String,
        initialStatus: TournamentStatus,
        onSave: @escaping @MainActor @Sendable (String, String, TournamentStatus) async throws -> Void
    ) {
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _intro = State(initialValue: initialIntro)
        _status = State(initialValue: initialStatus)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(title: "赛事名称", error: errorMessage) {
                            AppTextField(placeholder: "输入赛事名称", text: $name)
                                .accessibilityIdentifier("tournament_edit_name_input")
                        }

                        AppFormField(title: "赛事简介") {
                            AppTextEditor(placeholder: "填写赛事简介", text: $intro)
                                .accessibilityIdentifier("tournament_edit_intro_input")
                        }

                        AppFormField(title: "赛事状态") {
                            Picker("赛事状态", selection: $status) {
                                ForEach(TournamentStatus.allCases, id: \.self) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("tournament_edit_status_picker")
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) {
                                dismiss()
                            }

                            AppButton("保存", variant: .primary) {
                                Task { @MainActor in
                                    await submit()
                                }
                            }
                            .disabled(isSubmitting)
                            .opacity(isSubmitting ? 0.56 : 1)
                            .accessibilityIdentifier("tournament_edit_save_button")
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("编辑赛事")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedIntro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSave(trimmedName, trimmedIntro, status)
            isSubmitting = false
            dismiss()
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

#Preview {
    let mock = MockData()
    NavigationStack {
        TournamentDetailView(
            store: AppStore(mock: mock),
            tournamentId: mock.tournaments.first?.id ?? UUID()
        )
    }
}
