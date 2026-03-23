//
//  CreateTournamentView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 赛事表单数据与保存回调。
//  OUTPUT: 赛事创建弹窗。
//  POS: 赛事管理流程。
//

import SwiftUI

struct CreateTournamentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var intro: String = ""
    @State private var status: TournamentStatus = .open
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    let onSave: (String, String, TournamentStatus) async throws -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(title: "赛事名称", isRequired: true, error: errorMessage) {
                            AppTextField(placeholder: "输入赛事名称", text: $name)
                                .accessibilityIdentifier("tournament_create_name_input")
                        }

                        AppFormField(title: "赛事简介") {
                            AppTextEditor(placeholder: "填写赛事简介", text: $intro)
                                .accessibilityIdentifier("tournament_create_intro_input")
                        }

                        AppFormField(title: "赛事状态") {
                            Picker("赛事状态", selection: $status) {
                                ForEach(TournamentStatus.allCases, id: \.self) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("tournament_create_status_picker")
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) {
                                dismiss()
                            }

                            AppButton("创建赛事", variant: .primary) {
                                Task {
                                    await submit()
                                }
                            }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                            .opacity((name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting) ? 0.56 : 1)
                            .accessibilityIdentifier("tournament_create_submit")
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("创建赛事")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedIntro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSave(trimmedName, trimmedIntro, status)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
