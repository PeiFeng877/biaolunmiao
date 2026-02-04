//
//  CreateTournamentView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 赛事表单数据与保存回调。
//  OUTPUT: 统一风格的赛事创建弹窗。
//  POS: 赛事管理流程。
//

import SwiftUI

struct CreateTournamentView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var intro: String = ""
    @State private var showScheduleSetup = false

    var onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        VStack(spacing: AppSpacing.m) {
                            AppTextField(title: "赛事名称", text: $name)
                            AppTextEditor(title: "赛事简介", text: $intro)
                        }
                        .padding(AppSpacing.l)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                                .stroke(AppColor.outline, lineWidth: 1)
                        )
                        .cornerRadius(AppRadius.l)

                        Button("下一步：赛程设定") {
                            onSave(name, intro)
                            showScheduleSetup = true
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(name.isEmpty)
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("发起赛事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .navigationDestination(isPresented: $showScheduleSetup) {
                TournamentScheduleSetupView(tournamentName: name)
            }
        }
    }
}
