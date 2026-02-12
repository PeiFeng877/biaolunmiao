//
//  CreateTournamentView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 赛事表单数据与保存回调。
//  OUTPUT: 赛事创建弹窗。
//  POS: 赛事管理流程。
//

import SwiftUI

struct CreateTournamentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var intro: String = ""

    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(title: "赛事名称") {
                            AppTextField(placeholder: "输入赛事名称", text: $name)
                                .accessibilityIdentifier("tournament_create_name_input")
                        }

                        AppFormField(title: "赛事简介") {
                            AppTextEditor(placeholder: "填写赛事简介", text: $intro)
                                .accessibilityIdentifier("tournament_create_intro_input")
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) {
                                dismiss()
                            }

                            AppButton("创建赛事", variant: .primary) {
                                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                                let trimmedIntro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
                                onSave(trimmedName, trimmedIntro)
                                dismiss()
                            }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.56 : 1)
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
}
