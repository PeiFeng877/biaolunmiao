//
//  AppStore.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: MockData 与模型数组。
//  OUTPUT: 应用状态存储与领域操作。
//  POS: 数据层 Store。
//

import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published var currentUser: User
    @Published var teams: [Team]
    @Published var tournaments: [Tournament]
    @Published var matches: [Match]
    @Published var rosters: [Roster]
    
    init(mock: MockData = .shared) {
        self.currentUser = mock.currentUser
        self.teams = mock.myTeams
        self.tournaments = mock.tournaments
        self.matches = mock.matches
        self.rosters = mock.rosters
    }
    
    // MARK: - Teams
    @discardableResult
    func createTeam(name: String, intro: String) -> Team {
        let teamId = UUID()
        let member = TeamMember(
            id: UUID(),
            teamId: teamId,
            userId: currentUser.id,
            role: .owner,
            joinTime: Date(),
            user: currentUser
        )
        let newTeam = Team(
            id: teamId,
            publicId: String(Int.random(in: 1000...9999)),
            name: name,
            intro: intro,
            avatarUrl: nil,
            ownerId: currentUser.id,
            status: .normal,
            members: [member]
        )
        teams.insert(newTeam, at: 0)
        return newTeam
    }
    
    func updateTeam(id: UUID, name: String, intro: String) {
        guard var team = teams.first(where: { $0.id == id }) else { return }
        team.name = name
        team.intro = intro
        replaceTeam(team)
    }
    
    func removeMember(teamId: UUID, memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        team.members.removeAll { $0.id == memberId }
        replaceTeam(team)
    }
    
    func toggleAdmin(teamId: UUID, memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        guard let idx = team.members.firstIndex(where: { $0.id == memberId }) else { return }
        team.members[idx].role = (team.members[idx].role == .admin) ? .member : .admin
        replaceTeam(team)
    }
    
    // MARK: - Tournaments
    @discardableResult
    func createTournament(name: String, intro: String) -> Tournament {
        let tour = Tournament(
            id: UUID(),
            name: name,
            intro: intro,
            coverUrl: nil,
            creatorId: currentUser.id,
            status: .draft,
            teams: []
        )
        tournaments.insert(tour, at: 0)
        return tour
    }
    
    // MARK: - Matches
    func matches(for tournamentId: UUID) -> [Match] {
        matches.filter { $0.tournamentId == tournamentId }
    }
    
    @discardableResult
    func addMatch(tournamentId: UUID) -> Match {
        let teams = tournaments.first(where: { $0.id == tournamentId })?.teams ?? []
        let teamA = teams.first
        let teamB = teams.last
        let newMatch = Match(
            id: UUID(),
            tournamentId: tournamentId,
            name: "新建场次",
            startTime: Date().addingTimeInterval(86400),
            endTime: Date().addingTimeInterval(86400 + 3600),
            location: "TBD",
            teamAId: teamA?.id,
            teamBId: teamB?.id,
            format: .f3v3,
            status: .scheduled,
            teamA: teamA,
            teamB: teamB
        )
        matches.append(newMatch)
        return newMatch
    }
    
    // MARK: - Rosters
    func saveRosters(_ newRosters: [Roster]) {
        rosters.append(contentsOf: newRosters)
    }
    
    // MARK: - Derived
    func myTeamIds() -> Set<UUID> {
        Set(teams.filter { team in
            team.members.contains { $0.userId == currentUser.id }
        }.map(\.id))
    }
    
    func myMatches() -> [Match] {
        let teamIds = myTeamIds()
        return matches.filter { match in
            guard let a = match.teamAId, let b = match.teamBId else { return false }
            return teamIds.contains(a) || teamIds.contains(b)
        }
    }
    
    // MARK: - Helpers
    private func replaceTeam(_ team: Team) {
        if let idx = teams.firstIndex(where: { $0.id == team.id }) {
            teams[idx] = team
        }
        
        for tIndex in tournaments.indices {
            if let idx = tournaments[tIndex].teams.firstIndex(where: { $0.id == team.id }) {
                tournaments[tIndex].teams[idx] = team
            }
        }
        
        for mIndex in matches.indices {
            if matches[mIndex].teamAId == team.id {
                matches[mIndex].teamA = team
            }
            if matches[mIndex].teamBId == team.id {
                matches[mIndex].teamB = team
            }
        }
    }
}
