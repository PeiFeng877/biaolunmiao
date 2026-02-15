//
//  MessageInboxViewModel.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的申请消息、系统通知消息与用户身份。
//  OUTPUT: 消息收件箱分段数据（申请/通知/状态变更）与动作。
//  POS: 消息页视图模型。
//

import Foundation
import Combine

enum InboxSection: String, CaseIterable, Identifiable {
    case application = "待处理"
    case notification = "通知"
    case statusChange = "状态变更"

    var id: String { rawValue }
}

final class MessageInboxViewModel: ObservableObject {
    @Published var selectedSection: InboxSection = .application
    @Published private(set) var incoming: [TeamJoinRequest] = []
    @Published private(set) var outgoing: [TeamJoinRequest] = []
    @Published private(set) var notifications: [InboxMessage] = []
    @Published private(set) var statusChanges: [InboxMessage] = []

    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()

    init(store: AppStore) {
        self.store = store
        refresh()

        Publishers.CombineLatest4(
            store.$teamJoinRequests,
            store.$teams,
            store.$discoverableTeams,
            store.$inboxMessages
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.refresh()
        }
        .store(in: &cancellables)
    }

    func request(id: UUID) -> TeamJoinRequest? {
        store.teamJoinRequests.first(where: { $0.id == id })
    }

    func canReview(_ request: TeamJoinRequest) -> Bool {
        request.status == .pending && store.canCurrentUserReviewJoinRequest(teamId: request.teamId)
    }

    @discardableResult
    func approve(requestId: UUID) -> TeamJoinRequestReviewResult {
        store.reviewTeamJoinRequest(requestId: requestId, decision: .approve)
    }

    @discardableResult
    func reject(requestId: UUID) -> TeamJoinRequestReviewResult {
        store.reviewTeamJoinRequest(requestId: requestId, decision: .reject)
    }

    func acknowledgeMessage(id: UUID) {
        store.acknowledgeInboxMessage(id: id)
    }

    private func refresh() {
        incoming = store.teamJoinRequests
            .filter { $0.status == .pending && store.canCurrentUserReviewJoinRequest(teamId: $0.teamId) }
            .sorted { $0.createdAt > $1.createdAt }

        outgoing = store.teamJoinRequests
            .filter { $0.applicantUserId == store.currentUser.id && $0.status != .pending }
            .sorted { lhs, rhs in
                let leftTime = lhs.reviewedAt ?? lhs.createdAt
                let rightTime = rhs.reviewedAt ?? rhs.createdAt
                return leftTime > rightTime
            }

        notifications = store.inboxMessages
            .filter { $0.kind == .notification }
            .sorted { $0.createdAt > $1.createdAt }

        statusChanges = store.inboxMessages
            .filter { $0.kind == .statusChange }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
