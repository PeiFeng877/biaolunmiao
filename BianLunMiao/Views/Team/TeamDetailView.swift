//
//  TeamDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: TeamDetailViewModel 提供的队伍与成员信息。
//  OUTPUT: 队伍详情页（管理视角）。
//  POS: 队伍列表的二级页面。
//

import SwiftUI

struct TeamDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: TeamDetailViewModel
    private let store: AppStore
    @State private var showInviteAlert = false
    @State private var transferCandidate: TeamMember?

    init(store: AppStore, teamId: UUID) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamDetailViewModel(store: store, teamId: teamId))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    headerCard

                    if viewModel.isCurrentUserAdmin {
                        inviteButton
                    }

                    AppSectionHeader("成员", trailing: "共 \(viewModel.team.members.count) 人")

                    memberList

                    Button(viewModel.isCurrentUserOwner ? "解散队伍" : "退出队伍", role: .destructive) {
                        dismiss()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationTitle(viewModel.team.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("邀请功能即将上线", isPresented: $showInviteAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("我们会在后续版本加入邀请成员的完整流程。")
        }
        .confirmationDialog(
            "确认移交队长？",
            isPresented: Binding(
                get: { transferCandidate != nil },
                set: { if !$0 { transferCandidate = nil } }
            ),
            presenting: transferCandidate
        ) { candidate in
            Button("移交给 \(candidate.user.nickname)", role: .destructive) {
                viewModel.transferOwner(to: candidate)
                transferCandidate = nil
            }
        } message: { _ in
            Text("移交后你将成为管理员。")
        }
        .toolbar {
            if viewModel.isCurrentUserAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        viewModel.showEditSheet = true
                    }
                    .buttonStyle(AppToolbarTextButtonStyle())
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            CreateTeamSheet(team: viewModel.team) { profile in
                viewModel.updateTeam(
                    name: profile.name,
                    slogan: profile.slogan,
                    about: profile.about,
                    avatarImageData: profile.avatarImageData
                )
            }
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

                if let about = viewModel.team.about, !about.isEmpty {
                    Text(about)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textMuted)
                }
            }
        }
    }

    private var inviteButton: some View {
        Button("邀请成员") {
            showInviteAlert = true
        }
        .buttonStyle(AppSecondaryButtonStyle())
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
                    .buttonStyle(.plain)

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
                        Button(role: .destructive, action: onRemove) {
                            Label("移除成员", systemImage: "trash")
                        }
                    }

                    if canToggleAdmin {
                        Button(action: onToggleAdmin) {
                            Label(member.role == .admin ? "降为队员" : "设为管理", systemImage: "shield")
                        }
                    }

                    if canTransferOwner {
                        Button(role: .destructive, action: onTransferOwner) {
                            Label("移交队长", systemImage: "crown")
                        }
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
