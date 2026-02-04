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
            ZStack {
                Circle()
                    .fill(AppColor.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(team.name.prefix(1))
                    .font(AppFont.section())
                    .foregroundColor(AppColor.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(team.name)
                        .font(AppFont.body())
                        .foregroundColor(AppColor.textPrimary)
                    if isOwner {
                        AppTag(text: "队长", color: AppColor.reward)
                    }
                }
                Text("ID: \(team.publicId)")
                    .font(AppFont.caption())
                    .foregroundColor(AppColor.textMuted)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                Text("\(team.memberCount)")
                    .font(AppFont.caption())
            }
            .foregroundColor(AppColor.textSecondary)
        }
        .padding(.vertical, AppSpacing.m)
    }
}

#Preview {
    TeamRow(team: MockData.shared.myTeams[0], isOwner: true)
        .padding()
        .background(AppColor.background)
}
