//
//  TeamRow.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: Team 数据与角色信息。
//  OUTPUT: 队伍列表行。
//  POS: 队伍列表子视图。
//

import SwiftUI

struct TeamRow: View {
    let team: Team
    let isOwner: Bool

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            TeamAvatarBadge(style: team.avatarStyle, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(team.name)
                        .font(AppFont.body())
                        .foregroundColor(AppColor.textPrimary)
                    if isOwner {
                        AppTag(text: "队长", color: AppColor.reward)
                    }
                }
                if let slogan = team.slogan, !slogan.isEmpty {
                    Text(slogan)
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.textMuted)
                        .lineLimit(1)
                } else {
                    Text("ID: \(team.publicId)")
                        .font(AppFont.caption())
                        .foregroundColor(AppColor.textMuted)
                        .monospacedDigit()
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(AppFont.iconSmall())
                Text("\(team.memberCount)")
                    .font(AppFont.caption())
            }
            .foregroundColor(AppColor.textSecondary)
        }
    }
}

#Preview {
    TeamRow(team: MockData.shared.myTeams[0], isOwner: true)
        .padding()
        .background(AppColor.background)
}
