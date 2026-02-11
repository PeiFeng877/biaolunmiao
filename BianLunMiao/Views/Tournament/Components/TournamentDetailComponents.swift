//
//  TournamentDetailComponents.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 赛事详情页状态与设计令牌。
//  OUTPUT: 赛事详情页复用组件。
//  POS: 赛事详情组件层。
//

import SwiftUI

enum TournamentDetailTab: String, CaseIterable, Identifiable {
    case overview = "概览"
    case schedule = "赛程"
    case teams = "队伍"

    var id: String { rawValue }
}

struct TournamentStatusTag: View {
    let text: String
    let token: ColorToken

    var body: some View {
        AppTag(text: text, color: color)
    }

    private var color: Color {
        switch token {
        case .primary:
            return AppColor.primaryStrong
        case .secondary:
            return AppColor.textSecondary
        case .info:
            return AppColor.infoBlue
        case .danger:
            return AppColor.danger
        }
    }
}

struct TournamentDetailHeaderCard: View {
    let title: String
    let intro: String
    let statusText: String
    let statusToken: ColorToken
    let participantCount: Int
    let matchCount: Int

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                    Text(title)
                        .font(AppFont.title())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    TournamentStatusTag(text: statusText, token: statusToken)
                }

                Text(intro)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(3)

                HStack(spacing: AppSpacing.s) {
                    StatPill(systemName: "person.2.fill", text: "\(participantCount) 支参赛队")
                    StatPill(systemName: "flag.checkered", text: "\(matchCount) 场赛程")
                }
            }
        }
    }
}

struct TournamentDetailTabBar: View {
    @Binding var selected: TournamentDetailTab

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            ForEach(TournamentDetailTab.allCases) { tab in
                TournamentFilterChip(
                    title: tab.rawValue,
                    isSelected: selected == tab
                ) {
                    selected = tab
                }
            }
        }
    }
}

struct TournamentMatchItemCard: View {
    let match: Match
    let teamAName: String
    let teamBName: String
    let scoreText: String

    var body: some View {
        AppCard(style: .standard) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                    Text(match.name)
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    AppTag(text: statusText, color: statusColor)
                }

                Text(match.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)

                Text("\(teamAName) VS \(teamBName)")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary)

                if match.status == .finished {
                    Text("比分：\(scoreText)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }

    private var statusText: String {
        switch match.status {
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

    private var statusColor: Color {
        switch match.status {
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
}

struct TournamentParticipantCard: View {
    let team: Team

    var body: some View {
        AppCard(style: .standard) {
            HStack(spacing: AppSpacing.m) {
                TeamAvatarView(team: team, size: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textPrimary)
                    Text("ID: \(team.publicId)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                }

                Spacer()

                AppTag(text: "已确认", color: AppColor.primaryStrong)
            }
        }
    }
}

private struct StatPill: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemName)
                .font(AppFont.iconSmall())
            Text(text)
                .font(AppFont.caption())
        }
        .foregroundStyle(AppColor.textSecondary)
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, 4)
        .background(AppColor.surface)
        .overlay(
            Capsule().stroke(AppColor.stroke, lineWidth: 1.2)
        )
        .clipShape(.capsule)
    }
}
