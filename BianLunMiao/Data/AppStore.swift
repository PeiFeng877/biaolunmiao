//
//  AppStore.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: MockData 与模型数组。
//  OUTPUT: 应用状态存储与领域操作。
//  POS: 数据层 Store。
//

import Foundation
import Combine

final class AppStore: ObservableObject {
    static let fixedMatchDuration: TimeInterval = 90 * 60

    @Published var currentUser: User
    @Published var teams: [Team]
    @Published var discoverableTeams: [Team]
    @Published var teamJoinRequests: [TeamJoinRequest]
    @Published var inboxMessages: [InboxMessage]
    @Published var tournaments: [Tournament]
    @Published var matches: [Match]
    @Published var rosters: [Roster]
    private let remoteGateway: RemoteGateway?
    private var remoteRefreshTask: Task<Void, Never>?

    init(mock: MockData = .shared) {
        self.currentUser = mock.currentUser
        self.teams = mock.myTeams
        self.discoverableTeams = mock.discoverableTeams
        self.teamJoinRequests = mock.teamJoinRequests
        self.inboxMessages = mock.inboxMessages
        self.tournaments = mock.tournaments
        self.matches = mock.matches
        self.rosters = mock.rosters
        self.remoteGateway = Self.shouldEnableRemoteGateway() ? .shared : nil
        scheduleRemoteRefresh()
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
        syncRemote { gateway in
            _ = try await gateway.createTeam(
                name: name,
                intro: slogan.isEmpty ? nil : slogan,
                avatarURL: newTeam.avatarUrl
            )
        }
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
        syncRemote { gateway in
            _ = try await gateway.updateTeam(
                teamID: id.uuidString.lowercased(),
                name: name,
                intro: slogan.isEmpty ? nil : slogan,
                avatarURL: team.avatarUrl
            )
        }
    }

    func dissolveTeam(id: UUID) {
        guard let team = teams.first(where: { $0.id == id }) else { return }
        if let avatarPath = team.avatarUrl {
            try? FileManager.default.removeItem(atPath: avatarPath)
        }
        teams.removeAll { $0.id == id }
        teamJoinRequests.removeAll { $0.teamId == id }
        removeTeamAssociations(teamId: id)
        syncRemote { gateway in
            try await gateway.dissolveTeam(teamID: id.uuidString.lowercased())
        }
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
        syncRemote { gateway in
            try await gateway.removeMember(
                teamID: teamId.uuidString.lowercased(),
                memberID: currentMember.id.uuidString.lowercased()
            )
        }
    }

    func removeMember(teamId: UUID, memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        if let member = team.members.first(where: { $0.id == memberId }), member.role == .owner {
            return
        }
        team.members.removeAll { $0.id == memberId }
        replaceTeam(team)
        syncRemote { gateway in
            try await gateway.removeMember(
                teamID: teamId.uuidString.lowercased(),
                memberID: memberId.uuidString.lowercased()
            )
        }
    }

    func toggleAdmin(teamId: UUID, memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        guard let idx = team.members.firstIndex(where: { $0.id == memberId }) else { return }
        guard team.members[idx].role != .owner else { return }
        team.members[idx].role = (team.members[idx].role == .admin) ? .member : .admin
        replaceTeam(team)
        syncRemote { gateway in
            try await gateway.toggleAdmin(
                teamID: teamId.uuidString.lowercased(),
                memberID: memberId.uuidString.lowercased()
            )
        }
    }

    func transferOwner(teamId: UUID, to memberId: UUID) {
        guard var team = teams.first(where: { $0.id == teamId }) else { return }
        guard let newOwnerIndex = team.members.firstIndex(where: { $0.id == memberId }) else { return }
        guard let currentOwnerIndex = team.members.firstIndex(where: { $0.role == .owner }) else { return }

        team.members[currentOwnerIndex].role = .admin
        team.members[newOwnerIndex].role = .owner
        team.ownerId = team.members[newOwnerIndex].userId
        replaceTeam(team)
        syncRemote { gateway in
            try await gateway.transferOwner(
                teamID: teamId.uuidString.lowercased(),
                memberID: memberId.uuidString.lowercased()
            )
        }
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
        syncRemote { gateway in
            _ = try await gateway.submitJoinRequest(
                teamID: team.id.uuidString.lowercased(),
                personalNote: trimmedNote,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
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
        let isApprove = decision == .approve
        syncRemote { gateway in
            _ = try await gateway.reviewJoinRequest(
                requestID: requestId.uuidString.lowercased(),
                approve: isApprove
            )
        }
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

    func searchableUsers(query: String) -> [User] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let users = allUsers()

        guard !trimmed.isEmpty else {
            return users.sorted { $0.nickname < $1.nickname }
        }

        return users
            .filter {
                $0.nickname.localizedStandardContains(trimmed) ||
                $0.publicId.localizedStandardContains(trimmed)
            }
            .sorted { $0.nickname < $1.nickname }
    }

    func searchableTournaments(query: String) -> [Tournament] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return tournaments.sorted { $0.name < $1.name }
        }

        return tournaments
            .filter {
                $0.name.localizedStandardContains(trimmed) ||
                tournamentShortCode(for: $0.id).localizedStandardContains(trimmed.uppercased())
            }
            .sorted { $0.name < $1.name }
    }

    func team(by id: UUID) -> Team? {
        searchableTeams().first(where: { $0.id == id })
    }

    func canCurrentUserManageTeam(teamId: UUID) -> Bool {
        guard let team = team(by: teamId) else { return false }
        return team.members.contains { member in
            member.userId == currentUser.id && (member.role == .owner || member.role == .admin)
        }
    }

    func matches(forUser userId: UUID) -> [Match] {
        let matchIds = Set(rosters.filter { $0.userId == userId }.map(\.matchId))
        return matches
            .filter { matchIds.contains($0.id) }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Tournaments
    @discardableResult
    func createTournament(name: String, intro: String, status: TournamentStatus = .open) -> Tournament {
        let tour = Tournament(
            id: UUID(),
            name: name,
            intro: intro,
            coverUrl: nil,
            creatorId: currentUser.id,
            status: status,
            participants: []
        )
        tournaments.insert(tour, at: 0)
        syncRemote { gateway in
            _ = try await gateway.createTournament(
                name: name,
                intro: intro,
                status: status.rawValue
            )
        }
        return tour
    }

    func tournament(id: UUID) -> Tournament? {
        tournaments.first(where: { $0.id == id })
    }

    @discardableResult
    func updateTournament(tournamentId: UUID, name: String, intro: String, status: TournamentStatus) -> Bool {
        guard canCurrentUserManageTournament(tournamentId: tournamentId) else { return false }
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentId }) else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let trimmedIntro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        tournaments[index].name = trimmedName
        tournaments[index].intro = trimmedIntro.isEmpty ? nil : trimmedIntro
        tournaments[index].status = status
        syncRemote { gateway in
            _ = try await gateway.updateTournament(
                id: tournamentId.uuidString.lowercased(),
                name: trimmedName,
                intro: trimmedIntro,
                status: status.rawValue
            )
        }
        return true
    }

    func canCurrentUserManageTournament(tournamentId: UUID) -> Bool {
        tournaments.contains { $0.id == tournamentId && $0.creatorId == currentUser.id }
    }

    func participantTeams(for tournamentId: UUID) -> [Team] {
        guard let tournament = tournament(id: tournamentId) else { return [] }
        return tournament.confirmedTeams
    }

    // MARK: - Matches
    func matches(for tournamentId: UUID) -> [Match] {
        matches
            .filter { $0.tournamentId == tournamentId }
            .sorted { $0.startTime < $1.startTime }
    }

    @discardableResult
    func createMatch(tournamentId: UUID, draft: MatchDraft) -> Match {
        let trimmedTopic = draft.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpponent = draft.opponentTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fixedEndTime = draft.startTime.addingTimeInterval(Self.fixedMatchDuration)
        let newMatch = Match(
            id: UUID(),
            tournamentId: tournamentId,
            name: draft.name,
            topic: trimmedTopic.isEmpty ? nil : trimmedTopic,
            startTime: draft.startTime,
            endTime: fixedEndTime,
            location: draft.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.location,
            opponentTeamName: trimmedOpponent.isEmpty ? nil : trimmedOpponent,
            teamAId: nil,
            teamBId: nil,
            format: draft.format,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: nil,
            teamB: nil
        )
        matches.append(newMatch)
        refreshTournamentStatus(tournamentId: tournamentId)
        syncRemote { gateway in
            _ = try await gateway.createMatch(
                tournamentID: tournamentId.uuidString.lowercased(),
                draft: draft
            )
        }
        return newMatch
    }

    @discardableResult
    func addMatch(tournamentId: UUID) -> Match {
        createMatch(
            tournamentId: tournamentId,
            draft: MatchDraft(
                name: "新建场次",
                startTime: Date().addingTimeInterval(86400),
                endTime: Date().addingTimeInterval(86400 + Self.fixedMatchDuration),
                location: "",
                format: .f3v3
            )
        )
    }

    func updateMatch(matchId: UUID, draft: MatchDraft) {
        guard let index = matches.firstIndex(where: { $0.id == matchId }) else { return }
        let trimmedTopic = draft.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpponent = draft.opponentTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fixedEndTime = draft.startTime.addingTimeInterval(Self.fixedMatchDuration)
        matches[index].name = draft.name
        matches[index].topic = trimmedTopic.isEmpty ? nil : trimmedTopic
        matches[index].startTime = draft.startTime
        matches[index].endTime = fixedEndTime
        matches[index].location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.location
        matches[index].opponentTeamName = trimmedOpponent.isEmpty ? nil : trimmedOpponent
        matches[index].format = draft.format
        updateMatchStatusFromRosters(matchId: matchId)
        refreshTournamentStatus(tournamentId: matches[index].tournamentId)
        syncRemote { gateway in
            _ = try await gateway.updateMatch(
                matchID: matchId.uuidString.lowercased(),
                draft: draft
            )
        }
    }

    @discardableResult
    func setMatchTeams(matchId: UUID, teamAId: UUID?, teamBId: UUID?) -> Bool {
        guard let index = matches.firstIndex(where: { $0.id == matchId }) else { return false }
        if let teamAId, let teamBId, teamAId == teamBId { return false }

        let teamA = teamAId.flatMap { id in
            team(by: id)
        }
        let teamB = teamBId.flatMap { id in
            team(by: id)
        }

        if teamAId != nil && teamA == nil { return false }
        if teamBId != nil && teamB == nil { return false }

        guard canCurrentUserManageMatch(index: index, candidateTeamAId: teamAId, candidateTeamBId: teamBId) else { return false }

        matches[index].teamAId = teamAId
        matches[index].teamBId = teamBId
        matches[index].teamA = teamA
        matches[index].teamB = teamB

        let validTeamIds = Set([teamAId, teamBId].compactMap { $0 })
        rosters.removeAll { roster in
            roster.matchId == matchId && !validTeamIds.contains(roster.teamId)
        }

        if let teamA {
            upsertTournamentParticipant(tournamentId: matches[index].tournamentId, team: teamA)
        }
        if let teamB {
            upsertTournamentParticipant(tournamentId: matches[index].tournamentId, team: teamB)
        }

        updateMatchStatusFromRosters(matchId: matchId)
        refreshTournamentStatus(tournamentId: matches[index].tournamentId)
        syncRemote { gateway in
            _ = try await gateway.assignTeams(
                matchID: matchId.uuidString.lowercased(),
                teamAID: teamAId?.uuidString.lowercased(),
                teamBID: teamBId?.uuidString.lowercased()
            )
        }
        return true
    }

    @discardableResult
    func updateMatchOutcome(
        matchId: UUID,
        winnerSide: DebateSide?,
        resultNote: String,
        bestDebaterPosition: String?
    ) -> Bool {
        guard let index = matches.firstIndex(where: { $0.id == matchId }) else { return false }
        guard canCurrentUserManageMatch(index: index) else { return false }

        matches[index].winnerSide = winnerSide
        switch winnerSide {
        case .affirmative:
            matches[index].winnerTeamId = matches[index].teamAId
            matches[index].status = .finished
            matches[index].resultRecordedAt = Date()
        case .negative:
            matches[index].winnerTeamId = matches[index].teamBId
            matches[index].status = .finished
            matches[index].resultRecordedAt = Date()
        case .none:
            matches[index].winnerTeamId = nil
            matches[index].resultRecordedAt = nil
        }

        let trimmedNote = resultNote.trimmingCharacters(in: .whitespacesAndNewlines)
        matches[index].resultNote = trimmedNote.isEmpty ? nil : trimmedNote

        let trimmedBest = bestDebaterPosition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        matches[index].bestDebaterPosition = trimmedBest.isEmpty ? nil : trimmedBest
        return true
    }

    @discardableResult
    func assignTeams(matchId: UUID, teamAId: UUID, teamBId: UUID) -> Bool {
        setMatchTeams(matchId: matchId, teamAId: teamAId, teamBId: teamBId)
    }

    @discardableResult
    func advanceMatchStatus(matchId: UUID, to newStatus: MatchStatus) -> Bool {
        guard let index = matches.firstIndex(where: { $0.id == matchId }) else { return false }
        guard canCurrentUserManageTournament(tournamentId: matches[index].tournamentId) else { return false }

        let current = matches[index].status
        let isAllowed: Bool = {
            switch (current, newStatus) {
            case (_, _) where current == newStatus:
                return true
            case (.scheduled, .ready), (.scheduled, .ongoing), (.scheduled, .finished):
                return true
            case (.ready, .ongoing), (.ready, .finished):
                return true
            case (.ongoing, .finished):
                return true
            case (.finished, .finished):
                return true
            default:
                return false
            }
        }()

        guard isAllowed else { return false }
        matches[index].status = newStatus
        refreshTournamentStatus(tournamentId: matches[index].tournamentId)
        syncRemote { gateway in
            _ = try await gateway.advanceMatch(
                matchID: matchId.uuidString.lowercased(),
                status: self.matchStatusString(newStatus)
            )
        }
        return true
    }

    @discardableResult
    func recordMatchResult(
        matchId: UUID,
        winnerTeamId: UUID,
        teamAScore: Int,
        teamBScore: Int
    ) -> Bool {
        guard let index = matches.firstIndex(where: { $0.id == matchId }) else { return false }
        guard canCurrentUserManageTournament(tournamentId: matches[index].tournamentId) else { return false }
        guard matches[index].teamAId == winnerTeamId || matches[index].teamBId == winnerTeamId else {
            return false
        }

        matches[index].winnerTeamId = winnerTeamId
        matches[index].winnerSide = (winnerTeamId == matches[index].teamAId) ? .affirmative : .negative
        matches[index].teamAScore = teamAScore
        matches[index].teamBScore = teamBScore
        matches[index].resultRecordedAt = Date()
        matches[index].status = .finished
        refreshTournamentStatus(tournamentId: matches[index].tournamentId)
        syncRemote { gateway in
            _ = try await gateway.recordResult(
                matchID: matchId.uuidString.lowercased(),
                winnerTeamID: winnerTeamId.uuidString.lowercased(),
                teamAScore: teamAScore,
                teamBScore: teamBScore,
                resultNote: self.matches[index].resultNote,
                bestDebaterPosition: self.matches[index].bestDebaterPosition
            )
        }
        return true
    }

    // MARK: - Rosters
    @discardableResult
    func saveRoster(matchId: UUID, teamId: UUID, assignments: [RosterAssignment]) -> Bool {
        guard let match = matches.first(where: { $0.id == matchId }) else { return false }
        guard match.teamAId == teamId || match.teamBId == teamId else { return false }
        guard canCurrentUserManageTeam(teamId: teamId) else { return false }
        guard let team = team(by: teamId) else { return false }

        let allowedPositions = Set(match.format.positions)
        let allowedUserIds = Set(team.members.map(\.userId))

        var seenUsers = Set<UUID>()
        var seenPositions = Set<String>()
        var normalized: [RosterAssignment] = []

        for assignment in assignments {
            let position = assignment.position.trimmingCharacters(in: .whitespacesAndNewlines)
            guard allowedUserIds.contains(assignment.userId) else { return false }
            guard allowedPositions.contains(position) else { return false }
            guard seenUsers.insert(assignment.userId).inserted else { return false }
            guard seenPositions.insert(position).inserted else { return false }
            normalized.append(RosterAssignment(userId: assignment.userId, position: position))
        }

        guard normalized.count <= match.format.positions.count else { return false }

        rosters.removeAll { $0.matchId == matchId && $0.teamId == teamId }
        rosters.append(contentsOf: normalized.map { assignment in
            Roster(
                id: UUID(),
                matchId: matchId,
                teamId: teamId,
                userId: assignment.userId,
                position: assignment.position,
                user: team.members.first(where: { $0.userId == assignment.userId })?.user
            )
        })

        updateMatchStatusFromRosters(matchId: matchId)
        refreshTournamentStatus(tournamentId: match.tournamentId)
        syncRemote { gateway in
            _ = try await gateway.saveRoster(
                matchID: matchId.uuidString.lowercased(),
                teamID: teamId.uuidString.lowercased(),
                assignments: normalized
            )
        }
        return true
    }

    // 兼容旧调用。
    func saveRosters(_ newRosters: [Roster]) {
        struct RosterGroupKey: Hashable {
            let matchId: UUID
            let teamId: UUID
        }

        let grouped = Dictionary(grouping: newRosters) {
            RosterGroupKey(matchId: $0.matchId, teamId: $0.teamId)
        }
        for (key, records) in grouped {
            let assignments = records.map { RosterAssignment(userId: $0.userId, position: $0.position) }
            _ = saveRoster(matchId: key.matchId, teamId: key.teamId, assignments: assignments)
        }
    }

    func rosterEntries(matchId: UUID, teamId: UUID) -> [Roster] {
        rosters
            .filter { $0.matchId == matchId && $0.teamId == teamId }
            .sorted { $0.position < $1.position }
    }

    // MARK: - Derived
    func myTeamIds() -> Set<UUID> {
        Set(teams.filter { team in
            team.members.contains { $0.userId == currentUser.id }
        }.map(\.id))
    }

    func myMatches() -> [Match] {
        matches(forUser: currentUser.id)
    }

    func matches(forSource source: ScheduleSource) -> [Match] {
        switch source.kind {
        case .me:
            return myMatches()
        case .person:
            guard let targetId = source.targetId else { return [] }
            return matches(forUser: targetId)
        case .team:
            guard let targetId = source.targetId else { return [] }
            return matches(forTeam: targetId)
        case .tournament:
            guard let targetId = source.targetId else { return [] }
            return matches(for: targetId)
        }
    }

    func matches(forTeam teamId: UUID) -> [Match] {
        matches
            .filter { $0.teamAId == teamId || $0.teamBId == teamId }
            .sorted { $0.startTime < $1.startTime }
    }

    func myTeamMembers(excludingCurrentUser: Bool = true) -> [User] {
        let teamIds = myTeamIds()
        let members = teams
            .filter { teamIds.contains($0.id) }
            .flatMap(\.members)

        var seen = Set<UUID>()
        return members.compactMap { member in
            guard seen.insert(member.userId).inserted else { return nil }
            guard !excludingCurrentUser || member.userId != currentUser.id else { return nil }
            return member.user
        }
    }

    func tournamentShortCode(for tournamentId: UUID) -> String {
        String(tournamentId.uuidString.prefix(8)).uppercased()
    }

    func acknowledgeInboxMessage(id: UUID) {
        guard let index = inboxMessages.firstIndex(where: { $0.id == id }) else { return }
        guard inboxMessages[index].isAcknowledged == false else { return }
        inboxMessages[index].isAcknowledged = true
        syncRemote { gateway in
            try await gateway.acknowledgeMessage(messageID: id.uuidString.lowercased())
        }
    }

    func updateCurrentUserProfile(nickname: String, avatarImageData: Data? = nil) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentUser.nickname = trimmed

        if let avatarImageData {
            let oldAvatarPath = currentUser.avatarUrl
            if let newAvatarPath = storeUserAvatar(avatarImageData, userId: currentUser.id) {
                currentUser.avatarUrl = newAvatarPath
                if let oldAvatarPath, oldAvatarPath != newAvatarPath {
                    try? FileManager.default.removeItem(atPath: oldAvatarPath)
                }
            }
        }

        syncCurrentUserSnapshot()
        syncRemote { gateway in
            try await gateway.updateProfile(
                nickname: trimmed,
                avatarURL: self.currentUser.avatarUrl
            )
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

    private func allUsers() -> [User] {
        let candidates = [currentUser] + teams.flatMap(\.members).map(\.user) + discoverableTeams.flatMap(\.members).map(\.user)
        var seen = Set<UUID>()
        return candidates.filter { user in
            seen.insert(user.id).inserted
        }
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

    private func syncCurrentUserSnapshot() {
        for teamIndex in teams.indices {
            for memberIndex in teams[teamIndex].members.indices where teams[teamIndex].members[memberIndex].userId == currentUser.id {
                teams[teamIndex].members[memberIndex] = TeamMember(
                    id: teams[teamIndex].members[memberIndex].id,
                    teamId: teams[teamIndex].members[memberIndex].teamId,
                    userId: teams[teamIndex].members[memberIndex].userId,
                    role: teams[teamIndex].members[memberIndex].role,
                    joinTime: teams[teamIndex].members[memberIndex].joinTime,
                    user: currentUser
                )
            }
        }

        for teamIndex in discoverableTeams.indices {
            for memberIndex in discoverableTeams[teamIndex].members.indices where discoverableTeams[teamIndex].members[memberIndex].userId == currentUser.id {
                discoverableTeams[teamIndex].members[memberIndex] = TeamMember(
                    id: discoverableTeams[teamIndex].members[memberIndex].id,
                    teamId: discoverableTeams[teamIndex].members[memberIndex].teamId,
                    userId: discoverableTeams[teamIndex].members[memberIndex].userId,
                    role: discoverableTeams[teamIndex].members[memberIndex].role,
                    joinTime: discoverableTeams[teamIndex].members[memberIndex].joinTime,
                    user: currentUser
                )
            }
        }
    }

    private func updateMatchStatusFromRosters(matchId: UUID) {
        guard let matchIndex = matches.firstIndex(where: { $0.id == matchId }) else { return }
        guard matches[matchIndex].status != .ongoing, matches[matchIndex].status != .finished else { return }

        guard let teamAId = matches[matchIndex].teamAId, let teamBId = matches[matchIndex].teamBId else {
            matches[matchIndex].status = .scheduled
            return
        }

        let required = matches[matchIndex].format.positions.count
        let teamACount = rosterEntries(matchId: matchId, teamId: teamAId).count
        let teamBCount = rosterEntries(matchId: matchId, teamId: teamBId).count

        matches[matchIndex].status = (teamACount >= required && teamBCount >= required) ? .ready : .scheduled
    }

    private func upsertTournamentParticipant(tournamentId: UUID, team: Team) {
        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentId }) else { return }

        if let existingIndex = tournaments[tournamentIndex].participants.firstIndex(where: { $0.teamId == team.id }) {
            tournaments[tournamentIndex].participants[existingIndex].status = .confirmed
            tournaments[tournamentIndex].participants[existingIndex].team = team
            return
        }

        let nextSeed = (tournaments[tournamentIndex].participants.map(\.seed).max() ?? -1) + 1
        let participant = TournamentParticipant(
            id: UUID(),
            tournamentId: tournamentId,
            teamId: team.id,
            status: .confirmed,
            seed: nextSeed,
            team: team
        )
        tournaments[tournamentIndex].participants.append(participant)
    }

    private static func shouldEnableRemoteGateway() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["BLM_REMOTE_DISABLED"] == "1" {
            return false
        }
        if env["XCTestConfigurationFilePath"] != nil {
            return false
        }
        return true
    }

    private func scheduleRemoteRefresh() {
        guard remoteGateway != nil else { return }
        remoteRefreshTask?.cancel()
        remoteRefreshTask = Task { [weak self] in
            await self?.refreshFromRemote()
        }
    }

    private func syncRemote(_ operation: @escaping (RemoteGateway) async throws -> Void) {
        guard let remoteGateway else { return }
        Task { [weak self] in
            do {
                _ = try await remoteGateway.ensureSession()
                try await operation(remoteGateway)
                await self?.refreshFromRemote()
            } catch {
                // Keep local-first UX when remote sync fails.
            }
        }
    }

    private func refreshFromRemote() async {
        guard let remoteGateway else { return }
        do {
            let snapshot = try await remoteGateway.bootstrap()
            applyRemoteSnapshot(snapshot)
        } catch {
            // Ignore remote errors and keep current local state.
        }
    }

    private func applyRemoteSnapshot(_ snapshot: RemoteSnapshot) {
        var usersByID: [UUID: User] = [:]

        func mergeUser(_ user: User) {
            usersByID[user.id] = user
        }

        func userFromAPI(_ api: APIUser) -> User? {
            guard let id = uuid(api.id) else { return nil }
            return User(
                id: id,
                publicId: api.publicId,
                nickname: api.nickname,
                avatarUrl: api.avatarUrl,
                status: UserStatus(rawValue: api.status) ?? .normal
            )
        }

        if let remoteCurrent = userFromAPI(snapshot.currentUser) {
            mergeUser(remoteCurrent)
            currentUser = remoteCurrent
        }

        for request in snapshot.joinRequests {
            guard let applicantID = uuid(request.applicantUserId) else { continue }
            mergeUser(
                User(
                    id: applicantID,
                    publicId: request.applicantPublicId,
                    nickname: request.applicantNickname,
                    avatarUrl: nil,
                    status: .normal
                )
            )
        }

        for team in snapshot.myTeams + snapshot.discoverTeams {
            for member in team.members {
                guard let memberUserID = uuid(member.userId) else { continue }
                mergeUser(
                    User(
                        id: memberUserID,
                        publicId: member.publicId,
                        nickname: member.nickname,
                        avatarUrl: nil,
                        status: .normal
                    )
                )
            }
        }

        func teamFromAPI(_ api: APITeam) -> Team? {
            guard let id = uuid(api.id), let ownerID = uuid(api.ownerId) else { return nil }
            let members: [TeamMember] = api.members.compactMap { member in
                guard
                    let memberID = uuid(member.id),
                    let userID = uuid(member.userId)
                else {
                    return nil
                }
                let user = usersByID[userID] ?? User(
                    id: userID,
                    publicId: member.publicId,
                    nickname: member.nickname,
                    avatarUrl: nil,
                    status: .normal
                )
                return TeamMember(
                    id: memberID,
                    teamId: id,
                    userId: userID,
                    role: TeamRole(rawValue: member.role) ?? .member,
                    joinTime: member.joinTime,
                    user: user
                )
            }
            return Team(
                id: id,
                publicId: api.publicId,
                name: api.name,
                slogan: api.intro,
                about: api.intro,
                avatarStyle: .paw,
                avatarUrl: api.avatarUrl,
                ownerId: ownerID,
                status: TeamStatus(rawValue: api.status) ?? .normal,
                members: members
            )
        }

        let mappedMyTeams = snapshot.myTeams.compactMap(teamFromAPI)
        let myTeamIDs = Set(mappedMyTeams.map(\.id))
        let mappedDiscoverTeams = snapshot.discoverTeams.compactMap(teamFromAPI).filter { !myTeamIDs.contains($0.id) }
        let allTeamsByID = Dictionary(uniqueKeysWithValues: (mappedMyTeams + mappedDiscoverTeams).map { ($0.id, $0) })

        let mappedRequests: [TeamJoinRequest] = snapshot.joinRequests.compactMap { request in
            guard
                let id = uuid(request.id),
                let teamID = uuid(request.teamId),
                let applicantID = uuid(request.applicantUserId)
            else {
                return nil
            }
            return TeamJoinRequest(
                id: id,
                teamId: teamID,
                teamPublicId: request.teamPublicId,
                teamName: request.teamName,
                applicantUserId: applicantID,
                applicantPublicId: request.applicantPublicId,
                applicantNickname: request.applicantNickname,
                personalNote: request.personalNote,
                reason: request.reason ?? "",
                createdAt: request.createdAt,
                status: teamJoinRequestStatus(request.status),
                reviewedAt: request.reviewedAt,
                reviewedByUserId: request.reviewedByUserId.flatMap(uuid),
                reviewedByNickname: request.reviewedByNickname
            )
        }

        let mappedMessages: [InboxMessage] = snapshot.messages.compactMap { message in
            guard let id = uuid(message.id) else { return nil }
            return InboxMessage(
                id: id,
                kind: inboxMessageKind(message.kind),
                title: message.title,
                subtitle: message.subtitle,
                createdAt: message.createdAt,
                isAcknowledged: message.isAcknowledged,
                relatedMatchId: message.relatedMatchId.flatMap(uuid)
            )
        }

        let mappedTournaments: [Tournament] = snapshot.tournaments.compactMap { tournament in
            guard
                let id = uuid(tournament.id),
                let creatorID = uuid(tournament.creatorId)
            else {
                return nil
            }

            let participants: [TournamentParticipant] = tournament.participants.compactMap { item in
                guard let participantID = uuid(item.id), let teamID = uuid(item.teamId) else { return nil }
                return TournamentParticipant(
                    id: participantID,
                    tournamentId: id,
                    teamId: teamID,
                    status: tournamentParticipantStatus(item.status),
                    seed: item.seed,
                    team: allTeamsByID[teamID]
                )
            }

            return Tournament(
                id: id,
                name: tournament.name,
                intro: tournament.intro,
                coverUrl: tournament.coverUrl,
                creatorId: creatorID,
                status: TournamentStatus(rawValue: tournament.status) ?? .open,
                participants: participants
            )
        }

        var mappedRosters: [Roster] = []
        let mappedMatches: [Match] = snapshot.matches.compactMap { match in
            guard
                let id = uuid(match.id),
                let tournamentID = uuid(match.tournamentId)
            else {
                return nil
            }

            let teamAID = match.teamAId.flatMap(uuid)
            let teamBID = match.teamBId.flatMap(uuid)
            let winnerTeamID = match.winnerTeamId.flatMap(uuid)
            let winnerSide: DebateSide? = {
                if winnerTeamID == teamAID { return .affirmative }
                if winnerTeamID == teamBID { return .negative }
                return nil
            }()

            for roster in match.rosters {
                guard
                    let rosterID = uuid(roster.id),
                    let teamID = uuid(roster.teamId),
                    let userID = uuid(roster.userId)
                else {
                    continue
                }
                mappedRosters.append(
                    Roster(
                        id: rosterID,
                        matchId: id,
                        teamId: teamID,
                        userId: userID,
                        position: roster.position,
                        user: usersByID[userID]
                    )
                )
            }

            return Match(
                id: id,
                tournamentId: tournamentID,
                name: match.name,
                topic: match.topic,
                startTime: match.startTime,
                endTime: match.endTime,
                location: match.location,
                opponentTeamName: match.opponentTeamName,
                teamAId: teamAID,
                teamBId: teamBID,
                format: matchFormatFromBackend(match.format),
                status: matchStatus(match.status),
                winnerSide: winnerSide,
                winnerTeamId: winnerTeamID,
                teamAScore: match.teamAScore,
                teamBScore: match.teamBScore,
                resultRecordedAt: match.resultRecordedAt,
                resultNote: match.resultNote,
                bestDebaterPosition: match.bestDebaterPosition,
                teamA: teamAID.flatMap { allTeamsByID[$0] },
                teamB: teamBID.flatMap { allTeamsByID[$0] }
            )
        }

        teams = mappedMyTeams
        discoverableTeams = mappedDiscoverTeams
        teamJoinRequests = mappedRequests
        inboxMessages = mappedMessages
        tournaments = mappedTournaments
        matches = mappedMatches
        rosters = mappedRosters
    }

    private func uuid(_ raw: String) -> UUID? {
        UUID(uuidString: raw.lowercased())
    }

    private func teamJoinRequestStatus(_ raw: String) -> TeamJoinRequestStatus {
        switch raw {
        case "approved":
            return .approved
        case "rejected":
            return .rejected
        default:
            return .pending
        }
    }

    private func inboxMessageKind(_ raw: String) -> InboxMessageKind {
        switch raw {
        case "application":
            return .application
        case "statusChange":
            return .statusChange
        default:
            return .notification
        }
    }

    private func tournamentParticipantStatus(_ raw: String) -> TournamentParticipantStatus {
        switch raw {
        case "confirmed":
            return .confirmed
        case "rejected":
            return .rejected
        default:
            return .pending
        }
    }

    private func matchStatus(_ raw: String) -> MatchStatus {
        switch raw {
        case "ready":
            return .ready
        case "ongoing":
            return .ongoing
        case "finished":
            return .finished
        default:
            return .scheduled
        }
    }

    private func matchStatusString(_ status: MatchStatus) -> String {
        switch status {
        case .scheduled:
            return "scheduled"
        case .ready:
            return "ready"
        case .ongoing:
            return "ongoing"
        case .finished:
            return "finished"
        }
    }

    private func matchFormatFromBackend(_ raw: String) -> MatchFormat {
        switch raw {
        case "1v1", MatchFormat.f1v1.rawValue:
            return .f1v1
        case "2v2", MatchFormat.f2v2.rawValue:
            return .f2v2
        case "4v4", MatchFormat.f4v4.rawValue:
            return .f4v4
        case "3v3", MatchFormat.f3v3.rawValue:
            return .f3v3
        default:
            return .f3v3
        }
    }

}
