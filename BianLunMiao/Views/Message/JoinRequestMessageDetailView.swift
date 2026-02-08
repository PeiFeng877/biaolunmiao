//
//  JoinRequestMessageDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 单条 TeamJoinRequest 与审批操作能力。
//  OUTPUT: 消息详情页（待审批操作或已处理结果）。
//  POS: 消息列表二级页面。
//

import SwiftUI

struct JoinRequestMessageDetailView: View {
    @ObservedObject var viewModel: MessageInboxViewModel
    let requestId: UUID

    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                if let request = viewModel.request(id: requestId) {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        headerCard(request: request)
                        detailCard(request: request)

                        if viewModel.canReview(request) {
                            actionBar(request: request)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                } else {
                    VStack(spacing: AppSpacing.l) {
                        AppEmptyState(
                            title: "消息不存在",
                            subtitle: "该条消息可能已被移除",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.xl)
                }
            }
        }
        .navigationTitle("消息详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("处理结果", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func headerCard(request: TeamJoinRequest) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(request.teamName)
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.s) {
                    Text("ID: \(request.teamPublicId)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textMuted)
                        .monospacedDigit()

                    AppTag(text: request.status.title, color: statusColor(request.status))
                }
            }
        }
    }

    private func detailCard(request: TeamJoinRequest) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                detailRow(title: "申请人", value: request.applicantNickname)
                detailRow(title: "申请人 ID", value: request.applicantPublicId)
                detailRow(title: "个人备注", value: request.personalNote)
                detailRow(
                    title: "申请理由",
                    value: request.reason.isEmpty ? "未填写" : request.reason
                )
                detailRow(
                    title: "提交时间",
                    value: request.createdAt.formatted(date: .abbreviated, time: .shortened)
                )

                if request.status != .pending {
                    detailRow(
                        title: "处理人",
                        value: request.reviewedByNickname ?? "管理员"
                    )
                    detailRow(
                        title: "处理时间",
                        value: (request.reviewedAt ?? request.createdAt)
                            .formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
    }

    private func actionBar(request: TeamJoinRequest) -> some View {
        HStack(spacing: AppSpacing.s) {
            Button("拒绝") {
                applyDecision(requestId: request.id, decision: .reject)
            }
            .buttonStyle(AppGhostButtonStyle())

            Button("通过") {
                applyDecision(requestId: request.id, decision: .approve)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusColor(_ status: TeamJoinRequestStatus) -> Color {
        switch status {
        case .pending:
            return AppColor.primaryStrong
        case .approved:
            return AppColor.infoBlue
        case .rejected:
            return AppColor.danger
        }
    }

    private func applyDecision(requestId: UUID, decision: TeamJoinRequestDecision) {
        let result: TeamJoinRequestReviewResult
        switch decision {
        case .approve:
            result = viewModel.approve(requestId: requestId)
        case .reject:
            result = viewModel.reject(requestId: requestId)
        }

        switch result {
        case .success(let request):
            alertMessage = "申请\(request.status.title)"
            showAlert = true
        case .failure(let error):
            alertMessage = error.rawValue
            showAlert = true
        }
    }
}

#Preview {
    let store = AppStore()
    NavigationStack {
        if let request = store.teamJoinRequests.first {
            JoinRequestMessageDetailView(
                viewModel: MessageInboxViewModel(store: store),
                requestId: request.id
            )
        }
    }
}
