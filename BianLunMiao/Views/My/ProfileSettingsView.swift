//
//  ProfileSettingsView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: ProfileSettingsViewModel 提供的用户资料与应用信息。
//  OUTPUT: 我的设置页面（资料编辑、版本信息、协议入口）。
//  POS: 我的页-设置分段内容。
//

import SwiftUI

struct ProfileSettingsView: View {
    @ObservedObject var viewModel: ProfileSettingsViewModel
    @State private var toast: AppToastPayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                AppSectionHeader("个人资料")
                profileCard

                AppSectionHeader("应用信息")
                appInfoCard

                AppSectionHeader("协议与隐私")
                policyCard
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, AppSpacing.xxl)
        }
        .appSheet(isPresented: $viewModel.showEditProfileSheet) {
            ProfileEditSheet(
                draftNickname: $viewModel.nicknameDraft,
                onCancel: { viewModel.showEditProfileSheet = false },
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
        .appSheet(isPresented: $viewModel.showUserAgreementSheet) {
            AppDocumentSheet(
                title: "用户协议",
                content: "使用本应用即代表你同意在队伍协作场景中共享必要的比赛与成员信息。\n\n请勿上传违法违规内容，管理员可对违规成员执行移除与封禁。",
                onClose: { viewModel.showUserAgreementSheet = false }
            )
        }
        .appSheet(isPresented: $viewModel.showPrivacyPolicySheet) {
            AppDocumentSheet(
                title: "隐私政策",
                content: "当前版本仅在本地 Mock 数据环境运行。后续接入网络服务时，将明确告知数据收集范围、用途与保存策略。",
                onClose: { viewModel.showPrivacyPolicySheet = false }
            )
        }
        .appToast(item: $toast)
    }

    private var profileCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(spacing: AppSpacing.m) {
                    Circle()
                        .fill(AppColor.primarySoft)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(initialText)
                                .font(AppFont.section())
                                .foregroundStyle(AppColor.textPrimary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentUser.nickname)
                            .font(AppFont.section())
                            .foregroundStyle(AppColor.textPrimary)
                        Text("ID: \(viewModel.currentUser.publicId)")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    Spacer()
                }

                AppButton("编辑资料", variant: .secondary) {
                    viewModel.beginEditProfile()
                }
            }
        }
    }

    private var appInfoCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                infoRow(title: "当前版本", value: viewModel.versionText)
                infoRow(title: "应用名称", value: "辩论喵")
            }
        }
    }

    private var policyCard: some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                AppRowTapButton {
                    viewModel.showUserAgreementSheet = true
                } label: {
                    policyRow(title: "用户协议")
                }

                Divider().overlay(AppColor.outline)

                AppRowTapButton {
                    viewModel.showPrivacyPolicySheet = true
                } label: {
                    policyRow(title: "隐私政策")
                }
            }
            .padding(.horizontal, AppSpacing.l)
        }
    }

    private var initialText: String {
        String(viewModel.currentUser.nickname.prefix(1))
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary)

            Spacer()

            Text(value)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    private func policyRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppFont.iconSmall())
                .foregroundStyle(AppColor.textMuted)
        }
        .padding(.vertical, AppSpacing.m)
    }
}

private struct ProfileEditSheet: View {
    @Binding var draftNickname: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    AppSectionHeader("编辑资料")

                    AppFormField(title: "昵称") {
                        AppTextField(placeholder: "请输入昵称", text: $draftNickname)
                            .accessibilityIdentifier("profile_nickname_input")
                    }

                    HStack(spacing: AppSpacing.s) {
                        AppButton("取消", variant: .ghost, action: onCancel)
                        AppButton("保存", variant: .primary, action: onSave)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

private struct AppDocumentSheet: View {
    let title: String
    let content: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    AppCard {
                        Text(content)
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AppButton("关闭", variant: .secondary, action: onClose)
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}

#Preview {
    ProfileSettingsView(viewModel: ProfileSettingsViewModel(store: AppStore()))
}
