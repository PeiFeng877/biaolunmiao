//
//  MatchManagementViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: AppStore 与赛事 ID。
//  OUTPUT: 赛程管理、阵容指派、赛果录入状态。
//  POS: 赛事赛程管理视图模型。
//

import Foundation
import Combine



@MainActor
final class MatchManagementViewModel: ObservableObject {
    struct MatchForm: Hashable {
        var name: String
        var startTime: Date
        var location: String
        var format: MatchFormat
        var teamAId: UUID?
        var teamBId: UUID?

        static func createDefault() -> MatchForm {
            let start = Date().addingTimeInterval(3600)
            return MatchForm(
                name: "",
                startTime: start,
                location: "",
                format: .f3v3,
                teamAId: nil,
                teamBId: nil
            )
        }

        init(match: Match) {
            self.name = match.name
            self.startTime = match.startTime
            self.location = match.location ?? ""
            self.format = match.format
            self.teamAId = match.teamAId
            self.teamBId = match.teamBId
        }

        init(
            name: String,
            startTime: Date,
            location: String,
            format: MatchFormat,
            teamAId: UUID?,
            teamBId: UUID?
        ) {
            self.name = name
            self.startTime = startTime
            self.location = location
            self.format = format
            self.teamAId = teamAId
            self.teamBId = teamBId
        }

        var draft: MatchDraft {
            MatchDraft(
                name: name,
                startTime: startTime,
                endTime: startTime.addingTimeInterval(AppStore.fixedMatchDuration),
                location: location,
                format: format
            )
        }
    }

    @Published private(set) var tournament: Tournament
    @Published private(set) var matches: [Match] = []
    @Published private(set) var assignableTeams: [Team] = []

    private let store: AppStore
    private let tournamentId: UUID
    private var cancellables = Set<AnyCancellable>()

    init(store: AppStore, tournamentId: UUID) {
        self.store = store
        self.tournamentId = tournamentId
        self.tournament = store.tournament(id: tournamentId) ?? Tournament(
            id: tournamentId,
            name: "未知赛事",
            intro: nil,
            coverUrl: nil,
            creatorId: store.currentUser.id,
            status: .open,
            participants: []
        )
        self.matches = store.matches(for: tournamentId)
        self.assignableTeams = store.searchableTeams().sorted { $0.name < $1.name }

        Publishers.CombineLatest3(store.$tournaments, store.$matches, store.$teams)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        store.$discoverableTeams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    var canManageTournament: Bool {
        store.canCurrentUserManageTournament(tournamentId: tournamentId)
    }

    func createForm() -> MatchForm {
        .createDefault()
    }

    func editForm(for match: Match) -> MatchForm {
        MatchForm(match: match)
    }

    @discardableResult
    func saveMatch(form: MatchForm, editingMatchId: UUID?) -> Bool {
        let trimmedName = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let normalized = MatchForm(
            name: trimmedName,
            startTime: form.startTime,
            location: form.location,
            format: form.format,
            teamAId: form.teamAId,
            teamBId: form.teamBId
        )

        if let editingMatchId {
            store.updateMatch(matchId: editingMatchId, draft: normalized.draft)
            if let teamAId = normalized.teamAId, let teamBId = normalized.teamBId {
                guard store.assignTeams(matchId: editingMatchId, teamAId: teamAId, teamBId: teamBId) else {
                    return false
                }
            }
            return true
        }

        let created = store.createMatch(tournamentId: tournamentId, draft: normalized.draft)
        if let teamAId = normalized.teamAId, let teamBId = normalized.teamBId {
            guard store.assignTeams(matchId: created.id, teamAId: teamAId, teamBId: teamBId) else {
                return false
            }
        }
        return true
    }

    func rosterCount(matchId: UUID, teamId: UUID?) -> Int {
        guard let teamId else { return 0 }
        return store.rosterEntries(matchId: matchId, teamId: teamId).count
    }

    func requiredRosterCount(for match: Match) -> Int {
        match.format.positions.count
    }

    func saveRoster(matchId: UUID, teamId: UUID, assignments: [RosterAssignment]) -> Bool {
        store.saveRoster(matchId: matchId, teamId: teamId, assignments: assignments)
    }

    func existingRosterAssignments(matchId: UUID, teamId: UUID) -> [RosterAssignment] {
        store.rosterEntries(matchId: matchId, teamId: teamId).map {
            RosterAssignment(userId: $0.userId, position: $0.position)
        }
    }

    func teamMembers(teamId: UUID) -> [TeamMember] {
        store.team(by: teamId)?.members ?? []
    }

    func teamEntity(teamId: UUID) -> Team? {
        store.team(by: teamId)
    }

    func canManageTeam(teamId: UUID) -> Bool {
        store.canCurrentUserManageTeam(teamId: teamId)
    }

    func recordResult(matchId: UUID, winnerTeamId: UUID, teamAScore: Int, teamBScore: Int) -> Bool {
        store.recordMatchResult(
            matchId: matchId,
            winnerTeamId: winnerTeamId,
            teamAScore: teamAScore,
            teamBScore: teamBScore
        )
    }

    func advanceStatus(matchId: UUID, to status: MatchStatus) -> Bool {
        store.advanceMatchStatus(matchId: matchId, to: status)
    }

    func teamName(teamId: UUID?) -> String {
        guard let teamId else { return "待定" }
        return store.team(by: teamId)?.name ?? "待定"
    }

    private func refresh() {
        if let updated = store.tournament(id: tournamentId) {
            tournament = updated
        }
        matches = store.matches(for: tournamentId)
        assignableTeams = store.searchableTeams().sorted { $0.name < $1.name }
    }
}
