//
//  MessageInboxView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: MessageInboxViewModel 提供的申请、通知与状态变更消息。
//  OUTPUT: 消息收件箱内容视图（分段展示 + 审批/确认动作）。
//  POS: 我的页-消息内容区域。
//

import SwiftUI

struct MessageInboxView: View {
    @ObservedObject var viewModel: MessageInboxViewModel
    var onOpenJoinRequest: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                Picker("消息类型", selection: $viewModel.selectedSection) {
                    ForEach(InboxSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                switch viewModel.selectedSection {
                case .application:
                    applicationSection
                case .notification:
                    systemSection(
                        title: "通知",
                        subtitle: "共 \(viewModel.notifications.count) 条",
                        items: viewModel.notifications
                    )
                case .statusChange:
                    systemSection(
                        title: "状态变更",
                        subtitle: "共 \(viewModel.statusChanges.count) 条",
                        items: viewModel.statusChanges
                    )
                }
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            AppSectionHeader("待处理申请", trailing: "共 \(viewModel.incoming.count) 条")

            if viewModel.incoming.isEmpty {
                AppCard {
                    AppEmptyState(
                        title: "没有待处理申请",
                        subtitle: "新的入队申请会在这里出现",
                        systemImage: "tray"
                    )
                }
            } else {
                joinRequestList(viewModel.incoming)
            }

            AppSectionHeader("申请结果", trailing: "共 \(viewModel.outgoing.count) 条")

            if viewModel.outgoing.isEmpty {
                AppCard {
                    AppEmptyState(
                        title: "没有结果通知",
                        subtitle: "你的申请通过或拒绝后会在这里显示",
                        systemImage: "bell"
                    )
                }
            } else {
                joinRequestList(viewModel.outgoing)
            }
        }
    }

    private func joinRequestList(_ requests: [TeamJoinRequest]) -> some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(requests) { request in
                    AppRowTapButton {
                        onOpenJoinRequest(request.id)
                    } label: {
                        JoinRequestMessageRow(
                            title: rowTitle(for: request),
                            subtitle: rowSubtitle(for: request),
                            status: request.status
                        )
                    }

                    if request.id != requests.last?.id {
                        Divider().overlay(AppColor.outline)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
        }
    }

    private func systemSection(title: String, subtitle: String, items: [InboxMessage]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title, trailing: subtitle)

            if items.isEmpty {
                AppCard {
                    AppEmptyState(
                        title: "暂无消息",
                        subtitle: "新的消息会在这里出现",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
            } else {
                AppCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(items) { message in
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                Text(message.title)
                                    .font(AppFont.body())
                                    .foregroundStyle(AppColor.textPrimary)
                                    .lineLimit(2)

                                Text(message.subtitle)
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppColor.textSecondary)
                                    .lineLimit(2)

                                HStack(alignment: .center) {
                                    Text(formattedTime(message.createdAt))
                                        .font(AppFont.caption())
                                        .foregroundStyle(AppColor.textMuted)

                                    Spacer()

                                    if message.isAcknowledged {
                                        AppTag(text: "已确认", color: AppColor.infoBlue)
                                    } else {
                                        AppButton("消息确认", variant: .toolbarText) {
                                            viewModel.acknowledgeMessage(id: message.id)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, AppSpacing.m)

                            if message.id != items.last?.id {
                                Divider().overlay(AppColor.outline)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                }
            }
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

private struct JoinRequestMessageRow: View {
    let title: String
    let subtitle: String
    let status: TeamJoinRequestStatus

    var body: some View {
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
        .padding(.vertical, AppSpacing.m)
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

#Preview {
    let store = AppStore()
    MessageInboxView(
        viewModel: MessageInboxViewModel(store: store),
        onOpenJoinRequest: { _ in }
    )
}
