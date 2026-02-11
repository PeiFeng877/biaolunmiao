//
//  TeamListViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的队伍列表。
//  OUTPUT: 队伍列表状态与创建/申请入口。
//  POS: 队伍列表视图模型。
//

import Foundation
import Combine

final class TeamListViewModel: ObservableObject {
    @Published private(set) var teams: [Team] = []
    @Published private(set) var discoverableTeams: [Team] = []
    @Published var showCreateSheet = false
    
    private let store: AppStore
    
    init(store: AppStore) {
        self.store = store
        self.teams = store.teams
        self.discoverableTeams = store.discoverableTeams
        
        store.$teams
            .receive(on: DispatchQueue.main)
            .assign(to: &$teams)

        store.$discoverableTeams
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoverableTeams)
    }
    
    func createTeam(name: String, slogan: String, avatarImageData: Data?) -> Team {
        store.createTeam(name: name, slogan: slogan, avatarImageData: avatarImageData)
    }

    func submitJoinRequestByPublicId(
        publicId: String,
        personalNote: String,
        reason: String
    ) -> TeamJoinRequestSubmitResult {
        store.submitTeamJoinRequest(
            teamPublicId: publicId,
            personalNote: personalNote,
            reason: reason
        )
    }

    func submitJoinRequestByTeamId(
        teamId: UUID,
        personalNote: String,
        reason: String
    ) -> TeamJoinRequestSubmitResult {
        guard let team = searchableTeams().first(where: { $0.id == teamId }) else {
            return .failure(.notFound)
        }

        return store.submitTeamJoinRequest(
            teamPublicId: team.publicId,
            personalNote: personalNote,
            reason: reason
        )
    }

    func searchableTeams(query: String) -> [Team] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return searchableTeams().filter { team in
            team.name.localizedStandardContains(trimmed) || team.publicId.localizedStandardContains(trimmed)
        }
    }

    func isMember(team: Team) -> Bool {
        team.members.contains { $0.userId == store.currentUser.id }
    }

    var currentUserNickname: String {
        store.currentUser.nickname
    }
    
    func isOwner(team: Team) -> Bool {
        team.ownerId == store.currentUser.id
    }

    private func searchableTeams() -> [Team] {
        store.searchableTeams()
    }
}
