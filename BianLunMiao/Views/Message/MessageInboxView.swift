//
//  MessageInboxView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/15.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: MessageInboxViewModel 提供的统一消息流与审批路由能力。
//  OUTPUT: 消息收件箱内容视图（扁平倒序卡片流）。
//  POS: 消息 Tab 内容区域。
//

import SwiftUI

struct MessageInboxView: View {
    @ObservedObject var viewModel: MessageInboxViewModel
    var onOpenJoinRequest: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                if viewModel.feedItems.isEmpty {
                    AppCard {
                        AppEmptyState(
                            title: "暂无消息",
                            subtitle: "新的消息会在这里出现",
                            systemImage: "bubble.left.and.bubble.right"
                        )
                    }
                } else {
                    ForEach(viewModel.feedItems) { item in
                        messageCard(item)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, AppSpacing.xxl)
        }
        .accessibilityIdentifier("message_feed_scroll")
    }

    @ViewBuilder
    private func messageCard(_ item: MessageFeedItem) -> some View {
        switch item {
        case .joinRequest(let request):
            AppRowTapButton {
                onOpenJoinRequest(request.id)
            } label: {
                AppCard {
                    JoinRequestCardContent(
                        title: rowTitle(for: request),
                        subtitle: rowSubtitle(for: request),
                        status: request.status,
                        timeText: formattedTime(request.reviewedAt ?? request.createdAt)
                    )
                }
            }
            .accessibilityIdentifier("message_card_join_request_\(request.id.uuidString)")

        case .system(let message):
            AppCard {
                SystemMessageCardContent(
                    title: message.title,
                    subtitle: message.subtitle,
                    timeText: formattedTime(message.createdAt),
                    isAcknowledged: message.isAcknowledged
                )
            }
            .accessibilityIdentifier("message_card_system_\(message.id.uuidString)")
        }
    }

    private func rowTitle(for request: TeamJoinRequest) -> String {
        switch request.status {
        case .pending:
            return "「\(request.applicantNickname)」申请加入 \(request.teamName)"
        case .approved:
            return "\(request.teamName) 已通过你的申请"
        case .rejected:
            return "\(request.teamName) 已拒绝你的申请"
        }
    }

    private func rowSubtitle(for request: TeamJoinRequest) -> String {
        switch request.status {
        case .pending:
            return "ID: \(request.teamPublicId) · 备注：\(request.personalNote)"
        case .approved, .rejected:
            let reviewer = request.reviewedByNickname ?? "管理员"
            return "\(reviewer) · \(formattedTime(request.reviewedAt ?? request.createdAt))"
        }
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct JoinRequestCardContent: View {
    let title: String
    let subtitle: String
    let status: TeamJoinRequestStatus
    let timeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(alignment: .top, spacing: AppSpacing.s) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: AppSpacing.s)

                AppTag(text: status.title, color: statusColor)
                    .padding(.top, 2)

                Image(systemName: "chevron.right")
                    .font(AppFont.iconSmall())
                    .foregroundStyle(AppColor.textMuted)
                    .padding(.top, 4)
            }

            Text(timeText)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textMuted)
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending:
            return AppColor.primaryStrong
        case .approved:
            return AppColor.infoBlue
        case .rejected:
            return AppColor.danger
        }
    }
}

private struct SystemMessageCardContent: View {
    let title: String
    let subtitle: String
    let timeText: String
    let isAcknowledged: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)

            Text(subtitle)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(2)

            HStack(spacing: AppSpacing.s) {
                Text(timeText)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textMuted)

                if isAcknowledged {
                    Text("已确认")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textMuted)
                }
            }
        }
    }
}

#Preview {
    let store = AppStore()
    MessageInboxView(
        viewModel: MessageInboxViewModel(store: store),
        onOpenJoinRequest: { _ in }
    )
}
