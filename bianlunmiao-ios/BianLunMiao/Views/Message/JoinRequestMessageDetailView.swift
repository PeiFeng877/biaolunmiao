//
//  JoinRequestMessageDetailView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 单条 TeamJoinRequest 与审批操作能力。
//  OUTPUT: 消息详情页（待审批操作或已处理结果）。
//  POS: 消息列表二级页面。
//

import SwiftUI

struct JoinRequestMessageDetailView: View {
    @ObservedObject var viewModel: MessageInboxViewModel
    let requestId: UUID

    @State private var toast: AppToastPayload?

    var body: some View {
        ZStack {
            AppBackground()
            accessibilityMarker("message_detail_root")

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
        .appToast(item: $toast)
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
            AppButton("拒绝", variant: .ghost) {
                applyDecision(requestId: request.id, decision: .reject)
            }

            AppButton("通过", variant: .primary) {
                applyDecision(requestId: request.id, decision: .approve)
            }
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
        Task {
            do {
                let request: TeamJoinRequest
                switch decision {
                case .approve:
                    request = try await viewModel.approve(requestId: requestId)
                case .reject:
                    request = try await viewModel.reject(requestId: requestId)
                }

                toast = AppToastPayload(
                    title: "处理成功",
                    message: "申请\(request.status.title)",
                    intent: .success
                )
            } catch {
                toast = AppToastPayload(
                    title: "处理失败",
                    message: error.localizedDescription,
                    intent: .error
                )
            }
        }
    }

    private func accessibilityMarker(_ id: String) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(id)
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
