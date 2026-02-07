//
//  TournamentListComponents.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 赛事列表相关状态与设计令牌。
//  OUTPUT: 赛事首页复用组件。
//  POS: 赛事首页组件层。
//

import SwiftUI

struct TournamentFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(isSelected ? AppColor.eventIcon : AppColor.eventText)
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.s)
                .background(isSelected ? AppColor.eventAccent : AppColor.eventCard)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                        .stroke(AppColor.eventStroke, lineWidth: 1.5)
                )
                .clipShape(.rect(cornerRadius: AppRadius.l, style: .continuous))
                .shadow(
                    color: isSelected ? AppShadow.standard.color : Color.clear,
                    radius: 0,
                    x: isSelected ? AppShadow.standard.x : 0,
                    y: isSelected ? AppShadow.standard.y : 0
                )
        }
        .buttonStyle(.plain)
    }
}

struct TournamentFeaturedCard: View {
    let card: TournamentListViewModel.TournamentCard

    var body: some View {
        AppCard(
            style: .emphasis,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventAccent }
        ) {
            HStack(spacing: AppSpacing.l) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    Text("FEATURED")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.eventIcon)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, AppSpacing.s)
                        .background(AppColor.eventAccentSoft)
                        .clipShape(.capsule)

                    Text(card.headline)
                        .font(AppFont.hero())
                        .foregroundStyle(AppColor.eventIcon)
                        .lineLimit(2)

                    Text(card.subheadline)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.eventIcon.opacity(0.7))

                    HStack(spacing: AppSpacing.s) {
                        AppTag(text: statusText, color: statusColor)
                        Text("\(card.participantCount) 人参与")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.eventIcon.opacity(0.7))
                    }

                    Button("立即报名") {}
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textOnDark)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.s)
                        .background(AppColor.eventIcon)
                        .clipShape(.capsule)
                }

                Spacer()

                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .fill(AppColor.eventAccentStrong.opacity(0.6))
                    .frame(width: 120)
            }
        }
        .padding(.horizontal, AppSpacing.l)
    }

    private var statusText: String {
        switch card.status {
        case .draft:
            return "待发布"
        case .open:
            return "报名中"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        case .cancelled:
            return "已取消"
        }
    }

    private var statusColor: Color {
        switch card.status {
        case .draft:
            return AppColor.eventMuted
        case .open:
            return AppColor.eventIcon
        case .ongoing:
            return AppColor.eventIcon
        case .ended:
            return AppColor.eventMuted
        case .cancelled:
            return AppColor.danger
        }
    }
}

struct TournamentListCard: View {
    let card: TournamentListViewModel.TournamentCard

    var body: some View {
        AppCard(
            style: .standard,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColor.eventAccentSoft.opacity(0.4),
                                    AppColor.eventAccentStrong.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)

                    statusBadge
                        .padding(AppSpacing.m)
                }

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(card.headline)
                            .font(AppFont.section())
                            .foregroundStyle(AppColor.eventText)
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "bookmark")
                            .foregroundStyle(AppColor.eventMuted)
                    }

                    Text(card.subheadline)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.eventMuted)

                    HStack(spacing: AppSpacing.s) {
                        Image(systemName: "calendar")
                            .foregroundStyle(AppColor.eventAccentStrong)
                        Text(card.dateText)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.eventMuted)
                    }

                    HStack(spacing: AppSpacing.s) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(AppColor.eventAccentStrong)
                        Text(card.locationText)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.eventMuted)
                        Text("· \(card.participantCount) 人参与")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.eventMuted)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.l)
    }

    private var statusBadge: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: statusIcon)
                .font(AppFont.iconSmall())
            Text(statusText)
                .font(AppFont.caption())
        }
        .foregroundStyle(AppColor.eventIcon)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(AppColor.eventAccentSoft)
        .clipShape(.capsule)
    }

    private var statusText: String {
        switch card.status {
        case .draft:
            return "即将开始"
        case .open:
            return "报名中"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        case .cancelled:
            return "已取消"
        }
    }

    private var statusIcon: String {
        switch card.status {
        case .draft:
            return "hourglass"
        case .open:
            return "tray.full"
        case .ongoing:
            return "bolt"
        case .ended:
            return "checkmark.circle"
        case .cancelled:
            return "xmark.circle"
        }
    }
}

enum TournamentFilter: String, CaseIterable, Identifiable {
    case hot
    case open
    case upcoming
    case campus
    case regional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hot:
            return "推荐 (Hot)"
        case .open:
            return "报名中"
        case .upcoming:
            return "即将开始"
        case .campus:
            return "高校赛"
        case .regional:
            return "地区赛"
        }
    }
}
