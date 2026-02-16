//
//  MessageInboxViewModel.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/15.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的申请消息、系统通知消息与用户身份。
//  OUTPUT: 消息收件箱单流数据（统一倒序卡片）与动作。
//  POS: 消息页视图模型。
//

import Foundation
import Combine

enum MessageFeedItem: Identifiable, Hashable {
    case joinRequest(TeamJoinRequest)
    case system(InboxMessage)

    var id: UUID {
        switch self {
        case .joinRequest(let request):
            return request.id
        case .system(let message):
            return message.id
        }
    }

    var sortTime: Date {
        switch self {
        case .joinRequest(let request):
            return request.reviewedAt ?? request.createdAt
        case .system(let message):
            return message.createdAt
        }
    }
}



@MainActor
final class MessageInboxViewModel: ObservableObject {
    @Published private(set) var feedItems: [MessageFeedItem] = []

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

    private func refresh() {
        let pendingReviews = store.teamJoinRequests
            .filter { $0.status == .pending && store.canCurrentUserReviewJoinRequest(teamId: $0.teamId) }

        let reviewResults = store.teamJoinRequests
            .filter { $0.applicantUserId == store.currentUser.id && $0.status != .pending }

        let joinRequestItems = (pendingReviews + reviewResults).map(MessageFeedItem.joinRequest)
        let systemItems = store.inboxMessages
            .filter { $0.kind == .notification || $0.kind == .statusChange }
            .map(MessageFeedItem.system)

        feedItems = (joinRequestItems + systemItems)
            .sorted { $0.sortTime > $1.sortTime }
    }
}
