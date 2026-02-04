//
//  CreateTeamSheet.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 队伍表单数据与保存回调。
//  OUTPUT: 统一风格的队伍创建/编辑弹窗。
//  POS: 队伍管理流程。
//

import SwiftUI

struct CreateTeamSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var intro: String
    @State private var generatedId: String

    var isEditing: Bool = false
    var onSave: (String, String) -> Void

    init(team: Team? = nil, onSave: @escaping (String, String) -> Void) {
        _name = State(initialValue: team?.name ?? "")
        _intro = State(initialValue: team?.intro ?? "")
        _generatedId = State(initialValue: team?.publicId ?? "8888")
        self.isEditing = team != nil
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColor.primary.opacity(0.12))
                                        .frame(width: 84, height: 84)
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(AppColor.primary)
                                }
                                Text("上传队徽")
                                    .font(AppFont.caption())
                                    .foregroundColor(AppColor.primary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.s)

                        Text("基本信息")
                            .font(AppFont.section())
                            .foregroundColor(AppColor.textPrimary)

                        VStack(spacing: AppSpacing.m) {
                            AppTextField(title: "队伍名称", text: $name)

                            HStack {
                                Text("队伍 ID")
                                    .font(AppFont.body())
                                    .foregroundColor(AppColor.textSecondary)
                                Spacer()
                                Text(generatedId)
                                    .font(AppFont.body())
                                    .foregroundColor(AppColor.textMuted)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 6)
                        }
                        .padding(AppSpacing.l)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                                .stroke(AppColor.outline, lineWidth: 1)
                        )
                        .cornerRadius(AppRadius.l)

                        Text("简介")
                            .font(AppFont.section())
                            .foregroundColor(AppColor.textPrimary)

                        AppTextEditor(title: "一句话介绍你的队伍", text: $intro)

                        Button(isEditing ? "保存修改" : "创建队伍") {
                            onSave(name, intro)
                            dismiss()
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(name.isEmpty)
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle(isEditing ? "编辑队伍" : "创建队伍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .onAppear {
                if !isEditing {
                    generatedId = String(Int.random(in: 1000...9999))
                }
            }
        }
    }
}

#Preview {
    CreateTeamSheet { _, _ in }
}
