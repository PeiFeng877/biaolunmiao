//
//  ProfileMoreView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: ProfileSettingsViewModel 的版本信息与协议弹层状态。
//  OUTPUT: 应用信息与协议隐私统一入口页面。
//  POS: 我的页-更多页面。
//

import SwiftUI

struct ProfileMoreView: View {
    @ObservedObject var viewModel: ProfileSettingsViewModel
    @State private var showSignOutConfirmation = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    moreListCard
                }
                .padding(.horizontal, AppSpacing.inset)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxl)
            }
            .accessibilityIdentifier("my_more_list")
        }
        .navigationTitle("更多")
        .navigationBarTitleDisplayMode(.inline)
        .appConfirmationDialog("退出登录", isPresented: $showSignOutConfirmation) {
            AppMenuAction("退出登录", role: .destructive) {
                viewModel.signOut()
            }
            AppMenuAction("取消", role: .cancel) {}
        } message: {
            Text("退出后将返回登录页，需要重新使用 Apple 登录。")
        }
        .appSheet(isPresented: $viewModel.showUserAgreementSheet) {
            MoreDocumentSheet(
                title: "用户协议",
                content: "使用本应用即代表你同意在队伍协作场景中共享必要的比赛与成员信息。\n\n请勿上传违法违规内容，管理员可对违规成员执行移除与封禁。",
                onClose: { viewModel.showUserAgreementSheet = false }
            )
        }
        .appSheet(isPresented: $viewModel.showPrivacyPolicySheet) {
            MoreDocumentSheet(
                title: "隐私政策",
                content: "当前版本已支持连接测试环境服务（默认指向阿里云 Staging），并在本地保留最小离线兜底。我们会持续明确告知数据收集范围、用途与保存策略。",
                onClose: { viewModel.showPrivacyPolicySheet = false }
            )
        }
    }

    private var moreListCard: some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                infoRow(title: "当前版本", trailing: viewModel.versionText, showsChevron: false)
                    .accessibilityIdentifier("my_more_row_version")

                Divider().overlay(AppColor.outline)

                AppRowTapButton {
                    viewModel.showUserAgreementSheet = true
                } label: {
                    infoRow(title: "用户协议", trailing: nil, showsChevron: true)
                }
                .accessibilityIdentifier("my_more_row_user_agreement")

                Divider().overlay(AppColor.outline)

                AppRowTapButton {
                    viewModel.showPrivacyPolicySheet = true
                } label: {
                    infoRow(title: "隐私政策", trailing: nil, showsChevron: true)
                }
                .accessibilityIdentifier("my_more_row_privacy_policy")

                Divider().overlay(AppColor.outline)

                AppRowTapButton {
                    showSignOutConfirmation = true
                } label: {
                    dangerRow(title: "退出登录")
                }
                .accessibilityIdentifier("my_more_row_sign_out")
            }
            .padding(.horizontal, AppSpacing.l)
        }
    }

    private func infoRow(title: String, trailing: String?, showsChevron: Bool) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let trailing {
                Text(trailing)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(AppFont.iconSmall())
                    .foregroundStyle(AppColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    private func dangerRow(title: String) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(AppColor.danger)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }
}

private struct MoreDocumentSheet: View {
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
    NavigationStack {
        ProfileMoreView(viewModel: ProfileSettingsViewModel(store: AppStore()))
    }
}
