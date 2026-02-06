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

enum JoinTeamError: String, Error {
    case invalidId = "请输入队伍 ID"
    case notFound = "未找到该队伍"
    case alreadyMember = "你已在该队伍中"
}

enum JoinTeamResult {
    case success(Team)
    case failure(JoinTeamError)
}

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
    func createTeam(name: String, slogan: String, about: String, avatarStyle: TeamAvatarStyle) -> Team {
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
            slogan: slogan,
            about: about,
            avatarStyle: avatarStyle,
            avatarUrl: nil,
            ownerId: currentUser.id,
            status: .normal,
            members: [member]
        )
        teams.insert(newTeam, at: 0)
        return newTeam
    }
    
    func updateTeam(id: UUID, name: String, slogan: String, about: String, avatarStyle: TeamAvatarStyle) {
        guard var team = teams.first(where: { $0.id == id }) else { return }
        team.name = name
        team.slogan = slogan
        team.about = about
        team.avatarStyle = avatarStyle
        replaceTeam(team)
    }
    
    func removeMember(teamId: UUID, memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        if let member = team.members.first(where: { $0.id == memberId }), member.role == .owner {
            return
        }
        team.members.removeAll { $0.id == memberId }
        replaceTeam(team)
    }
    
    func toggleAdmin(teamId: UUID, memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        guard let idx = team.members.firstIndex(where: { $0.id == memberId }) else { return }
        guard team.members[idx].role != .owner else { return }
        team.members[idx].role = (team.members[idx].role == .admin) ? .member : .admin
        replaceTeam(team)
    }

    func transferOwner(teamId: UUID, to memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        guard let newOwnerIndex = team.members.firstIndex(where: { $0.id == memberId }) else { return }
        guard let currentOwnerIndex = team.members.firstIndex(where: { $0.role == .owner }) else { return }

        team.members[currentOwnerIndex].role = .admin
        team.members[newOwnerIndex].role = .owner
        team.ownerId = team.members[newOwnerIndex].userId
        replaceTeam(team)
    }

    @discardableResult
    func joinTeam(publicId: String) -> JoinTeamResult {
        guard !publicId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidId)
        }
        guard var team = teams.first(where: { $0.publicId == publicId }) else {
            return .failure(.notFound)
        }
        let alreadyMember = team.members.contains { $0.userId == currentUser.id }
        if alreadyMember {
            return .failure(.alreadyMember)
        }

        let newMember = TeamMember(
            id: UUID(),
            teamId: team.id,
            userId: currentUser.id,
            role: .member,
            joinTime: Date(),
            user: currentUser
        )
        team.members.append(newMember)
        replaceTeam(team)
        return .success(team)
    }

    func matches(forUser userId: UUID) -> [Match] {
        let teamIds = teams
            .filter { team in
                team.members.contains { $0.userId == userId }
            }
            .map(\.id)
        guard !teamIds.isEmpty else { return [] }
        return matches.filter { match in
            let a = match.teamAId
            let b = match.teamBId
            return (a.map(teamIds.contains) ?? false) || (b.map(teamIds.contains) ?? false)
        }
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
