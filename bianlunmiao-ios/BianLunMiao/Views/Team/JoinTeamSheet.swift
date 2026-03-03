//
//  JoinTeamSheet.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 队伍 ID 输入与申请提交回调。
//  OUTPUT: 申请入队的轻量表单弹窗。
//  POS: 队伍管理流程。
//

import SwiftUI

struct JoinTeamSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var teamId = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    let defaultPersonalNote: String
    let onSubmit: (String, String, String) async throws -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    Text("通过队伍 ID 申请")
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)

                    AppFormField(
                        title: "队伍 ID",
                        error: errorMessage
                    ) {
                        AppTextField(placeholder: "输入队伍 ID", text: $teamId)
                    }

                    HStack(spacing: AppSpacing.s) {
                        AppButton("取消", variant: .ghost) { dismiss() }

                        AppButton("提交申请", variant: .primary) {
                            Task {
                                await submit()
                            }
                        }
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.56 : 1)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
            .navigationTitle("申请入队")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await onSubmit(
                teamId.trimmingCharacters(in: .whitespacesAndNewlines),
                defaultPersonalNote,
                ""
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

#Preview {
    JoinTeamSheet(defaultPersonalNote: "培风") { _, _, _ in
        throw TeamJoinRequestError.notFound
    }
}
