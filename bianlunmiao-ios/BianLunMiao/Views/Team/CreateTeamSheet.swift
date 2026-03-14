//
//  CreateTeamSheet.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 队伍表单数据、头像上传与保存回调。
//  OUTPUT: 统一风格的队伍创建/编辑弹窗（支持相册上传队徽）。
//  POS: 队伍管理流程。
//

import PhotosUI
import SwiftUI
import UIKit

struct TeamProfileInput: Sendable {
    let name: String
    let slogan: String
    let avatarImageData: Data?

    static func normalized(
        name: String,
        slogan: String,
        avatarImageData: Data?
    ) -> TeamProfileInput {
        TeamProfileInput(
            name: normalizedFieldValue(name),
            slogan: normalizedFieldValue(slogan),
            avatarImageData: avatarImageData
        )
    }

    var createPayload: TeamCreatePayload {
        TeamCreatePayload(
            name: name,
            slogan: slogan.isEmpty ? nil : slogan,
            avatarImageData: avatarImageData
        )
    }

    func updatePayload(id: UUID) -> TeamUpdatePayload {
        TeamUpdatePayload(
            id: id,
            name: name,
            slogan: slogan.isEmpty ? nil : slogan,
            avatarImageData: avatarImageData
        )
    }

    private static func normalizedFieldValue(_ value: String) -> String {
        guard let start = value.firstIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        guard let end = value.lastIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        return String(value[start...end])
    }
}

struct CreateTeamSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var slogan: String
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var previewAvatarData: Data?
    @State private var newAvatarData: Data?
    @State private var avatarErrorMessage: String?
    @State private var submitErrorMessage: String?
    @State private var isSubmitting = false
    @State private var showDangerActionConfirm = false

    private let fallbackAvatarStyle: TeamAvatarStyle
    private let existingAvatarURL: URL?

    var isEditing: Bool = false
    var dangerActionTitle: String?
    var onDangerAction: (() -> Void)?
    let onSave: @MainActor @Sendable (TeamProfileInput) async throws -> Void

    private var shouldTraceSubmit: Bool {
#if DEBUG
        return true
#else
        let env = ProcessInfo.processInfo.environment
        return env["BLM_UI_TEST_MODE"] == "1" || env["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] == "1"
#endif
    }

    init(
        team: Team? = nil,
        dangerActionTitle: String? = nil,
        onDangerAction: (() -> Void)? = nil,
        onSave: @escaping @MainActor @Sendable (TeamProfileInput) async throws -> Void
    ) {
        let existingAvatarInfo: (data: Data?, remoteURL: URL?) = {
            guard let avatarUrl = team?.avatarUrl, !avatarUrl.isEmpty else {
                return (nil, nil)
            }
            if
                let url = URL(string: avatarUrl),
                let scheme = url.scheme?.lowercased(),
                (scheme == "http" || scheme == "https")
            {
                return (nil, url)
            }
            return (try? Data(contentsOf: URL(fileURLWithPath: avatarUrl)), nil)
        }()
        let initialName = Self.prefilledFieldValue(
            editingValue: team?.name,
            createEnvKey: "BLM_UI_TEST_TEAM_NAME"
        )
        let initialSlogan = Self.prefilledFieldValue(
            editingValue: team?.slogan,
            createEnvKey: "BLM_UI_TEST_TEAM_SLOGAN"
        )

        _name = State(initialValue: initialName)
        _slogan = State(initialValue: initialSlogan)
        _previewAvatarData = State(initialValue: existingAvatarInfo.data)
        _newAvatarData = State(initialValue: nil)
        self.fallbackAvatarStyle = team?.avatarStyle ?? .paw
        self.existingAvatarURL = existingAvatarInfo.remoteURL
        self.isEditing = team != nil
        self.dangerActionTitle = dangerActionTitle
        self.onDangerAction = onDangerAction
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

                        AppFormField(title: "队伍名称", error: submitErrorMessage) {
                            AppTextField(placeholder: "队伍名（最多 30 字）", text: $name)
                                .accessibilityIdentifier("team_create_name_input")
                        }
                        .onChange(of: name) { _, newValue in
                            name = enforceLimit(for: newValue, limit: 30)
                        }

                        AppFormField(title: "队伍 Slogan") {
                            AppTextField(placeholder: "一句话介绍（最多 50 字）", text: $slogan)
                                .accessibilityIdentifier("team_create_slogan_input")
                        }
                        .onChange(of: slogan) { _, newValue in
                            slogan = enforceLimit(for: newValue, limit: 50)
                        }

                        HStack(spacing: AppSpacing.s) {
                            AppButton("取消", variant: .ghost) { dismiss() }

                            AppButton(submitButtonTitle, variant: .primary) {
                                traceSubmit("button tapped")
                                Task { @MainActor in
                                    await submit()
                                }
                            }
                            .accessibilityIdentifier("team_create_submit_button")
                            .disabled(!isFormValid || isSubmitting)
                            .opacity((isFormValid && !isSubmitting) ? 1 : 0.56)
                        }

                        if isSubmitting {
                            HStack(spacing: AppSpacing.s) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(isEditing ? "正在保存队伍资料..." : "正在创建队伍...")
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }

                        if isEditing, let dangerActionTitle {
                            AppButton(dangerActionTitle, variant: .secondary, role: .destructive) {
                                showDangerActionConfirm = true
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle(isEditing ? "编辑队伍" : "创建队伍")
            .navigationBarTitleDisplayMode(.inline)
            .appConfirmationDialog(
                "确认\(dangerActionTitle ?? "执行该操作")？",
                isPresented: $showDangerActionConfirm
            ) {
                if let dangerActionTitle, let onDangerAction {
                    AppMenuAction(dangerActionTitle, role: .destructive) {
                        onDangerAction()
                        dismiss()
                    }
                }
                AppMenuAction("取消", role: .cancel) {}
            } message: {
                Text("该操作不可撤销。")
            }
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
            } else if let existingAvatarURL {
                AsyncImage(url: existingAvatarURL) { phase in
                    if let image = phase.image {
                        image
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
            } else {
                TeamAvatarBadge(style: fallbackAvatarStyle, size: 88)
            }
        }
    }

    private var isFormValid: Bool {
        let snapshot = TeamProfileInput.normalized(
            name: name,
            slogan: slogan,
            avatarImageData: nil
        )

        return !snapshot.name.isEmpty
            && snapshot.name.count <= 30
            && snapshot.slogan.count <= 50
    }

    private var submitButtonTitle: String {
        if isSubmitting {
            return isEditing ? "保存中..." : "创建中..."
        }
        return isEditing ? "保存修改" : "立即创建"
    }

    private func enforceLimit(for value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        let snapshot = TeamProfileInput.normalized(
            name: name,
            slogan: slogan,
            avatarImageData: newAvatarData
        )
        traceSubmit("submit start actor=main")
        traceSubmit("payload prepared nameLength=\(snapshot.name.count) sloganLength=\(snapshot.slogan.count)")
        isSubmitting = true
        submitErrorMessage = nil
        do {
            traceSubmit("before onSave await")
            try await onSave(snapshot)
            traceSubmit("submit success actor=main")
            dismiss()
        } catch {
            traceSubmit("submit failed error=\(error.localizedDescription)")
            submitErrorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func traceSubmit(_ message: String) {
        guard shouldTraceSubmit else { return }
        print("[CreateTeamSheet] \(message)")
    }

    private static func prefilledFieldValue(editingValue: String?, createEnvKey: String) -> String {
        if let editingValue {
            return editingValue
        }

        let env = ProcessInfo.processInfo.environment
        guard env["BLM_UI_TEST_MODE"] == "1" else {
            return ""
        }

        return env[createEnvKey] ?? ""
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
