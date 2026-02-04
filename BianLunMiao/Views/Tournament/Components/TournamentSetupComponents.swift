//
//  TournamentSetupComponents.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
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
                TournamentTopIconButton(
                    systemName: "chevron.left",
                    foreground: AppColor.eventIcon,
                    background: AppColor.eventCard,
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
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                HStack(spacing: AppSpacing.s) {
                    Text("\(round.index)")
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.eventText)
                        .frame(width: 26, height: 26)
                        .background(AppColor.eventAccentSoft)
                        .clipShape(Circle())
                    Text("第 \(round.index) 轮")
                        .font(AppFont.body())
                        .foregroundColor(AppColor.eventText)
                }
                Spacer()
                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColor.eventMuted)
                    }
                    .buttonStyle(.plain)
                }
            }

            TournamentInputField(
                icon: "text.quote",
                title: "轮次名称",
                placeholder: "例如：初赛 (Preliminaries)",
                text: $round.title
            )

            HStack(spacing: AppSpacing.m) {
                TournamentInputField(
                    icon: "calendar",
                    title: "日期",
                    placeholder: "选择日期",
                    text: $round.date
                )
                TournamentInputField(
                    icon: "clock",
                    title: "时间",
                    placeholder: "--:--",
                    text: $round.time
                )
            }

            TournamentInputField(
                icon: "mappin.and.ellipse",
                title: "地点",
                placeholder: "选择或输入地点",
                text: $round.location
            )
        }
        .padding(AppSpacing.l)
        .background(AppColor.eventCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .stroke(AppColor.eventStroke, lineWidth: 1)
        )
        .cornerRadius(AppRadius.l)
        .shadow(color: AppShadow.subtle, radius: 8, x: 0, y: 4)
    }
}

struct TournamentInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(AppColor.eventMuted)
            HStack(spacing: AppSpacing.s) {
                Image(systemName: icon)
                    .foregroundColor(AppColor.eventMuted)
                TextField(placeholder, text: $text)
                    .font(AppFont.body())
                    .foregroundColor(AppColor.eventText)
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.m)
            .background(AppColor.eventBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .stroke(AppColor.eventStroke, lineWidth: 1)
            )
            .cornerRadius(AppRadius.l)
        }
    }
}

struct TournamentAddRoundButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
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
            Button(actionTitle, action: action)
                .font(AppFont.body())
                .foregroundColor(.black)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.s)
                .background(AppColor.eventAccent)
                .clipShape(Capsule())
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
