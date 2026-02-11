//
//  TournamentListComponents.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 赛事列表状态与设计令牌。
//  OUTPUT: 赛事首页复用组件。
//  POS: 赛事首页组件层。
//

import SwiftUI

enum TournamentFilter: String, CaseIterable, Identifiable {
    case all
    case draft
    case open
    case ongoing
    case ended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .draft:
            return "待发布"
        case .open:
            return "报名中"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        }
    }

    func matches(status: TournamentStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .draft:
            return status == .draft
        case .open:
            return status == .open
        case .ongoing:
            return status == .ongoing
        case .ended:
            return status == .ended
        }
    }
}

struct TournamentFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        AppRowTapButton(action: action) {
            Text(title)
                .font(AppFont.caption())
                .tracking(AppFont.tracking)
                .foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(isSelected ? AppColor.primarySoft : AppColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                        .stroke(AppColor.stroke, lineWidth: 1.5)
                )
                .clipShape(.rect(cornerRadius: AppRadius.l, style: .continuous))
        }
    }
}

struct TournamentListCard: View {
    let card: TournamentListViewModel.TournamentCard

    var body: some View {
        AppCard(style: .standard) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                    Text(card.title)
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    AppTag(text: statusTitle, color: statusColor)
                }

                Text(card.intro)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.s) {
                    infoPill(systemName: "person.2.fill", text: "\(card.participantCount) 支")
                    infoPill(systemName: "flag.checkered", text: "\(card.matchCount) 场")

                    if let latestMatchTime = card.latestMatchTime {
                        infoPill(
                            systemName: "calendar",
                            text: latestMatchTime.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
            }
        }
    }

    private var statusTitle: String {
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
            return AppColor.textSecondary
        case .open:
            return AppColor.primaryStrong
        case .ongoing:
            return AppColor.infoBlue
        case .ended:
            return AppColor.textSecondary
        case .cancelled:
            return AppColor.danger
        }
    }

    private func infoPill(systemName: String, text: String) -> some View {
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
