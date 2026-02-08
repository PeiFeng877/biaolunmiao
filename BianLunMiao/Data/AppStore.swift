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
    @Published var discoverableTeams: [Team]
    @Published var teamJoinRequests: [TeamJoinRequest]
    @Published var tournaments: [Tournament]
    @Published var matches: [Match]
    @Published var rosters: [Roster]
    
    init(mock: MockData = .shared) {
        self.currentUser = mock.currentUser
        self.teams = mock.myTeams
        self.discoverableTeams = mock.discoverableTeams
        self.teamJoinRequests = mock.teamJoinRequests
        self.tournaments = mock.tournaments
        self.matches = mock.matches
        self.rosters = mock.rosters
    }
    
    // MARK: - Teams
    @discardableResult
    func createTeam(name: String, slogan: String, avatarImageData: Data?) -> Team {
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
            about: nil,
            avatarStyle: .paw,
            avatarUrl: avatarImageData.flatMap { storeTeamAvatar($0, teamId: teamId) },
            ownerId: currentUser.id,
            status: .normal,
            members: [member]
        )
        teams.insert(newTeam, at: 0)
        return newTeam
    }
    
    func updateTeam(id: UUID, name: String, slogan: String, avatarImageData: Data?) {
        guard var team = teams.first(where: { $0.id == id }) else { return }
        team.name = name
        team.slogan = slogan

        if let avatarImageData {
            let oldAvatarPath = team.avatarUrl
            if let newAvatarPath = storeTeamAvatar(avatarImageData, teamId: id) {
                team.avatarUrl = newAvatarPath
                if let oldAvatarPath, oldAvatarPath != newAvatarPath {
                    try? FileManager.default.removeItem(atPath: oldAvatarPath)
                }
            }
        }
        replaceTeam(team)
    }

    func dissolveTeam(id: UUID) {
        guard let team = teams.first(where: { $0.id == id }) else { return }
        if let avatarPath = team.avatarUrl {
            try? FileManager.default.removeItem(atPath: avatarPath)
        }
        teams.removeAll { $0.id == id }
        teamJoinRequests.removeAll { $0.teamId == id }
        removeTeamAssociations(teamId: id)
    }

    func leaveTeam(teamId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        guard let currentMember = team.members.first(where: { $0.userId == currentUser.id }) else { return }
        guard currentMember.role != .owner else { return }

        team.members.removeAll { $0.userId == currentUser.id }
        teams.removeAll { $0.id == teamId }
        if !discoverableTeams.contains(where: { $0.id == team.id }) {
            discoverableTeams.append(team)
        }
        removeTeamAssociations(teamId: teamId)
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
    func submitTeamJoinRequest(
        teamPublicId: String,
        personalNote: String,
        reason: String
    ) -> TeamJoinRequestSubmitResult {
        let trimmedId = teamPublicId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            return .failure(.invalidId)
        }

        let trimmedNote = personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            return .failure(.invalidRemark)
        }

        guard let team = searchableTeams().first(where: { $0.publicId == trimmedId }) else {
            return .failure(.notFound)
        }

        let alreadyMember = team.members.contains { $0.userId == currentUser.id }
        if alreadyMember {
            return .failure(.alreadyMember)
        }

        let duplicatePending = teamJoinRequests.contains { request in
            request.teamId == team.id &&
            request.applicantUserId == currentUser.id &&
            request.status == .pending
        }
        if duplicatePending {
            return .failure(.duplicatePending)
        }

        let request = TeamJoinRequest(
            id: UUID(),
            teamId: team.id,
            teamPublicId: team.publicId,
            teamName: team.name,
            applicantUserId: currentUser.id,
            applicantPublicId: currentUser.publicId,
            applicantNickname: currentUser.nickname,
            personalNote: trimmedNote,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            status: .pending,
            reviewedAt: nil,
            reviewedByUserId: nil,
            reviewedByNickname: nil
        )
        teamJoinRequests.insert(request, at: 0)
        return .success(request)
    }

    @discardableResult
    func reviewTeamJoinRequest(
        requestId: UUID,
        decision: TeamJoinRequestDecision
    ) -> TeamJoinRequestReviewResult {
        guard let requestIndex = teamJoinRequests.firstIndex(where: { $0.id == requestId }) else {
            return .failure(.notFound)
        }

        var request = teamJoinRequests[requestIndex]
        guard canCurrentUserReviewJoinRequest(teamId: request.teamId) else {
            return .failure(.unauthorized)
        }

        guard request.status == .pending else {
            return .failure(.alreadyProcessed)
        }

        if decision == .approve {
            guard var targetTeam = searchableTeams().first(where: { $0.id == request.teamId }) else {
                return .failure(.notFound)
            }

            let applicantIsMember = targetTeam.members.contains { $0.userId == request.applicantUserId }
            if applicantIsMember {
                return .failure(.alreadyMember)
            }

            let applicant = userSnapshot(
                userId: request.applicantUserId,
                publicId: request.applicantPublicId,
                nickname: request.applicantNickname
            )
            targetTeam.members.append(makeMember(user: applicant, teamId: targetTeam.id))
            replaceTeam(targetTeam)
        }

        request.status = (decision == .approve) ? .approved : .rejected
        request.reviewedAt = Date()
        request.reviewedByUserId = currentUser.id
        request.reviewedByNickname = currentUser.nickname
        teamJoinRequests[requestIndex] = request
        return .success(request)
    }

    func canCurrentUserReviewJoinRequest(teamId: UUID) -> Bool {
        guard let team = searchableTeams().first(where: { $0.id == teamId }) else {
            return false
        }

        return team.members.contains { member in
            member.userId == currentUser.id && (member.role == .owner || member.role == .admin)
        }
    }

    func searchableTeams() -> [Team] {
        let combined = teams + discoverableTeams
        var seen = Set<UUID>()
        return combined.filter { team in
            seen.insert(team.id).inserted
        }
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
    private func makeMember(user: User, teamId: UUID) -> TeamMember {
        TeamMember(
            id: UUID(),
            teamId: teamId,
            userId: user.id,
            role: .member,
            joinTime: Date(),
            user: user
        )
    }

    private func userSnapshot(userId: UUID, publicId: String, nickname: String) -> User {
        if currentUser.id == userId {
            return currentUser
        }

        if let member = (teams + discoverableTeams)
            .flatMap(\.members)
            .first(where: { $0.userId == userId }) {
            return member.user
        }

        return User(
            id: userId,
            publicId: publicId,
            nickname: nickname,
            avatarUrl: nil,
            status: .normal
        )
    }

    private func removeTeamAssociations(teamId: UUID) {
        for tournamentIndex in tournaments.indices {
            tournaments[tournamentIndex].teams.removeAll { $0.id == teamId }
        }
        matches.removeAll { $0.teamAId == teamId || $0.teamBId == teamId }
    }

    private func storeTeamAvatar(_ data: Data, teamId: UUID) -> String? {
        let directoryURL = teamAvatarDirectoryURL()
        let fileURL = directoryURL
            .appendingPathComponent("team-\(teamId.uuidString)-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            return nil
        }
    }

    private func teamAvatarDirectoryURL() -> URL {
        let rootURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return rootURL.appendingPathComponent("TeamAvatars", isDirectory: true)
    }

    private func replaceTeam(_ team: Team) {
        if let idx = teams.firstIndex(where: { $0.id == team.id }) {
            teams[idx] = team
        }

        if let idx = discoverableTeams.firstIndex(where: { $0.id == team.id }) {
            discoverableTeams[idx] = team
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
