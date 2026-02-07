//
//  TeamListView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: TeamListViewModel 提供的队伍列表。
//  OUTPUT: 带创建/加入入口的队伍主页。
//  POS: 我的 Tab 根页面。
//

import SwiftUI

struct TeamListView: View {
    @StateObject private var viewModel: TeamListViewModel
    private let store: AppStore
    @State private var navigationPath: [UUID] = []
    @State private var showJoinSheet = false

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    AppTopBar(
                        title: "队伍",
                        style: .team,
                        showsLeadingIcon: false,
                        onAdd: { viewModel.showCreateSheet = true }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.l) {
                            if viewModel.teams.isEmpty {
                                TeamEmptyStateCard(
                                    onCreate: { viewModel.showCreateSheet = true },
                                    onJoin: { showJoinSheet = true }
                                )
                            } else {
                                VStack(spacing: AppSpacing.m) {
                                    ForEach(viewModel.teams) { team in
                                        NavigationLink(value: team.id) {
                                            TeamCard(team: team, isOwner: viewModel.isOwner(team: team))
                                        }
                                        .buttonStyle(TeamCardButtonStyle())
                                    }
                                }
                            }

                            Text("共 \(viewModel.teams.count) 支")
                                .font(AppFont.caption())
                                .tracking(AppFont.tracking)
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.horizontal, AppSpacing.inset)
                        .padding(.top, AppSpacing.l)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { teamId in
                TeamDetailView(store: store, teamId: teamId)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateTeamSheet { profile in
                    let team = viewModel.createTeam(
                        name: profile.name,
                        slogan: profile.slogan,
                        about: profile.about,
                        avatarStyle: profile.avatarStyle
                    )
                    navigationPath.append(team.id)
                }
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinTeamSheet { publicId in
                    let result = viewModel.joinTeam(publicId: publicId)
                    if case let .success(team) = result {
                        navigationPath.append(team.id)
                    }
                    return result
                }
            }
        }
    }
}

#Preview {
    TeamListView(store: AppStore())
}

private struct TeamEmptyStateCard: View {
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: AppSpacing.l) {
                AppEmptyState(
                    title: "还没有队伍",
                    subtitle: "创建或加入队伍，开始第一场辩论",
                    systemImage: "flag.checkered"
                )

                VStack(spacing: AppSpacing.s) {
                    Button("创建队伍", action: onCreate)
                        .buttonStyle(AppPrimaryButtonStyle())

                    Button("加入队伍", action: onJoin)
                        .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }
    }
}

private struct TeamCard: View {
    let team: Team
    let isOwner: Bool

    var body: some View {
        TeamRow(team: team, isOwner: isOwner)
    }
}

private struct TeamCardButtonStyle: ButtonStyle {
    private let projectionX: CGFloat = 2
    private let projectionY: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .padding(AppSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .fill(AppColor.surface)
            )
            .background(alignment: .topLeading) {
                // ASCII: 右下投影层，确保空间方向固定为右下生长。
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .fill(AppColor.stroke)
                    .offset(
                        x: isPressed ? 0 : projectionX,
                        y: isPressed ? 0 : projectionY
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(AppColor.stroke, lineWidth: 1.5)
            )
            .offset(
                x: isPressed ? projectionX : 0,
                y: isPressed ? projectionY : 0
            )
            .padding(.trailing, projectionX)
            .padding(.bottom, projectionY)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
            .animation(AppMotion.spring, value: isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
    }
}
