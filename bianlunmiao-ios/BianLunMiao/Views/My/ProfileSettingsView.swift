//
//  ProfileSettingsView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//  Updated by Codex on 2026/2/17.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: ProfileSettingsViewModel 提供的用户资料与完赛记录。
//  OUTPUT: 我的设置页面（资料卡、比赛时间轴与资料编辑入口）。
//  POS: 我的页-设置内容。
//

import SwiftUI
import PhotosUI
import UIKit

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
                currentNickname: viewModel.currentUser.nickname,
                canSave: viewModel.canSaveProfileDraft,
                onCancel: { viewModel.cancelEditProfile() },
                onSave: {
                    let success = viewModel.saveProfile()
                    if success {
                        toast = AppToastPayload(title: "资料已更新", intent: .success)
                    } else {
                        toast = AppToastPayload(title: "保存失败", message: "昵称不能为空", intent: .warning)
                    }
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
    let currentNickname: String
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppFormField(
                            title: "头像",
                            error: avatarErrorMessage
                        ) {
                            avatarUploader
                        }

                        AppFormField(title: "昵称") {
                            AppTextField(placeholder: "请输入昵称", text: $draftNickname)
                                .accessibilityIdentifier("profile_nickname_input")
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppButton("取消", variant: .toolbarText, action: onCancel)
                        .accessibilityIdentifier("profile_edit_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppButton("保存", variant: .toolbarText, action: onSave)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.56)
                        .accessibilityIdentifier("profile_edit_save_button")
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var avatarUploader: some View {
        HStack(spacing: AppSpacing.l) {
            avatarPreview

            PhotosPicker(
                selection: $avatarPickerItem,
                matching: .images
            ) {
                Label(draftAvatarData == nil ? "从相册上传头像" : "更换头像", systemImage: "photo.badge.plus")
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
        let trimmedDraft = draftNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmedDraft.isEmpty ? currentNickname : trimmedDraft
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
