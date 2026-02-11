//
//  TeamDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: TeamDetailViewModel 提供的队伍与成员信息。
//  OUTPUT: 队伍详情页（管理视角）。
//  POS: 队伍列表的二级页面。
//

import SwiftUI

struct TeamDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: TeamDetailViewModel
    private let store: AppStore
    @State private var toast: AppToastPayload?
    @State private var transferCandidate: TeamMember?

    init(store: AppStore, teamId: UUID) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamDetailViewModel(store: store, teamId: teamId))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                AppDetailTopBar(
                    title: viewModel.team.name,
                    onBack: { dismiss() },
                    trailingSystemName: viewModel.isCurrentUserAdmin ? "square.and.pencil" : nil,
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
        ) { profile in
            viewModel.updateTeam(
                name: profile.name,
                slogan: profile.slogan,
                avatarImageData: profile.avatarImageData
            )
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
                            roleColor: roleColor(member.role),
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
}

private struct TeamMemberRow: View {
    let member: TeamMember
    let isCurrentUserAdmin: Bool
    let isCurrentUserSelf: Bool
    let canRemove: Bool
    let canToggleAdmin: Bool
    let canTransferOwner: Bool
    let roleColor: Color
    let onRemove: () -> Void
    let onToggleAdmin: () -> Void
    let onTransferOwner: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            Circle()
                .fill(AppColor.surface)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.user.nickname.prefix(1))
                        .font(AppFont.body())
                        .foregroundColor(AppColor.textSecondary)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(member.user.nickname)
                    .font(AppFont.body())
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: AppSpacing.s) {
                    AppTag(text: member.role.title, color: roleColor)
                    if isCurrentUserSelf {
                        AppTag(text: "我", color: AppColor.textSecondary)
                    }
                }
            }

            Spacer()

            if isCurrentUserAdmin && !isCurrentUserSelf {
                Menu {
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
                        .foregroundColor(AppColor.textMuted)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .padding(.vertical, AppSpacing.m)
    }
}

#Preview {
    NavigationStack {
        TeamDetailView(store: AppStore(), teamId: MockData.shared.myTeams[0].id)
    }
}
