//
//  TournamentDetailComponents.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 赛事详情页状态与设计令牌。
//  OUTPUT: 赛事详情页复用组件。
//  POS: 赛事详情组件层。
//

import SwiftUI

struct TournamentDetailTopBar: View {
    let onBack: () -> Void
    let onShare: () -> Void

    var body: some View {
        ZStack {
            Text("赛事详情")
                .font(AppFont.section())
                .foregroundColor(AppColor.eventText)

            HStack {
                AppTopBarButton(
                    systemName: "chevron.left",
                    foreground: AppColor.eventIcon,
                    background: AppColor.eventCard,
                    stroke: AppColor.eventStroke,
                    action: onBack
                )

                Spacer()

                AppTopBarButton(
                    systemName: "square.and.arrow.up",
                    foreground: AppColor.eventIcon,
                    background: AppColor.eventCard,
                    stroke: AppColor.eventStroke,
                    action: onShare
                )
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
    }
}

struct TournamentDetailHeader: View {
    let title: String
    let statusText: String
    let statusColor: Color
    let dateRange: String
    let teamCount: Int

    var body: some View {
        AppCard(
            style: .standard,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(AppFont.title())
                        .foregroundStyle(AppColor.eventText)
                        .lineLimit(2)
                    Spacer()
                    AppTag(text: statusText, color: statusColor)
                }

                HStack(spacing: AppSpacing.m) {
                    Label(dateRange, systemImage: "calendar")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.eventMuted)
                    Label("\(teamCount) 支队伍", systemImage: "person.3")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.eventMuted)
                }
            }
        }
    }
}

enum TournamentDetailTab: String, CaseIterable, Identifiable {
    case overview = "简介"
    case schedule = "赛程"
    case teams = "队伍"

    var id: String { rawValue }
}

struct TournamentDetailTabBar: View {
    let tabs: [TournamentDetailTab]
    @Binding var selected: TournamentDetailTab

    var body: some View {
        HStack(spacing: AppSpacing.xl) {
            ForEach(tabs) { tab in
                AppRowTapButton(action: { selected = tab }) {
                    VStack(spacing: AppSpacing.xs) {
                        Text(tab.rawValue)
                            .font(AppFont.body())
                            .foregroundColor(selected == tab ? AppColor.eventText : AppColor.eventMuted)
                        Capsule()
                            .fill(selected == tab ? AppColor.eventAccentStrong : Color.clear)
                            .frame(height: 3)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.s)
    }
}

struct TournamentOverviewCard: View {
    let text: String

    var body: some View {
        AppCard(
            style: .standard,
            alignment: .leading,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(text.isEmpty ? "赛事简介待补充" : text)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.eventText)
                Text("赛事将汇聚顶尖队伍，围绕热点辩题展开较量。")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.eventMuted)
            }
        }
    }
}

struct TournamentScheduleView: View {
    let days: [TournamentDetailViewModel.ScheduleDay]
    @Binding var selectedDayId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        TournamentDayChip(
                            dayIndex: index + 1,
                            date: day.date,
                            isSelected: selectedDayId == day.id
                        ) {
                            selectedDayId = day.id
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.s)
            }

            if let activeDay = activeDay {
                ForEach(activeDay.sessions) { session in
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        TournamentSessionHeader(title: session.title, time: session.timeLabel)
                        ForEach(session.matches) { match in
                            TournamentMatchCard(match: match)
                        }
                    }
                }
            } else {
                Text("暂无赛程")
                    .font(AppFont.caption())
                    .foregroundColor(AppColor.eventMuted)
            }
        }
        .onAppear {
            if selectedDayId == nil {
                selectedDayId = days.first?.id
            }
        }
        .onChange(of: days) { _, _ in
            if selectedDayId == nil {
                selectedDayId = days.first?.id
            }
        }
    }

    private var activeDay: TournamentDetailViewModel.ScheduleDay? {
        if let id = selectedDayId {
            return days.first(where: { $0.id == id })
        }
        return days.first
    }
}

struct TournamentDayChip: View {
    let dayIndex: Int
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        AppRowTapButton(action: action) {
            VStack(spacing: 4) {
                Text("Day \(dayIndex)")
                    .font(AppFont.caption())
                    .foregroundStyle(isSelected ? AppColor.eventIcon : AppColor.eventMuted)
                Text(dateText)
                    .font(AppFont.body())
                    .foregroundStyle(isSelected ? AppColor.eventIcon : AppColor.eventText)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.s)
            .background(isSelected ? AppColor.eventAccent : AppColor.eventCard)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .stroke(AppColor.eventStroke, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: AppRadius.l, style: .continuous))
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

struct TournamentSessionHeader: View {
    let title: String
    let time: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "clock")
                .foregroundColor(AppColor.eventMuted)
            Text("\(title) · \(time)")
                .font(AppFont.body())
                .foregroundColor(AppColor.eventText)
        }
    }
}

struct TournamentMatchCard: View {
    let match: TournamentDetailViewModel.ScheduleMatch

    var body: some View {
        AppCard(
            style: .standard,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.stage)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.eventAccentStrong)
                        Text(match.matchTitle)
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.eventText)
                    }
                    Spacer()
                    TournamentLocationBadge(text: match.location)
                }

                HStack(spacing: AppSpacing.l) {
                    TournamentTeamBlock(team: match.teamA)
                    TournamentVSBadge()
                    TournamentTeamBlock(team: match.teamB)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: AppSpacing.s) {
                    TournamentTopicBadge()
                    Text(match.topic)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.eventText)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct TournamentTeamBlock: View {
    let team: TournamentDetailViewModel.TeamSnapshot

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            TournamentTeamAvatar(seed: team.seed, text: teamInitials)
            Text(team.name)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.eventText)
        }
        .frame(maxWidth: .infinity)
    }

    private var teamInitials: String {
        String(team.name.prefix(2))
    }
}

struct TournamentTeamAvatar: View {
    let seed: Int
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundStyle(AppColor.eventIcon)
            .frame(width: 48, height: 48)
            .background(color)
            .clipShape(.circle)
            .overlay(
                Circle().stroke(AppColor.eventCard, lineWidth: 3)
            )
    }

    private var color: Color {
        let palette = [
            AppColor.eventAccentSoft,
            AppColor.avatar1,
            AppColor.avatar2,
            AppColor.avatar3,
            AppColor.avatar4
        ]
        return palette[abs(seed) % palette.count]
    }
}

struct TournamentVSBadge: View {
    var body: some View {
        Text("VS")
            .font(AppFont.caption())
            .foregroundStyle(AppColor.eventMuted)
            .frame(width: 36, height: 36)
            .background(AppColor.eventCard)
            .clipShape(.circle)
            .overlay(
                Circle().stroke(AppColor.eventStroke, lineWidth: 1)
            )
    }
}

struct TournamentLocationBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "mappin.and.ellipse")
                .font(AppFont.iconSmall())
            Text(text)
                .font(AppFont.caption())
        }
        .foregroundStyle(AppColor.eventText)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(AppColor.eventCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .stroke(AppColor.eventStroke, lineWidth: 1)
        )
        .clipShape(.capsule)
    }
}

struct TournamentTopicBadge: View {
    var body: some View {
        Text("辩题")
            .font(AppFont.caption())
            .foregroundStyle(AppColor.eventIcon)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, 4)
            .background(AppColor.eventAccentSoft)
            .clipShape(.capsule)
    }
}

struct TournamentTeamsView: View {
    let teams: [TournamentDetailViewModel.TeamEntry]

    @State private var selectedFilter: TournamentTeamFilter = .all

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: AppSpacing.m),
        GridItem(.flexible(), spacing: AppSpacing.m)
    ]

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(TournamentTeamFilter.allCases) { filter in
                        TournamentFilterChip(
                            title: filter.title,
                            isSelected: filter == selectedFilter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.s)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.l) {
                ForEach(filteredTeams) { team in
                    TournamentTeamCard(team: team)
                }
            }
        }
    }

    private var filteredTeams: [TournamentDetailViewModel.TeamEntry] {
        switch selectedFilter {
        case .all:
            return teams
        case .confirmed:
            return teams.filter { $0.status == .confirmed }
        case .pending:
            return teams.filter { $0.status == .pending }
        case .waitlist:
            return teams.filter { $0.status == .waitlist }
        }
    }
}

struct TournamentTeamCard: View {
    let team: TournamentDetailViewModel.TeamEntry

    var body: some View {
        AppCard(
            style: .standard,
            alignment: .center,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(spacing: AppSpacing.s) {
                ZStack(alignment: .bottomTrailing) {
                    TournamentTeamAvatar(seed: team.seed, text: String(team.name.prefix(2)))
                    if team.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(AppFont.iconMedium())
                            .foregroundStyle(AppColor.eventAccentStrong)
                            .background(Circle().fill(AppColor.eventCard))
                            .offset(x: 6, y: 6)
                    }
                }

                Text(team.name)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.eventText)

                Text(team.school)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.eventAccentStrong)

                TournamentTeamStatusBadge(status: team.status)
            }
        }
    }
}

struct TournamentTeamStatusBadge: View {
    let status: TournamentDetailViewModel.TeamStatus

    var body: some View {
        Text(status.label)
            .font(AppFont.caption())
            .foregroundStyle(textColor)
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.s)
            .background(backgroundColor)
            .clipShape(.capsule)
    }

    private var textColor: Color {
        switch status {
        case .confirmed:
            return AppColor.eventAccentStrong
        case .pending:
            return AppColor.reward
        case .waitlist:
            return AppColor.eventMuted
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .confirmed:
            return AppColor.eventAccentSoft
        case .pending:
            return AppColor.reward.opacity(0.15)
        case .waitlist:
            return AppColor.eventStroke
        }
    }
}

enum TournamentTeamFilter: String, CaseIterable, Identifiable {
    case all
    case confirmed
    case pending
    case waitlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .confirmed:
            return "已确认"
        case .pending:
            return "审核中"
        case .waitlist:
            return "候补"
        }
    }
}
