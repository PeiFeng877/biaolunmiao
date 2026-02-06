//
//  JoinTeamSheet.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 队伍 ID 输入与加入回调。
//  OUTPUT: 加入队伍的轻量表单弹窗。
//  POS: 队伍管理流程。
//

import SwiftUI

struct JoinTeamSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var teamId: String = ""
    @State private var errorMessage: String?

    let onJoin: (String) -> JoinTeamResult

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    Text("通过队伍 ID 加入")
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)

                    AppFormField(
                        title: "队伍 ID",
                        error: errorMessage
                    ) {
                        AppTextField(placeholder: "输入队伍 ID", text: $teamId)
                    }

                    Button("申请加入") {
                        let result = onJoin(teamId.trimmingCharacters(in: .whitespacesAndNewlines))
                        switch result {
                        case .success:
                            dismiss()
                        case .failure(let error):
                            errorMessage = error.rawValue
                        }
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
            .navigationTitle("加入队伍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }
}

#Preview {
    JoinTeamSheet { _ in .failure(.notFound) }
}
