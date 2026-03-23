//
//  TeamDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/23.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: TeamDetailViewModel 提供的队伍与成员信息。
//  OUTPUT: 队伍详情页（管理视角）。
//  POS: 队伍列表的二级页面。
//

import SwiftUI

struct TeamDetailView: View {
    private struct TeamNicknameEditorContext: Identifiable, Equatable {
        let memberId: UUID
        let initialNickname: String
        let title: String

        var id: UUID { memberId }
    }

    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: TeamDetailViewModel
    private let store: AppStore
    @State private var toast: AppToastPayload?
    @State private var transferCandidate: TeamMember?
    @State private var nicknameEditorContext: TeamNicknameEditorContext?

    init(store: AppStore, teamId: UUID) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamDetailViewModel(store: store, teamId: teamId))
    }

    var body: some View {
        ZStack {
            AppBackground()
            accessibilityMarker("team_detail_root")

            VStack(spacing: 0) {
                AppDetailTopBar(
                    title: viewModel.team.name,
                    onBack: { dismiss() },
                    backAccessibilityId: "team_detail_back_button",
                    trailingSystemName: viewModel.isCurrentUserAdmin ? "square.and.pencil" : nil,
                    trailingAccessibilityId: viewModel.isCurrentUserAdmin ? "team_detail_edit_button" : nil,
                    onTrailingAction: viewModel.isCurrentUserAdmin ? { viewModel.showEditSheet = true } : nil
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        headerCard

                        AppSectionHeader("成员", trailing: "共 \(viewModel.team.members.count) 人")

                        memberList

                        if viewModel.isCurrentUserAdmin {
                            inviteButton
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .appToast(item: $toast)
        .appConfirmationDialog(
            "确认移交队长？",
            isPresented: transferDialogPresented,
            presenting: transferCandidate
        ) { candidate in
            AppMenuAction("移交给 \(candidate.user.nickname)", role: .destructive) {
                viewModel.transferOwner(to: candidate)
                transferCandidate = nil
            }
        } message: { _ in
            Text("移交后你将成为管理员。")
        }
        .appSheet(isPresented: $viewModel.showEditSheet) {
            editSheet
        }
        .appSheet(item: $nicknameEditorContext) { context in
            TeamMemberNicknameSheet(
                title: context.title,
                initialNickname: context.initialNickname
            ) { nickname in
                try await viewModel.updateTeamNickname(
                    memberId: context.memberId,
                    teamNickname: nickname
                )
                nicknameEditorContext = nil
                toast = AppToastPayload(title: "称呼已更新", intent: .success)
            }
        }
    }

    private var transferDialogPresented: Binding<Bool> {
        Binding(
            get: { transferCandidate != nil },
            set: { if !$0 { transferCandidate = nil } }
        )
    }

    private var editSheet: some View {
        CreateTeamSheet(
            team: viewModel.team,
            dangerActionTitle: viewModel.dangerActionTitle,
            onDangerAction: {
                viewModel.performDangerAction()
                dismiss()
            }
        ) { @MainActor profile in
            try await viewModel.updateTeam(payload: profile.updatePayload(id: viewModel.team.id))
        }
    }

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(spacing: AppSpacing.m) {
                    TeamAvatarView(team: viewModel.team, size: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.team.name)
                            .font(AppFont.section())
                            .foregroundStyle(AppColor.textPrimary)
                        Text("ID: \(viewModel.team.publicId)")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textMuted)
                            .monospacedDigit()
                    }

                    Spacer()
                }

                if let slogan = viewModel.team.slogan, !slogan.isEmpty {
                    Text(slogan)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }

    private var inviteButton: some View {
        AppButton("邀请成员", variant: .secondary) {
            toast = AppToastPayload(
                title: "邀请功能即将上线",
                message: "后续版本会补齐完整流程",
                intent: .info
            )
        }
    }

    private var memberList: some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(viewModel.sortedMembers) { member in
                    NavigationLink {
                        MemberDetailView(store: store, user: member.user)
                    } label: {
                        TeamMemberRow(
                            member: member,
                            isCurrentUserAdmin: viewModel.isCurrentUserAdmin,
                            isCurrentUserSelf: member.userId == viewModel.currentUserId,
                            canRemove: viewModel.canRemove(member),
                            canToggleAdmin: viewModel.canToggleAdmin(member),
                            canTransferOwner: viewModel.canTransferOwner(member),
                            canEditTeamNickname: viewModel.canEditTeamNickname(member),
                            roleColor: roleColor(member.role),
                            onEditTeamNickname: { presentNicknameEditor(for: member) },
                            onRemove: { viewModel.removeMember(member) },
                            onToggleAdmin: { viewModel.toggleAdmin(member) },
                            onTransferOwner: { transferCandidate = member }
                        )
                    }
                    .buttonStyle(AppRowTapButtonStyle())

                    if member.id != viewModel.sortedMembers.last?.id {
                        Divider().overlay(AppColor.outline)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
        }
    }

    private func roleColor(_ role: TeamRole) -> Color {
        switch role {
        case .owner:
            return AppColor.reward
        case .admin:
            return AppColor.primary
        case .member:
            return AppColor.textSecondary
        }
    }

    private func presentNicknameEditor(for member: TeamMember) {
        nicknameEditorContext = TeamNicknameEditorContext(
            memberId: member.id,
            initialNickname: member.displayName,
            title: "修改称呼"
        )
    }

    private func accessibilityMarker(_ id: String) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(id)
    }
}

private struct TeamMemberRow: View {
    let member: TeamMember
    let isCurrentUserAdmin: Bool
    let isCurrentUserSelf: Bool
    let canRemove: Bool
    let canToggleAdmin: Bool
    let canTransferOwner: Bool
    let canEditTeamNickname: Bool
    let roleColor: Color
    let onEditTeamNickname: () -> Void
    let onRemove: () -> Void
    let onToggleAdmin: () -> Void
    let onTransferOwner: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            Circle()
                .fill(AppColor.surface)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.displayName.prefix(1))
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(member.displayName)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textPrimary)

                HStack(spacing: AppSpacing.s) {
                    AppTag(text: member.role.title, color: roleColor)
                    if isCurrentUserSelf {
                        AppTag(text: "我", color: AppColor.textSecondary)
                    }
                }
            }

            Spacer()

            if isCurrentUserSelf {
                AppIconButton(
                    systemName: "square.and.pencil",
                    accessibilityTitle: "修改称呼",
                    foreground: AppColor.textMuted,
                    background: AppColor.surface,
                    stroke: AppColor.outline,
                    action: onEditTeamNickname
                )
                .accessibilityIdentifier("team_member_self_edit_button")
            } else if isCurrentUserAdmin {
                Menu {
                    if canEditTeamNickname {
                        AppMenuAction(
                            "修改称呼",
                            systemImage: "square.and.pencil",
                            action: onEditTeamNickname
                        )
                    }

                    if canRemove {
                        AppMenuAction("移除成员", systemImage: "trash", role: .destructive, action: onRemove)
                    }

                    if canToggleAdmin {
                        AppMenuAction(
                            member.role == .admin ? "降为队员" : "设为管理",
                            systemImage: "shield",
                            action: onToggleAdmin
                        )
                    }

                    if canTransferOwner {
                        AppMenuAction("移交队长", systemImage: "crown", role: .destructive, action: onTransferOwner)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppColor.textMuted)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .padding(.vertical, AppSpacing.m)
    }
}

private struct TeamMemberNicknameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: @MainActor @Sendable (String) async throws -> Void

    @State private var teamNickname: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canSave: Bool {
        !teamNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    init(
        title: String,
        initialNickname: String,
        onSave: @escaping @MainActor @Sendable (String) async throws -> Void
    ) {
        self.title = title
        self.onSave = onSave
        _teamNickname = State(initialValue: initialNickname)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSheetHeader(
                    title: title,
                    leadingAccessibilityId: "team_member_nickname_cancel_button",
                    trailingTitle: "保存",
                    trailingAccessibilityId: "team_member_nickname_save_button",
                    onLeadingAction: { dismiss() },
                    onTrailingAction: {
                        guard canSave else { return }
                        Task {
                            await submit()
                        }
                    }
                )
                .opacity(canSave ? 1 : 0.56)

                ZStack {
                    AppBackground()

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.l) {
                            AppFormField(title: "队内称呼", isRequired: true, error: errorMessage) {
                                AppTextField(placeholder: "输入当前队伍内使用的称呼", text: $teamNickname)
                                    .accessibilityIdentifier("team_member_nickname_input")
                            }
                        }
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.top, AppSpacing.l)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .dismissKeyboardOnTap()
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func submit() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await onSave(teamNickname.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    let mock = MockData()
    NavigationStack {
        TeamDetailView(store: AppStore(mock: mock), teamId: mock.myTeams[0].id)
    }
}
