//
//  TeamListViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: AppStore 的队伍列表。
//  OUTPUT: 队伍列表状态与创建入口。
//  POS: 队伍列表视图模型。
//

import Foundation
import Combine

final class TeamListViewModel: ObservableObject {
    @Published private(set) var teams: [Team] = []
    @Published var showCreateSheet = false
    
    private let store: AppStore
    
    init(store: AppStore) {
        self.store = store
        self.teams = store.teams
        
        store.$teams
            .receive(on: DispatchQueue.main)
            .assign(to: &$teams)
    }
    
    func createTeam(name: String, intro: String) {
        _ = store.createTeam(name: name, intro: intro)
    }
    
    func isOwner(team: Team) -> Bool {
        team.ownerId == store.currentUser.id
    }
}
