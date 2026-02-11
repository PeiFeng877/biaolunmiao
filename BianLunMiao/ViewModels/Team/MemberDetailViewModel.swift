//
//  MemberDetailViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 与指定成员 User。
//  OUTPUT: 成员详情页的赛程数据与筛选结果。
//  POS: 成员详情视图模型。
//

import Foundation
import Combine

final class MemberDetailViewModel: ObservableObject {
    @Published private(set) var user: User
    @Published private(set) var pastMatches: [Match] = []
    @Published private(set) var upcomingMatches: [Match] = []

    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()

    init(store: AppStore, user: User) {
        self.store = store
        self.user = user
        refreshMatches()

        store.$matches
            .combineLatest(store.$rosters)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refreshMatches()
            }
            .store(in: &cancellables)
    }

    private func refreshMatches() {
        let allMatches = store.matches(forUser: user.id)
        let now = Date()
        let past = allMatches.filter { $0.startTime < now }.sorted { $0.startTime > $1.startTime }
        let upcoming = allMatches.filter { $0.startTime >= now }.sorted { $0.startTime < $1.startTime }
        pastMatches = past
        upcomingMatches = upcoming
    }
}
