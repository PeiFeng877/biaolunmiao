//
//  ScheduleViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的比赛与队伍数据。
//  OUTPUT: 当前用户相关赛程列表。
//  POS: 日程视图模型。
//

import Foundation
import Combine

final class ScheduleViewModel: ObservableObject {
    @Published private(set) var myMatches: [Match] = []
    
    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AppStore) {
        self.store = store
        self.myMatches = store.myMatches()
        
        Publishers.CombineLatest3(store.$matches, store.$rosters, store.$currentUser)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                guard let self = self else { return }
                self.myMatches = store.myMatches()
            }
            .store(in: &cancellables)
    }
}
