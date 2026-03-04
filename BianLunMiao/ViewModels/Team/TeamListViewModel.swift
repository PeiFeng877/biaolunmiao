//
//  TeamListViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: AppStore 的队伍列表。
//  OUTPUT: 队伍列表状态与创建/申请入口。
//  POS: 队伍列表视图模型。
//

import Foundation
import Combine

@MainActor
final class TeamListViewModel: ObservableObject {
    @Published private(set) var teams: [Team] = []
    @Published private(set) var discoverableTeams: [Team] = []
    @Published var showCreateSheet = false
    
    private let store: AppStore

    private var shouldTraceTeamActions: Bool {
#if DEBUG
        return true
#else
        let env = ProcessInfo.processInfo.environment
        return env["BLM_UI_TEST_MODE"] == "1" || env["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] == "1"
#endif
    }
    
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
    
    func createTeam(payload: TeamCreatePayload) async throws -> Team {
        traceTeamAction("createTeam entered nameLength=\(payload.name.count) sloganLength=\(payload.slogan?.count ?? 0) actor=main")
        do {
            traceTeamAction("createTeam before store await")
            let team = try await store.createTeam(payload: payload)
            traceTeamAction("createTeam success teamId=\(team.id.uuidString.lowercased())")
            return team
        } catch {
            traceTeamAction("createTeam failed error=\(error.localizedDescription)")
            throw error
        }
    }

    func submitJoinRequestByPublicId(
        publicId: String,
        personalNote: String,
        reason: String
    ) async throws -> TeamJoinRequest {
        try await store.submitTeamJoinRequest(
            teamPublicId: publicId,
            personalNote: personalNote,
            reason: reason
        )
    }

    func submitJoinRequestByTeamId(
        teamId: UUID,
        personalNote: String,
        reason: String
    ) async throws -> TeamJoinRequest {
        guard let team = searchableTeams().first(where: { $0.id == teamId }) else {
            throw TeamJoinRequestError.notFound
        }

        return try await store.submitTeamJoinRequest(
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

    private func traceTeamAction(_ message: String) {
        guard shouldTraceTeamActions else { return }
        print("[TeamListViewModel] \(message)")
    }
}
