//
//  MemberDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: MemberDetailViewModel 提供的成员资料与赛程。
//  OUTPUT: 队员个人详情页与过往/近期赛程展示。
//  POS: 队伍成员二级页面。
//

import SwiftUI

private enum MemberDetailTab: String, CaseIterable, Identifiable {
    case past = "过往比赛记录"
    case upcoming = "近期日程"

    var id: String { rawValue }
}

struct MemberDetailView: View {
    @StateObject private var viewModel: MemberDetailViewModel
    @State private var selectedTab: MemberDetailTab = .upcoming

    init(store: AppStore, user: User) {
        _viewModel = StateObject(wrappedValue: MemberDetailViewModel(store: store, user: user))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    memberHeader

                    Picker("成员信息", selection: $selectedTab) {
                        ForEach(MemberDetailTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == .past {
                        matchSection(title: "过往比赛记录", matches: viewModel.pastMatches)
                    } else {
                        matchSection(title: "近期日程", matches: viewModel.upcomingMatches)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationTitle(viewModel.user.nickname)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var memberHeader: some View {
        AppCard {
            HStack(spacing: AppSpacing.m) {
                Circle()
                    .fill(AppColor.primary.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text(viewModel.user.nickname.prefix(1))
                            .font(AppFont.title())
                            .foregroundStyle(AppColor.primary)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.user.nickname)
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)
                    Text("ID: \(viewModel.user.publicId)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textMuted)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func matchSection(title: String, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title, trailing: "共 \(matches.count) 场")

            if matches.isEmpty {
                AppCard {
                    AppEmptyState(title: "暂无记录", subtitle: "该成员还没有赛程安排", systemImage: "clock")
                }
            } else {
                AppCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(matches) { match in
                            MemberMatchRow(match: match)
                                .padding(.vertical, AppSpacing.m)

                            if match.id != matches.last?.id {
                                Divider().overlay(AppColor.outline)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                }
            }
        }
    }
}

private struct MemberMatchRow: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(match.name)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary)

            HStack(spacing: AppSpacing.s) {
                Text(match.startTime, style: .date)
                Text(match.startTime, style: .time)
            }
            .font(AppFont.caption())
            .foregroundStyle(AppColor.textSecondary)

            if let location = match.location, !location.isEmpty {
                Text(location)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textMuted)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MemberDetailView(store: AppStore(), user: MockData.shared.currentUser)
    }
}
