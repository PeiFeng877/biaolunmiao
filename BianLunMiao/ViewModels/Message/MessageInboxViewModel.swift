//
//  MessageInboxViewModel.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: AppStore 的入队申请状态与当前用户身份。
//  OUTPUT: 消息收件箱列表（待审批 + 结果通知）与审批动作。
//  POS: 消息页视图模型。
//

import Foundation
import Combine

final class MessageInboxViewModel: ObservableObject {
    @Published private(set) var incoming: [TeamJoinRequest] = []
    @Published private(set) var outgoing: [TeamJoinRequest] = []

    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()

    init(store: AppStore) {
        self.store = store
        refresh()

        Publishers.CombineLatest3(store.$teamJoinRequests, store.$teams, store.$discoverableTeams)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
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
    }
}
