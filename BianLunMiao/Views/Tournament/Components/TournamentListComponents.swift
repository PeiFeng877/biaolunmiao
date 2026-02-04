//
//  TournamentListComponents.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 赛事列表相关状态与设计令牌。
//  OUTPUT: 赛事首页复用组件。
//  POS: 赛事首页组件层。
//

import SwiftUI

struct TournamentTopBar: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            HStack(spacing: AppSpacing.s) {
                TournamentTopIconButton(
                    systemName: "pawprint.fill",
                    foreground: AppColor.eventIcon,
                    background: AppColor.eventAccent
                ) {}
                Text("赛事")
                    .font(AppFont.section())
                    .foregroundColor(AppColor.eventText)
            }

            Spacer()

            HStack(spacing: AppSpacing.m) {
                TournamentTopIconButton(
                    systemName: "plus",
                    foreground: AppColor.eventIcon,
                    background: AppColor.eventAccent,
                    action: onAdd
                )
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
    }
}

struct TournamentTopIconButton: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(foreground)
                .frame(width: 40, height: 40)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(AppColor.eventStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct TournamentSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.eventMuted)
            TextField("搜索辩论赛… (Search tournaments)", text: $text)
                .font(AppFont.body())
                .foregroundColor(AppColor.eventText)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .background(AppColor.eventCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .stroke(AppColor.eventStroke, lineWidth: 1)
        )
        .cornerRadius(AppRadius.l)
        .shadow(color: AppShadow.subtle, radius: 10, x: 0, y: 6)
        .padding(.horizontal, AppSpacing.l)
    }
}

struct TournamentFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body())
                .foregroundColor(isSelected ? AppColor.eventIcon : AppColor.eventText)
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.s)
                .background(isSelected ? AppColor.eventAccent : AppColor.eventCard)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                        .stroke(AppColor.eventStroke, lineWidth: 1)
                )
                .cornerRadius(AppRadius.l)
                .shadow(color: isSelected ? AppShadow.subtle : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct TournamentFeaturedCard: View {
    let card: TournamentListViewModel.TournamentCard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .fill(AppColor.eventAccent)

            HStack(spacing: AppSpacing.l) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    Text("FEATURED")
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.eventIcon)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, AppSpacing.s)
                        .background(AppColor.eventAccentSoft)
                        .clipShape(Capsule())

                    Text(card.headline)
                        .font(AppFont.hero())
                        .foregroundColor(AppColor.eventIcon)
                        .lineLimit(2)

                    Text(card.subheadline)
                        .font(AppFont.body())
                        .foregroundColor(AppColor.eventIcon.opacity(0.7))

                    HStack(spacing: AppSpacing.s) {
                        AppTag(text: statusText, color: statusColor)
                        Text("\(card.participantCount) 人参与")
                            .font(AppFont.caption())
                            .foregroundColor(AppColor.eventIcon.opacity(0.7))
                    }

                    Button("立即报名") {}
                        .font(AppFont.body())
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.s)
                        .background(AppColor.eventIcon)
                        .clipShape(Capsule())
                }

                Spacer()

                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .fill(AppColor.eventAccentStrong.opacity(0.6))
                    .frame(width: 120)
            }
            .padding(AppSpacing.l)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.l)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .stroke(AppColor.eventStroke, lineWidth: 1)
        )
        .cornerRadius(AppRadius.l)
        .shadow(color: AppShadow.subtle, radius: 10, x: 0, y: 6)
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
                        .foregroundColor(AppColor.eventText)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "bookmark")
                        .foregroundColor(AppColor.eventMuted)
                }

                Text(card.subheadline)
                    .font(AppFont.body())
                    .foregroundColor(AppColor.eventMuted)

                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "calendar")
                        .foregroundColor(AppColor.eventAccentStrong)
                    Text(card.dateText)
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.eventMuted)
                }

                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(AppColor.eventAccentStrong)
                    Text(card.locationText)
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.eventMuted)
                    Text("· \(card.participantCount) 人参与")
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.eventMuted)
                }
            }
        }
        .padding(AppSpacing.l)
        .background(AppColor.eventCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .stroke(AppColor.eventStroke, lineWidth: 1)
        )
        .cornerRadius(AppRadius.l)
        .shadow(color: AppShadow.subtle, radius: 10, x: 0, y: 6)
        .padding(.horizontal, AppSpacing.l)
    }

    private var statusBadge: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(statusText)
                .font(AppFont.caption())
        }
        .foregroundColor(AppColor.eventIcon)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(AppColor.eventAccentSoft)
        .clipShape(Capsule())
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
