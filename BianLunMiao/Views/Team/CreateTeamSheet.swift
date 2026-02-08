//
//  CreateTeamSheet.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/7.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 队伍表单数据、头像上传与保存回调。
//  OUTPUT: 统一风格的队伍创建/编辑弹窗（支持相册上传队徽）。
//  POS: 队伍管理流程。
//

import PhotosUI
import SwiftUI
import UIKit

struct TeamProfileInput {
    let name: String
    let slogan: String
    let about: String
    let avatarImageData: Data?
}

struct CreateTeamSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var slogan: String
    @State private var about: String
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var previewAvatarData: Data?
    @State private var newAvatarData: Data?
    @State private var avatarErrorMessage: String?

    private let fallbackAvatarStyle: TeamAvatarStyle

    var isEditing: Bool = false
    var onSave: (TeamProfileInput) -> Void

    init(team: Team? = nil, onSave: @escaping (TeamProfileInput) -> Void) {
        let existingAvatarData: Data? = {
            guard let avatarUrl = team?.avatarUrl, !avatarUrl.isEmpty else { return nil }
            return try? Data(contentsOf: URL(fileURLWithPath: avatarUrl))
        }()
        _name = State(initialValue: team?.name ?? "")
        _slogan = State(initialValue: team?.slogan ?? "")
        _about = State(initialValue: team?.about ?? "")
        _previewAvatarData = State(initialValue: existingAvatarData)
        _newAvatarData = State(initialValue: nil)
        self.fallbackAvatarStyle = team?.avatarStyle ?? .paw
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
                            helper: "可选上传，推荐使用方形 Logo",
                            error: avatarErrorMessage
                        ) {
                            avatarUploader
                        }

                        AppSectionHeader("基本信息")

                        AppFormField(title: "队伍名称") {
                            AppTextField(placeholder: "队伍名（最多 30 字）", text: $name)
                        }
                        .onChange(of: name) { _, newValue in
                            name = enforceLimit(for: newValue, limit: 30)
                        }

                        AppFormField(title: "队伍 Slogan") {
                            AppTextField(placeholder: "一句话介绍（最多 50 字）", text: $slogan)
                        }
                        .onChange(of: slogan) { _, newValue in
                            slogan = enforceLimit(for: newValue, limit: 50)
                        }

                        AppFormField(title: "队伍简介") {
                            AppTextEditor(placeholder: "队伍简介（最多 200 字）", text: $about)
                        }
                        .onChange(of: about) { _, newValue in
                            about = enforceLimit(for: newValue, limit: 200)
                        }

                        HStack(spacing: AppSpacing.s) {
                            Button("取消") { dismiss() }
                                .buttonStyle(AppGhostButtonStyle())

                            Button(isEditing ? "保存修改" : "立即创建") {
                                onSave(
                                    TeamProfileInput(
                                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                        slogan: slogan.trimmingCharacters(in: .whitespacesAndNewlines),
                                        about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                                        avatarImageData: newAvatarData
                                    )
                                )
                                dismiss()
                            }
                            .buttonStyle(AppPrimaryButtonStyle())
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1 : 0.56)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle(isEditing ? "编辑队伍" : "创建队伍")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var avatarUploader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(spacing: AppSpacing.l) {
                avatarPreview

                PhotosPicker(
                    selection: $avatarPickerItem,
                    matching: .images
                ) {
                    Label(previewAvatarData == nil ? "从相册上传队徽" : "更换队徽", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
        .onChange(of: avatarPickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadAvatarImage(from: newValue)
            }
        }
    }

    private var avatarPreview: some View {
        Group {
            if let previewAvatarData, let avatarImage = UIImage(data: previewAvatarData) {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(.circle)
                    .overlay(
                        Circle().stroke(AppColor.stroke, lineWidth: 1.5)
                    )
            } else {
                TeamAvatarBadge(style: fallbackAvatarStyle, size: 88)
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
    }

    private func enforceLimit(for value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    @MainActor
    private func loadAvatarImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                avatarErrorMessage = "图片读取失败，请重新选择。"
                return
            }
            guard let image = UIImage(data: data) else {
                avatarErrorMessage = "图片格式不支持，请更换图片。"
                return
            }

            let normalizedData = image.jpegData(compressionQuality: 0.86) ?? data
            previewAvatarData = normalizedData
            newAvatarData = normalizedData
            avatarErrorMessage = nil
        } catch {
            avatarErrorMessage = "图片读取失败，请重新选择。"
        }
    }
}

#Preview {
    CreateTeamSheet { _ in }
}
