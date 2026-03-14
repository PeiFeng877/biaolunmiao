//
//  ProfileMoreView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/6.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: ProfileSettingsViewModel 的版本信息、正式协议链接与备案信息。
//  OUTPUT: 应用信息、协议隐私与底部备案信息统一入口页面。
//  POS: 我的页-更多页面。
//

import SwiftUI

struct ProfileMoreView: View {
    @ObservedObject var viewModel: ProfileSettingsViewModel
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountFinalAlert = false
    @State private var toast: AppToastPayload?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    moreListCard
#if DEBUG
                    debugToolsCard
#endif
                }
                .padding(.horizontal, AppSpacing.inset)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
            .accessibilityIdentifier("my_more_list")
        }
        .navigationTitle("更多")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            filingFooter
        }
        .appConfirmationDialog("退出登录", isPresented: $showSignOutConfirmation) {
            AppMenuAction("退出登录", role: .destructive) {
                viewModel.signOut()
            }
            AppMenuAction("取消", role: .cancel) {}
        } message: {
            Text("退出后将返回登录页，需要重新使用 Apple 登录。")
        }
        .appConfirmationDialog("要删除账号吗？", isPresented: $showDeleteAccountConfirmation) {
            AppMenuAction("继续删除", role: .destructive) {
                showDeleteAccountFinalAlert = true
            }
            AppMenuAction("取消", role: .cancel) {}
        } message: {
            Text("删除后，你将退出登录，并且无法使用这个账号。")
        }
        .appAlert("请再次确认", isPresented: $showDeleteAccountFinalAlert) {
            AppMenuAction("删除账号", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            AppMenuAction("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，确认是否继续？")
        }
        .appToast(item: $toast)
    }

    private var moreListCard: some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                infoRow(title: "当前版本", trailing: viewModel.versionText, showsChevron: false)
                    .accessibilityIdentifier("my_more_row_version")

                Divider().overlay(AppColor.outline)

                Link(destination: viewModel.userAgreementURL) {
                    infoRow(title: "用户协议", trailing: nil, showsChevron: true)
                }
                .buttonStyle(AppRowTapButtonStyle())
                .accessibilityIdentifier("my_more_row_user_agreement")

                Divider().overlay(AppColor.outline)

                Link(destination: viewModel.privacyPolicyURL) {
                    infoRow(title: "隐私政策", trailing: nil, showsChevron: true)
                }
                .buttonStyle(AppRowTapButtonStyle())
                .accessibilityIdentifier("my_more_row_privacy_policy")

                Divider().overlay(AppColor.outline)

                AppRowTapButton {
                    showSignOutConfirmation = true
                } label: {
                    dangerRow(title: "退出登录")
                }
                .accessibilityIdentifier("my_more_row_sign_out")

                Divider().overlay(AppColor.outline)

                AppRowTapButton {
                    showDeleteAccountConfirmation = true
                } label: {
                    dangerRow(
                        title: viewModel.isDeletingAccount ? "正在删除..." : "删除账号",
                        showsProgress: viewModel.isDeletingAccount
                    )
                }
                .disabled(viewModel.isDeletingAccount)
                .accessibilityIdentifier("my_more_row_delete_account")
            }
            .padding(.horizontal, AppSpacing.l)
        }
    }

    private var filingFooter: some View {
        VStack(spacing: 0) {
            Text("备案号：\(viewModel.filingNumber)")
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textMuted)
                .accessibilityIdentifier("my_more_filing_number")
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.s)
                .padding(.bottom, AppSpacing.m)
        }
        .background(AppColor.background)
    }

#if DEBUG
    private var debugToolsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("调试")
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)

                Toggle(isOn: forceNewUserFlowBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("下次登录强制走新用户资料流")
                            .font(AppFont.body())
                            .foregroundStyle(AppColor.textPrimary)

                        Text("打开后，退出并重新登录当前账号，也会先进入头像与昵称设置页。")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(AppColor.primaryStrong)
                .accessibilityIdentifier("my_more_force_new_user_flow_toggle")
            }
        }
    }

    private var forceNewUserFlowBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isForceNewUserFlowEnabled },
            set: { viewModel.setForceNewUserFlowEnabled($0) }
        )
    }
#endif

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

    private func dangerRow(title: String, showsProgress: Bool = false) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(AppColor.danger)
                .lineLimit(1)

            Spacer(minLength: 0)

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColor.danger)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    @MainActor
    private func deleteAccount() async {
        do {
            try await viewModel.deleteAccount()
        } catch {
            toast = AppToastPayload(
                title: "删除失败",
                message: error.localizedDescription,
                intent: .error,
                accessibilityIdentifier: "my_more_delete_account_error_toast"
            )
        }
    }
}

#Preview {
    NavigationStack {
        ProfileMoreView(viewModel: ProfileSettingsViewModel(store: AppStore()))
    }
}
