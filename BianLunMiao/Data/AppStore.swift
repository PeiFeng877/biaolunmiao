//
//  AppStore.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
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

    init(mock: MockData = .shared) {
        self.currentUser = mock.currentUser
        self.teams = mock.myTeams
        self.discoverableTeams = mock.discoverableTeams
        self.teamJoinRequests = mock.teamJoinRequests
        self.inboxMessages = mock.inboxMessages
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

}
