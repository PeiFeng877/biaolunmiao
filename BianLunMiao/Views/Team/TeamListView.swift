//
//  TeamListView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: TeamListViewModel 提供的队伍列表。
//  OUTPUT: 以平面列表呈现的队伍入口页。
//  POS: 我的 Tab 根页面。
//

import SwiftUI

struct TeamListView: View {
    @StateObject private var viewModel: TeamListViewModel
    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamListViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppSectionHeader("我的队伍", trailing: "共 \(viewModel.teams.count) 支")

                        if viewModel.teams.isEmpty {
                            VStack {
                                AppEmptyState(title: "还没有队伍", subtitle: "创建第一支队伍，马上开战", systemImage: "flag.checkered")
                            }
                            .padding(AppSpacing.l)
                            .background(AppColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                                    .stroke(AppColor.outline, lineWidth: 1)
                            )
                            .cornerRadius(AppRadius.l)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(viewModel.teams) { team in
                                    NavigationLink(destination: TeamDetailView(store: store, teamId: team.id)) {
                                        TeamRow(team: team, isOwner: viewModel.isOwner(team: team))
                                    }
                                    .buttonStyle(.plain)

                                    if team.id != viewModel.teams.last?.id {
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
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateTeamSheet { name, intro in
                    viewModel.createTeam(name: name, intro: intro)
                }
            }
        }
    }
}

#Preview {
    TeamListView(store: AppStore())
}
