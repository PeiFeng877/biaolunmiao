//
//  ScheduleEventDetailComponents.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 当日赛事与时间轴渲染数据。
//  OUTPUT: 赛事详情卡片与时间轴组件。
//  POS: 日程页复用组件。
//

import SwiftUI

struct ScheduleEventDetailCard: View {
    let match: Match
    let tournamentName: String?
    let onAddToCalendar: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack(alignment: .top, spacing: AppSpacing.s) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.name)
                            .font(AppFont.section())
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(2)

                        if let tournamentName {
                            Text(tournamentName)
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }

                    Spacer(minLength: 0)

                    AppTag(text: match.status.title, color: match.status.color)
                }

                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "clock")
                        .font(AppFont.iconSmall())
                    Text("\(match.startTime.formatted(date: .omitted, time: .shortened)) - \(match.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textPrimary)
                }

                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(AppFont.iconSmall())
                    Text(match.location ?? "地点待定")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary)
                }

                HStack(spacing: AppSpacing.s) {
                    AppButton("添加到日历", variant: .toolbarText, action: onAddToCalendar)
                    Spacer()
                }
                .padding(.top, AppSpacing.xs)
            }
        }
    }
}

struct ScheduleTimelineView: View {
    let matches: [Match]
    let selectedDate: Date
    let tournamentNameProvider: ((Match) -> String?)?
    let teamsLineProvider: ((Match) -> String)?
    let onAddToCalendar: ((Match) -> Void)?

    private var calendar: Calendar { .current }
    private let rowHeight: CGFloat = 68

    init(
        matches: [Match],
        selectedDate: Date,
        tournamentNameProvider: ((Match) -> String?)? = nil,
        teamsLineProvider: ((Match) -> String)? = nil,
        onAddToCalendar: ((Match) -> Void)? = nil
    ) {
        self.matches = matches
        self.selectedDate = selectedDate
        self.tournamentNameProvider = tournamentNameProvider
        self.teamsLineProvider = teamsLineProvider
        self.onAddToCalendar = onAddToCalendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hourRows, id: \.hour) { row in
                timelineRow(hour: row.hour, matches: row.matches)
            }
        }
        .accessibilityIdentifier("schedule_timeline")
    }

    private var hourRows: [(hour: Int, matches: [Match])] {
        let grouped = Dictionary(grouping: matches) { match in
            calendar.component(.hour, from: match.startTime)
        }

        let minHour = matches.map { calendar.component(.hour, from: $0.startTime) }.min() ?? 8
        let maxHour = matches.map { calendar.component(.hour, from: $0.endTime) }.max() ?? 20

        let startHour = max(min(minHour, 8) - 3, 0)
        let endHour = min(max(maxHour, 20) + 1, 23)

        return (startHour...endHour).map { hour in
            let items = (grouped[hour] ?? []).sorted { $0.startTime < $1.startTime }
            return (hour: hour, matches: items)
        }
    }

    private func timelineRow(hour: Int, matches: [Match]) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            Text(hourLabel(hour))
                .font(AppFont.body())
                .foregroundStyle(AppColor.textMuted)
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
                .padding(.top, 2)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(AppColor.stroke.opacity(0.24))
                    .frame(height: 1)
                    .padding(.top, 11)

                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(matches) { match in
                            timelineEventBlock(match)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .topLeading)
        }
        .padding(.vertical, 2)
    }

    private func timelineEventBlock(_ match: Match) -> some View {
        let start = match.startTime.formatted(date: .omitted, time: .shortened)
        let end = match.endTime.formatted(date: .omitted, time: .shortened)
        let location = (match.location?.isEmpty == false) ? match.location! : "地点待定"
        let tournamentName = tournamentNameProvider?(match) ?? "未关联赛事"
        let topic = {
            let trimmed = (match.topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "待定" : trimmed
        }()
        let teamsLine = teamsLineProvider?(match) ?? "待定队伍 vs 待定队伍"

        return HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColor.reward)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.name)
                    .font(AppFont.body().weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)

                Text(tournamentName)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)

                Text("辩题：\(topic)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)

                Text("队伍：\(teamsLine)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)

                Text("时间：\(start) - \(end)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textMuted)
                    .lineLimit(1)

                Text("地点：\(location)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let onAddToCalendar {
                AppRowTapButton {
                    onAddToCalendar(match)
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(AppFont.iconSmall())
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(4)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColor.reward.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .stroke(AppColor.stroke.opacity(0.2), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: AppRadius.s, style: .continuous))
    }

    private func hourLabel(_ hour: Int) -> String {
        let base = calendar.startOfDay(for: selectedDate)
        let date = calendar.date(byAdding: .hour, value: hour, to: base) ?? base
        return date.formatted(.dateTime.hour())
    }
}

private extension MatchStatus {
    var title: String {
        switch self {
        case .scheduled:
            return "未开始"
        case .ready:
            return "可开赛"
        case .ongoing:
            return "进行中"
        case .finished:
            return "已结束"
        }
    }

    var color: Color {
        switch self {
        case .scheduled:
            return AppColor.infoBlue
        case .ready:
            return AppColor.primaryStrong
        case .ongoing:
            return AppColor.reward
        case .finished:
            return AppColor.textSecondary
        }
    }
}
