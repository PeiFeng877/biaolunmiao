//
//  CreateTeamSheet.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 队伍表单数据与保存回调。
//  OUTPUT: 统一风格的队伍创建/编辑弹窗。
//  POS: 队伍管理流程。
//

import SwiftUI

struct TeamProfileInput {
    let name: String
    let slogan: String
    let about: String
    let avatarStyle: TeamAvatarStyle
}

struct CreateTeamSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var slogan: String
    @State private var about: String
    @State private var avatarStyle: TeamAvatarStyle?

    var isEditing: Bool = false
    var onSave: (TeamProfileInput) -> Void

    init(team: Team? = nil, onSave: @escaping (TeamProfileInput) -> Void) {
        _name = State(initialValue: team?.name ?? "")
        _slogan = State(initialValue: team?.slogan ?? "")
        _about = State(initialValue: team?.about ?? "")
        _avatarStyle = State(initialValue: team?.avatarStyle)
        self.isEditing = team != nil
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(
                            title: "队伍头像",
                            helper: "必填",
                            error: avatarStyle == nil ? "请选择队伍头像" : nil
                        ) {
                            AppAvatarPicker(selection: $avatarStyle)
                        }

                        AppSectionHeader("基本信息")

                        AppFormField(
                            title: "队伍名称",
                            helper: "最多 30 字",
                            counter: AppFormFieldCounter(current: name.count, limit: 30)
                        ) {
                            AppTextField(placeholder: "例如：辩论喵战队", text: $name)
                        }
                        .onChange(of: name) { _, newValue in
                            name = enforceLimit(for: newValue, limit: 30)
                        }

                        AppFormField(
                            title: "队伍 Slogan",
                            helper: "一句话介绍，最多 50 字",
                            counter: AppFormFieldCounter(current: slogan.count, limit: 50)
                        ) {
                            AppTextField(placeholder: "例如：友谊第一，比赛第二", text: $slogan)
                        }
                        .onChange(of: slogan) { _, newValue in
                            slogan = enforceLimit(for: newValue, limit: 50)
                        }

                        AppFormField(
                            title: "队伍简介",
                            helper: "最多 200 字",
                            counter: AppFormFieldCounter(current: about.count, limit: 200)
                        ) {
                            AppTextEditor(placeholder: "介绍队伍风格、优势、成立背景…", text: $about)
                        }
                        .onChange(of: about) { _, newValue in
                            about = enforceLimit(for: newValue, limit: 200)
                        }

                        Button(isEditing ? "保存修改" : "立即创建") {
                            guard let avatarStyle else { return }
                            onSave(
                                TeamProfileInput(
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    slogan: slogan.trimmingCharacters(in: .whitespacesAndNewlines),
                                    about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                                    avatarStyle: avatarStyle
                                )
                            )
                            dismiss()
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(!isFormValid)
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
        }
    }

    private var isFormValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlogan = slogan.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAbout = about.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmedName.isEmpty
            && trimmedName.count <= 30
            && trimmedSlogan.count <= 50
            && trimmedAbout.count <= 200
            && avatarStyle != nil
    }

    private func enforceLimit(for value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }
}

#Preview {
    CreateTeamSheet { _ in }
}
