//
//  TeamListView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/23.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: TeamListViewModel 提供的队伍列表。
//  OUTPUT: 带创建/申请入口的队伍主页。
//  POS: 队伍 Tab 根页面。
//

import SwiftUI

struct TeamListView: View {
    @StateObject private var viewModel: TeamListViewModel
    private let store: AppStore
    @State private var navigationPath: [UUID] = []
    @State private var showSearchPage = false
    @State private var toast: AppToastPayload?

    private var shouldTraceCreateTeam: Bool {
#if DEBUG
        return true
#else
        let env = ProcessInfo.processInfo.environment
        return env["BLM_UI_TEST_MODE"] == "1" || env["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] == "1"
#endif
    }

    private var uiTestQuickCreateProfile: TeamProfileInput? {
        let env = ProcessInfo.processInfo.environment
        let slogan = env["BLM_UI_TEST_TEAM_SLOGAN"] ?? ""
        guard
            env["BLM_UI_TEST_MODE"] == "1",
            env["BLM_UI_TEST_REMOTE_TEAM_CREATE"] == "1",
            let rawName = env["BLM_UI_TEST_TEAM_NAME"]
        else {
            return nil
        }

        let snapshot = TeamProfileInput.normalized(name: rawName, slogan: slogan, avatarImageData: nil)
        guard !snapshot.name.isEmpty else {
            return nil
        }
        return snapshot
    }

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("team_list_root")

                VStack(spacing: 0) {
                    AppTopBar(
                        title: "队伍",
                        style: .team,
                        showsLeadingIcon: false,
                        secondaryActionSystemName: "magnifyingglass",
                        secondaryActionAccessibilityId: "team_search_button",
                        onSecondaryAction: { showSearchPage = true },
                        addAccessibilityId: "team_add_button",
                        onAdd: { handleCreateAction() }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.l) {
                            if viewModel.teams.isEmpty {
                                TeamEmptyStateCard(
                                    onCreate: { handleCreateAction() },
                                    onJoin: { showSearchPage = true }
                                )
                            } else {
                                VStack(spacing: AppSpacing.m) {
                                    ForEach(viewModel.teams) { team in
                                        AppRowTapButton {
                                            navigationPath.append(team.id)
                                        } label: {
                                            TeamCard(team: team, isOwner: viewModel.isOwner(team: team))
                                                .contentShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
                                        }
                                        // 导航型卡片用统一行点击按钮，避免业务层裸 Button。
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
                    .refreshable {
                        await refreshAppData()
                    }
                }
            }
            .navigationDestination(for: UUID.self) { teamId in
                TeamDetailView(store: store, teamId: teamId)
            }
            .navigationDestination(isPresented: $showSearchPage) {
                TeamSearchView(viewModel: viewModel)
            }
            .toolbar(.hidden, for: .navigationBar)
            .appSheet(isPresented: $viewModel.showCreateSheet) {
                CreateTeamSheet { @MainActor profile in
                    traceCreateTeam("sheet onSave entered actor=main")
                    let payload = profile.createPayload
                    traceCreateTeam("payload prepared nameLength=\(payload.name.count) sloganLength=\(payload.slogan?.count ?? 0)")
                    traceCreateTeam("before viewModel createTeam await")
                    do {
                        let team = try await viewModel.createTeam(payload: payload)
                        traceCreateTeam("viewModel createTeam succeeded")
                        navigationPath.append(team.id)
                    } catch {
                        traceCreateTeam("viewModel createTeam failed error=\(error.localizedDescription)")
                        throw error
                    }
                }
            }
            .appToast(item: $toast)
        }
    }
}

private extension TeamListView {
    func handleCreateAction() {
        guard let uiTestQuickCreateProfile else {
            viewModel.showCreateSheet = true
            return
        }

        traceCreateTeam("ui test quick create started")
        Task { @MainActor in
            do {
                let team = try await viewModel.createTeam(payload: uiTestQuickCreateProfile.createPayload)
                traceCreateTeam("ui test quick create succeeded")
                toast = AppToastPayload(
                    title: "队伍已创建",
                    message: team.name,
                    intent: .success,
                    accessibilityIdentifier: "team_create_success_toast"
                )
                navigationPath.append(team.id)
            } catch {
                traceCreateTeam("ui test quick create failed")
                toast = AppToastPayload(
                    title: "创建队伍失败",
                    message: error.localizedDescription,
                    intent: .error
                )
            }
        }
    }

    func traceCreateTeam(_ message: String) {
        guard shouldTraceCreateTeam else { return }
        print("[TeamListView] \(message)")
    }

    @MainActor
    func refreshAppData() async {
        do {
            try await store.refreshNow(force: true)
        } catch {
            toast = AppToastPayload(
                title: "刷新失败",
                message: error.localizedDescription,
                intent: .error
            )
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
                    AppButton("创建队伍", variant: .primary, action: onCreate)

                    AppButton("加入队伍", variant: .secondary, action: onJoin)
                }
            }
        }
    }
}

private struct TeamCard: View {
    let team: Team
    let isOwner: Bool

    var body: some View {
        AppCard(style: .standard) {
            TeamRow(team: team, isOwner: isOwner)
        }
    }
}
