//
//  ProfileSettingsView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//  Updated by Codex on 2026/3/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: ProfileSettingsViewModel 提供的用户资料与完赛记录。
//  OUTPUT: 我的设置页面（资料卡、比赛时间轴与资料编辑入口）。
//  POS: 我的页-设置内容。
//

import SwiftUI
import PhotosUI
import UIKit

struct NewUserProfileSetupView: View {
    @StateObject private var viewModel: ProfileSettingsViewModel
    @State private var toast: AppToastPayload?
    @State private var isSaving = false

    init(store: AppStore) {
        _viewModel = StateObject(wrappedValue: ProfileSettingsViewModel(store: store))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                centeredTitleBar

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppCard {
                            ProfileEditorFields(
                                draftNickname: $viewModel.nicknameDraft,
                                draftAvatarData: $viewModel.avatarDraftData
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomSubmitBar
        }
        .dismissKeyboardOnTap()
        .task {
            viewModel.prepareProfileDraft()
        }
        .appToast(item: $toast)
    }

    private var bottomSubmitBar: some View {
        VStack(spacing: 0) {
            AppButton("提交资料", variant: .primary) {
                Task {
                    await submit()
                }
            }
            .disabled(isSaving)
            .opacity(isSaving ? 0.56 : 1)
            .accessibilityIdentifier("new_user_profile_save_button")
            .padding(.horizontal, AppSpacing.inset)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.l)
        }
        .background(AppColor.background)
    }

    private func submit() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let success = try await viewModel.saveProfile(completesPostLoginSetup: true)
            guard success else {
                toast = AppToastPayload(
                    title: "资料未完成",
                    message: "昵称不能为空",
                    intent: .warning
                )
                return
            }
        } catch {
            toast = AppToastPayload(
                title: "保存失败",
                message: error.localizedDescription,
                intent: .error
            )
        }
    }

    private var centeredTitleBar: some View {
        HStack(spacing: AppSpacing.m) {
            Color.clear
                .frame(width: 40, height: 40)

            Spacer(minLength: AppSpacing.s)

            Text("完善资料")
                .font(AppFont.section())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.s)

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.vertical, AppSpacing.s)
    }
}

struct ProfileSettingsView: View {
    @ObservedObject var viewModel: ProfileSettingsViewModel
    @State private var toast: AppToastPayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                profileCard
                finishedMatchTimeline
            }
            .padding(.horizontal, AppSpacing.inset)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, AppSpacing.xxl)
        }
        .appSheet(isPresented: $viewModel.showEditProfileSheet) {
            ProfileEditSheet(
                draftNickname: $viewModel.nicknameDraft,
                draftAvatarData: $viewModel.avatarDraftData,
                canSave: viewModel.canSaveProfileDraft,
                onCancel: { viewModel.cancelEditProfile() },
                onSave: {
                    let success = try await viewModel.saveProfile()
                    guard success else {
                        toast = AppToastPayload(title: "保存失败", message: "昵称不能为空", intent: .warning)
                        return
                    }
                    toast = AppToastPayload(title: "资料已更新", intent: .success)
                }
            )
        }
        .appToast(item: $toast)
    }

    private var profileCard: some View {
        AppCard {
            HStack(spacing: AppSpacing.m) {
                avatarView

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentUser.nickname)
                        .font(AppFont.section())
                        .foregroundStyle(AppColor.textPrimary)

                    Text("ID: \(viewModel.currentUser.publicId)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                }

                Spacer()
            }
        }
    }

    private var finishedMatchTimeline: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("比赛记录")
                .font(AppFont.section())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textPrimary)

            if viewModel.finishedMatches.isEmpty {
                AppCard {
                    AppEmptyState(
                        title: "暂无已完成赛事",
                        subtitle: "完成比赛后将在这里展示赛果",
                        systemImage: "flag.checkered"
                    )
                }
            } else {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        ForEach(Array(viewModel.finishedMatches.enumerated()), id: \.element.id) { index, match in
                            MatchTimelineRow(
                                match: match,
                                tournamentName: viewModel.tournamentName(for: match),
                                teamsLine: viewModel.teamsLine(for: match),
                                winnerText: viewModel.winnerText(for: match),
                                scoreText: viewModel.scoreText(for: match),
                                isLast: index == viewModel.finishedMatches.count - 1
                            )
                        }
                    }
                }
                .accessibilityIdentifier("my_match_timeline")
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let remoteAvatarURL {
            AsyncImage(url: remoteAvatarURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(.circle)
                        .overlay(
                            Circle().stroke(AppColor.stroke, lineWidth: 1.5)
                        )
                } else {
                    fallbackAvatarView
                }
            }
        } else if let localAvatarImage {
            Image(uiImage: localAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(.circle)
                .overlay(
                    Circle().stroke(AppColor.stroke, lineWidth: 1.5)
                )
        } else {
            fallbackAvatarView
        }
    }

    private var fallbackAvatarView: some View {
        Circle()
            .fill(AppColor.primarySoft)
            .frame(width: 56, height: 56)
            .overlay(
                Text(initialText)
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)
            )
            .overlay(
                Circle().stroke(AppColor.stroke, lineWidth: 1.5)
            )
    }

    private var remoteAvatarURL: URL? {
        guard let avatarUrl = viewModel.currentUser.avatarUrl, !avatarUrl.isEmpty else { return nil }
        guard let url = URL(string: avatarUrl), let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    private var localAvatarImage: UIImage? {
        guard let avatarUrl = viewModel.currentUser.avatarUrl, !avatarUrl.isEmpty else { return nil }
        guard remoteAvatarURL == nil else { return nil }
        return UIImage(contentsOfFile: avatarUrl)
    }

    private var initialText: String {
        let first = String(viewModel.currentUser.nickname.prefix(1))
        return first.isEmpty ? "我" : first
    }
}

private struct MatchTimelineRow: View {
    let match: Match
    let tournamentName: String
    let teamsLine: String
    let winnerText: String
    let scoreText: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppColor.primaryStrong)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                if !isLast {
                    Rectangle()
                        .fill(AppColor.stroke.opacity(0.35))
                        .frame(width: 2, height: 72)
                        .padding(.top, 6)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(match.name)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textPrimary)

                Text(tournamentName)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)

                Text("对阵：\(teamsLine)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textPrimary)

                Text("胜方：\(winnerText)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)

                Text("比分：\(scoreText)")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)

                Text("开赛：\(match.startTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textMuted)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ProfileEditSheet: View {
    @Binding var draftNickname: String
    @Binding var draftAvatarData: Data?
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () async throws -> Void
    @State private var saveErrorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSheetHeader(
                    title: "编辑资料",
                    leadingAccessibilityId: "profile_edit_cancel_button",
                    trailingTitle: "保存",
                    trailingAccessibilityId: "profile_edit_save_button",
                    onLeadingAction: onCancel,
                    onTrailingAction: {
                        guard canSave && !isSaving else { return }
                        Task {
                            await submit()
                        }
                    }
                )
                .opacity((canSave && !isSaving) ? 1 : 0.56)

                ZStack {
                    AppBackground()

                    ScrollView {
                        ProfileEditorFields(
                            draftNickname: $draftNickname,
                            draftAvatarData: $draftAvatarData,
                            nicknameErrorMessage: $saveErrorMessage
                        )
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.top, AppSpacing.l)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .dismissKeyboardOnTap()
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }
    
    @MainActor
    private func submit() async {
        guard !isSaving else { return }
        isSaving = true
        saveErrorMessage = nil
        do {
            try await onSave()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

private struct ProfileEditorFields: View {
    @Binding var draftNickname: String
    @Binding var draftAvatarData: Data?
    @Binding var nicknameErrorMessage: String?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarErrorMessage: String?

    init(
        draftNickname: Binding<String>,
        draftAvatarData: Binding<Data?>,
        nicknameErrorMessage: Binding<String?> = .constant(nil)
    ) {
        self._draftNickname = draftNickname
        self._draftAvatarData = draftAvatarData
        self._nicknameErrorMessage = nicknameErrorMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            AppFormField(
                title: "头像",
                error: avatarErrorMessage
            ) {
                avatarUploader
            }

            AppFormField(title: "昵称", isRequired: true, error: nicknameErrorMessage) {
                AppTextField(placeholder: "请输入昵称", text: $draftNickname)
                    .accessibilityIdentifier("profile_nickname_input")
            }
        }
    }

    private var avatarUploader: some View {
        HStack(spacing: AppSpacing.l) {
            PhotosPicker(
                selection: $avatarPickerItem,
                matching: .images
            ) {
                avatarPreview
            }
            .buttonStyle(AppHapticPressStyle())
            .accessibilityIdentifier("profile_avatar_preview_button")

            PhotosPicker(
                selection: $avatarPickerItem,
                matching: .images
            ) {
                Label(draftAvatarData == nil ? "选择头像" : "更换头像", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .accessibilityIdentifier("profile_avatar_picker_button")
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
            if let draftAvatarData, let avatarImage = UIImage(data: draftAvatarData) {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(.circle)
                    .overlay(
                        Circle().stroke(AppColor.stroke, lineWidth: 1.5)
                    )
            } else {
                Circle()
                    .fill(AppColor.primarySoft)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Text(avatarInitialText)
                            .font(AppFont.section())
                            .foregroundStyle(AppColor.textPrimary)
                    )
                    .overlay(
                        Circle().stroke(AppColor.stroke, lineWidth: 1.5)
                    )
            }
        }
    }

    private var avatarInitialText: String {
        let source = draftNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = String(source.prefix(1))
        return initial.isEmpty ? "我" : initial
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
            draftAvatarData = normalizedData
            avatarErrorMessage = nil
        } catch {
            avatarErrorMessage = "图片读取失败，请重新选择。"
        }
    }
}

#Preview {
    ProfileSettingsView(viewModel: ProfileSettingsViewModel(store: AppStore()))
}
