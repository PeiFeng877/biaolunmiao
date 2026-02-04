//
//  TeamDetailView.swift
//  BianLunMiao
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

    init(store: AppStore, teamId: UUID) {
        _viewModel = StateObject(wrappedValue: TeamDetailViewModel(store: store, teamId: teamId))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        HStack(spacing: AppSpacing.m) {
                            ZStack {
                                Circle()
                                    .fill(AppColor.primary.opacity(0.12))
                                    .frame(width: 60, height: 60)
                                Text(viewModel.team.name.prefix(1))
                                    .font(AppFont.section())
                                    .foregroundColor(AppColor.primary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.team.name)
                                    .font(AppFont.section())
                                    .foregroundColor(AppColor.textPrimary)
                                Text("ID: \(viewModel.team.publicId)")
                                    .font(AppFont.caption())
                                    .foregroundColor(AppColor.textMuted)
                                    .monospacedDigit()
                            }

                            Spacer()
                        }

                        if let intro = viewModel.team.intro, !intro.isEmpty {
                            Text(intro)
                                .font(AppFont.body())
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }
                    .padding(AppSpacing.l)
                    .background(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                            .stroke(AppColor.outline, lineWidth: 1)
                    )
                    .cornerRadius(AppRadius.l)

                    if viewModel.isCurrentUserAdmin {
                        Button("邀请成员") {
                            print("Invite Tapped")
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }

                    AppSectionHeader("成员", trailing: "共 \(viewModel.team.members.count) 人")

                    VStack(spacing: 0) {
                        ForEach(viewModel.sortedMembers) { member in
                            HStack(spacing: AppSpacing.m) {
                                Circle()
                                    .fill(AppColor.surface)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(member.user.nickname.prefix(1))
                                            .font(AppFont.body())
                                            .foregroundColor(AppColor.textSecondary)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.user.nickname)
                                        .font(AppFont.body())
                                        .foregroundColor(AppColor.textPrimary)

                                    if member.userId == viewModel.currentUserId {
                                        AppTag(text: "我", color: AppColor.textSecondary)
                                    }
                                }

                                Spacer()

                                if member.role != .member {
                                    AppTag(text: member.role.title, color: roleColor(member.role))
                                }

                                if viewModel.isCurrentUserAdmin && member.userId != viewModel.currentUserId {
                                    Menu {
                                        Button(role: .destructive) {
                                            viewModel.removeMember(member)
                                        } label: {
                                            Label("移除成员", systemImage: "trash")
                                        }

                                        if viewModel.isCurrentUserOwner {
                                            Button {
                                                viewModel.toggleAdmin(member)
                                            } label: {
                                                Label(member.role == .admin ? "降为队员" : "设为管理", systemImage: "shield")
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

                            if member.id != viewModel.sortedMembers.last?.id {
                                Divider().overlay(AppColor.outline)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .background(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                            .stroke(AppColor.outline, lineWidth: 1)
                    )
                    .cornerRadius(AppRadius.l)

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
        .toolbar {
            if viewModel.isCurrentUserAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        viewModel.showEditSheet = true
                    }
                    .foregroundColor(AppColor.primary)
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            CreateTeamSheet(team: viewModel.team) { newName, newIntro in
                viewModel.updateTeam(name: newName, intro: newIntro)
            }
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

#Preview {
    NavigationStack {
        TeamDetailView(store: AppStore(), teamId: MockData.shared.myTeams[0].id)
    }
}
