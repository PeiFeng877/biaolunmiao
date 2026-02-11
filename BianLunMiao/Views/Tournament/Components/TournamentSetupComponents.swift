//
//  TournamentSetupComponents.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 赛程设定与发布页面的状态。
//  OUTPUT: 赛程设定/发布流程组件。
//  POS: 赛事设定组件层。
//

import SwiftUI

struct TournamentSetupTopBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
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
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
    }
}

struct TournamentSetupProgress: View {
    let step: Int
    let total: Int
    let title: String

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                ForEach(1...total, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppColor.eventAccentStrong : AppColor.eventStroke)
                        .frame(height: 6)
                }
            }
            Text("步骤 \(step)/\(total): \(title)")
                .font(AppFont.caption())
                .foregroundColor(AppColor.eventAccentStrong)
        }
        .padding(.horizontal, AppSpacing.l)
    }
}

struct TournamentRoundCard: View {
    @Binding var round: TournamentScheduleSetupViewModel.RoundConfig
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        AppCard(
            style: .standard,
            stroke: AppColor.eventStroke,
            background: { AppColor.eventCard }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    HStack(spacing: AppSpacing.s) {
                        Text("\(round.index)")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.eventText)
                            .frame(width: 26, height: 26)
                            .background(AppColor.eventAccentSoft)
                            .clipShape(.circle)
                        Text("第 \(round.index) 轮")
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.eventText)
                    }
                    Spacer()
                    if canDelete {
                        AppRowTapButton(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundStyle(AppColor.eventMuted)
                        }
                    }
                }

                AppFormField(
                    title: "轮次名称",
                    labelColor: AppColor.eventMuted,
                    helperColor: AppColor.eventMuted,
                    counterColor: AppColor.eventMuted
                ) {
                        AppIconField(
                            systemName: "text.quote",
                            placeholder: "例如：初赛",
                            text: $round.title,
                            style: .tournament
                        )
                }

                HStack(spacing: AppSpacing.m) {
                    AppFormField(
                        title: "日期",
                        labelColor: AppColor.eventMuted,
                        helperColor: AppColor.eventMuted,
                        counterColor: AppColor.eventMuted
                    ) {
                        AppIconField(
                            systemName: "calendar",
                            placeholder: "选择日期",
                            text: $round.date,
                            style: .tournament
                        )
                    }

                    AppFormField(
                        title: "时间",
                        labelColor: AppColor.eventMuted,
                        helperColor: AppColor.eventMuted,
                        counterColor: AppColor.eventMuted
                    ) {
                        AppIconField(
                            systemName: "clock",
                            placeholder: "--:--",
                            text: $round.time,
                            style: .tournament
                        )
                    }
                }

                AppFormField(
                    title: "地点",
                    labelColor: AppColor.eventMuted,
                    helperColor: AppColor.eventMuted,
                    counterColor: AppColor.eventMuted
                ) {
                    AppIconField(
                        systemName: "mappin.and.ellipse",
                        placeholder: "选择或输入地点",
                        text: $round.location,
                        style: .tournament
                    )
                }
            }
        }
    }
}

struct TournamentAddRoundButton: View {
    let action: () -> Void

    var body: some View {
        AppRowTapButton(action: action) {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: "plus.circle.fill")
                Text("添加新轮次")
                    .font(AppFont.body())
            }
            .foregroundColor(AppColor.eventAccentStrong)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundColor(AppColor.eventAccentSoft)
            )
        }
    }
}

struct TournamentPublishBottomBar: View {
    let leftText: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(leftText)
                .font(AppFont.body())
                .foregroundColor(AppColor.eventText)
            Spacer()
            AppRowTapButton(action: action) {
                Text(actionTitle)
                    .font(AppFont.body())
                    .foregroundColor(AppColor.eventIcon)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.s)
                    .background(AppColor.eventAccent)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .background(AppColor.eventCard)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(AppColor.eventStroke),
            alignment: .top
        )
    }
}
