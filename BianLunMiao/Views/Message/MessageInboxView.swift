//
//  MessageInboxView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: MessageInboxViewModel 提供的申请消息分区数据。
//  OUTPUT: 消息收件箱（待处理申请 + 申请结果通知）。
//  POS: 消息 Tab 根页面。
//

import SwiftUI

struct MessageInboxView: View {
    @StateObject private var viewModel: MessageInboxViewModel

    init(store: AppStore) {
        _viewModel = StateObject(wrappedValue: MessageInboxViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
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
                            messageList(viewModel.incoming)
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
                            messageList(viewModel.outgoing)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { requestId in
                JoinRequestMessageDetailView(viewModel: viewModel, requestId: requestId)
            }
        }
    }

    private func messageList(_ requests: [TeamJoinRequest]) -> some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(requests) { request in
                    NavigationLink(value: request.id) {
                        JoinRequestMessageRow(
                            title: rowTitle(for: request),
                            subtitle: rowSubtitle(for: request),
                            status: request.status
                        )
                    }
                    .buttonStyle(.plain)

                    if request.id != requests.last?.id {
                        Divider().overlay(AppColor.outline)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
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
    MessageInboxView(store: AppStore())
}
