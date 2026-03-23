//
//  TournamentDetailViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: AppStore 与赛事 ID。
//  OUTPUT: 赛事管理页展示状态。
//  POS: 赛事详情视图模型。
//

import Foundation
import Combine



@MainActor
final class TournamentDetailViewModel: ObservableObject {
    enum TeamSide: String, CaseIterable {
        case affirmative = "正方"
        case negative = "反方"
    }

    enum WinnerResult: String, CaseIterable {
        case none = "无结果"
        case affirmative = "正方胜"
        case negative = "反方胜"
    }

    struct LineupSlot: Identifiable, Hashable {
        var id: String { position }
        let position: String
        var userId: UUID?
    }

    struct MatchForm: Hashable {
        var name: String
        var topic: String
        var startTime: Date
        var location: String
        var format: MatchFormat
        var myTeamId: UUID?
        var mySide: TeamSide
        var opponentTeamName: String
        var lineup: [LineupSlot]
        var winnerResult: WinnerResult
        var resultNote: String
        var bestDebaterPosition: String?

        static func createDefault() -> MatchForm {
            let start = Date().addingTimeInterval(3600)
            return MatchForm(
                name: "",
                topic: "",
                startTime: start,
                location: "",
                format: .f3v3,
                myTeamId: nil,
                mySide: .affirmative,
                opponentTeamName: "",
                lineup: .empty(for: .f3v3),
                winnerResult: .none,
                resultNote: "",
                bestDebaterPosition: nil
            )
        }

        init(
            name: String,
            topic: String,
            startTime: Date,
            location: String,
            format: MatchFormat,
            myTeamId: UUID?,
            mySide: TeamSide,
            opponentTeamName: String,
            lineup: [LineupSlot],
            winnerResult: WinnerResult,
            resultNote: String,
            bestDebaterPosition: String?
        ) {
            self.name = name
            self.topic = topic
            self.startTime = startTime
            self.location = location
            self.format = format
            self.myTeamId = myTeamId
            self.mySide = mySide
            self.opponentTeamName = opponentTeamName
            self.lineup = lineup
            self.winnerResult = winnerResult
            self.resultNote = resultNote
            self.bestDebaterPosition = bestDebaterPosition
        }
    }

    @Published private(set) var tournament: Tournament
    @Published private(set) var matches: [Match] = []

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

        Publishers.CombineLatest(store.$tournaments, store.$matches)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    var canManage: Bool {
        store.canCurrentUserManageTournament(tournamentId: tournamentId)
    }

    var canManageSchedule: Bool {
        !manageableTeams.isEmpty
    }

    var manageableTeams: [Team] {
        store.searchableTeams()
            .filter { store.canCurrentUserManageTeam(teamId: $0.id) }
            .sorted(by: teamSortOrder(_:_:))
    }

    var managedTeam: Team? {
        manageableTeams.first
    }

    var managedTeamMembers: [TeamMember] {
        managedTeamMembers(for: defaultManagedTeamId())
    }

    @discardableResult
    func updateTournamentInfo(name: String, intro: String, status: TournamentStatus) async throws -> Bool {
        try await store.updateTournament(tournamentId: tournamentId, name: name, intro: intro, status: status)
    }

    func createMatchForm() -> MatchForm {
        let teamId = defaultManagedTeamId()
        var form = MatchForm.createDefault()
        form.myTeamId = teamId
        form.lineup = defaultLineup(for: teamId, format: form.format)
        return form
    }

    func editMatchForm(for match: Match) -> MatchForm {
        let currentTeamId = selectedManagedTeamId(for: match)
        let side: TeamSide
        if match.teamAId == currentTeamId {
            side = .affirmative
        } else if match.teamBId == currentTeamId {
            side = .negative
        } else {
            side = .affirmative
        }

        let opponentNameFromTeam: String = {
            if side == .affirmative {
                return teamName(for: match.teamBId)
            }
            return teamName(for: match.teamAId)
        }()
        let opponentName = match.opponentTeamName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedOpponentName = (opponentName?.isEmpty == false) ? (opponentName ?? "") : opponentNameFromTeam

        let rosterByPosition: [String: UUID] = {
            guard let managedTeamId = currentTeamId else { return [:] }
            return Dictionary(uniqueKeysWithValues: store.rosterEntries(matchId: match.id, teamId: managedTeamId).map { ($0.position, $0.userId) })
        }()

        let rosterLineup = match.format.positions.map { position in
            LineupSlot(position: position, userId: rosterByPosition[position])
        }
        let hasAssignedLineup = rosterLineup.contains { $0.userId != nil }
        let resolvedLineup: [LineupSlot] = hasAssignedLineup
            ? rosterLineup
            : defaultLineup(for: currentTeamId, format: match.format)

        return MatchForm(
            name: match.name,
            topic: match.topic ?? "",
            startTime: match.startTime,
            location: match.location ?? "",
            format: match.format,
            myTeamId: currentTeamId,
            mySide: side,
            opponentTeamName: resolvedOpponentName,
            lineup: resolvedLineup,
            winnerResult: winnerResult(for: match),
            resultNote: match.resultNote ?? "",
            bestDebaterPosition: match.bestDebaterPosition
        )
    }

    func syncLineupSlots(_ form: inout MatchForm) {
        let old = Dictionary(uniqueKeysWithValues: form.lineup.map { ($0.position, $0.userId) })
        form.lineup = form.format.positions.map { position in
            LineupSlot(position: position, userId: old[position] ?? nil)
        }
        let validBest = Set(bestDebaterOptions(for: form.format))
        if let selected = form.bestDebaterPosition, !validBest.contains(selected) {
            form.bestDebaterPosition = nil
        }
    }

    @discardableResult
    func saveMatch(form: MatchForm, editingMatchId: UUID?) -> Bool {
        guard canManageSchedule else { return false }
        let managedTeamId = form.myTeamId ?? defaultManagedTeamId()
        guard let managedTeamId else { return false }

        let trimmedName = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let trimmedTopic = form.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpponent = form.opponentTeamName.trimmingCharacters(in: .whitespacesAndNewlines)

        let selected = form.lineup.compactMap { slot in
            slot.userId.map { (slot.position, $0) }
        }
        guard selected.count == form.format.positions.count else { return false }

        let uniqueUserIds = Set(selected.map { $0.1 })
        guard uniqueUserIds.count == selected.count else { return false }

        let draft = MatchDraft(
            name: trimmedName,
            startTime: form.startTime,
            endTime: form.startTime.addingTimeInterval(AppStore.fixedMatchDuration),
            location: form.location,
            format: form.format,
            topic: trimmedTopic,
            opponentTeamName: trimmedOpponent
        )
        let assignments = selected.map { position, userId in
            RosterAssignment(userId: userId, position: position)
        }
        let teamAId: UUID? = (form.mySide == .affirmative) ? managedTeamId : nil
        let teamBId: UUID? = (form.mySide == .negative) ? managedTeamId : nil

        let persistMatch: UUID
        if let editingMatchId {
            store.updateMatch(matchId: editingMatchId, draft: draft)
            persistMatch = editingMatchId
        } else {
            let created = store.createMatch(tournamentId: tournamentId, draft: draft)
            persistMatch = created.id
        }

        guard store.setMatchTeams(matchId: persistMatch, teamAId: teamAId, teamBId: teamBId) else {
            return false
        }
        guard store.saveRoster(matchId: persistMatch, teamId: managedTeamId, assignments: assignments) else {
            return false
        }
        guard store.updateMatchOutcome(
            matchId: persistMatch,
            winnerSide: winnerSide(for: form.winnerResult),
            resultNote: form.resultNote,
            bestDebaterPosition: form.bestDebaterPosition
        ) else {
            return false
        }
        return true
    }

    func defaultManagedTeamId() -> UUID? {
        manageableTeams.first?.id
    }

    func managedTeamMembers(for teamId: UUID?) -> [TeamMember] {
        guard let teamId else { return [] }
        return team(by: teamId)?.members.sorted(by: memberSortOrder(_:_:)) ?? []
    }

    func defaultLineup(for teamId: UUID?, format: MatchFormat) -> [LineupSlot] {
        let members = managedTeamMembers(for: teamId).map(\.userId)
        return format.positions.enumerated().map { index, position in
            LineupSlot(position: position, userId: index < members.count ? members[index] : nil)
        }
    }

    func bestDebaterOptions(for format: MatchFormat) -> [String] {
        let positions = format.positions
        let affirmative = positions.map { "正方\($0)" }
        let negative = positions.map { "反方\($0)" }
        return affirmative + negative
    }

    var participantTeams: [Team] {
        tournament.confirmedTeams
    }

    var introText: String {
        let trimmed = tournament.intro?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "暂无赛事简介" : trimmed
    }

    var statusText: String {
        tournament.status.title
    }

    var statusColor: ColorToken {
        switch tournament.status {
        case .open:
            return .primary
        case .ongoing:
            return .info
        case .ended:
            return .secondary
        }
    }

    func myTeamSide(for match: Match) -> TeamSide? {
        guard let managedTeamId = selectedManagedTeamId(for: match) else { return nil }
        if match.teamAId == managedTeamId {
            return .affirmative
        }
        if match.teamBId == managedTeamId {
            return .negative
        }
        return nil
    }

    func teamAName(for match: Match) -> String {
        if let name = team(by: match.teamAId)?.name {
            return name
        }
        if myTeamSide(for: match) == .negative {
            let fallback = match.opponentTeamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fallback.isEmpty { return fallback }
        }
        return "待定"
    }

    func teamBName(for match: Match) -> String {
        if let name = team(by: match.teamBId)?.name {
            return name
        }
        if myTeamSide(for: match) == .affirmative {
            let fallback = match.opponentTeamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fallback.isEmpty { return fallback }
        }
        return "待定"
    }

    func memberName(userId: UUID?) -> String {
        guard let userId else { return "未选择" }
        return managedTeamMembers.first(where: { $0.userId == userId })?.user.nickname ?? "未选择"
    }

    private func selectedManagedTeamId(for match: Match) -> UUID? {
        let managedIds = Set(manageableTeams.map(\.id))
        let teamAId = match.teamAId
        let teamBId = match.teamBId
        let teamAIsManaged = teamAId.map { managedIds.contains($0) } ?? false
        let teamBIsManaged = teamBId.map { managedIds.contains($0) } ?? false

        switch (teamAIsManaged, teamBIsManaged) {
        case (true, false):
            return teamAId
        case (false, true):
            return teamBId
        case (true, true):
            let teamACount = teamAId.map { store.rosterEntries(matchId: match.id, teamId: $0).count } ?? 0
            let teamBCount = teamBId.map { store.rosterEntries(matchId: match.id, teamId: $0).count } ?? 0
            if teamACount != teamBCount {
                return teamACount > teamBCount ? teamAId : teamBId
            }
            return teamAId ?? teamBId
        case (false, false):
            break
        }
        return defaultManagedTeamId()
    }

    private func team(by id: UUID?) -> Team? {
        guard let id else { return nil }
        return store.team(by: id)
    }

    func teamName(for id: UUID?) -> String {
        guard let id else { return "待定" }
        return team(by: id)?.name ?? "待定"
    }

    func refreshNow() async throws {
        try await store.refreshNow(force: true)
    }

    private func teamSortOrder(_ lhs: Team, _ rhs: Team) -> Bool {
        let lhsCreatedAt = lhs.createdAt ?? .distantFuture
        let rhsCreatedAt = rhs.createdAt ?? .distantFuture
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt < rhsCreatedAt
        }
        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.publicId < rhs.publicId
    }

    private func memberSortOrder(_ lhs: TeamMember, _ rhs: TeamMember) -> Bool {
        let nameComparison = lhs.user.nickname.localizedStandardCompare(rhs.user.nickname)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.userId.uuidString < rhs.userId.uuidString
    }

    func scoreText(for match: Match) -> String {
        guard let teamAScore = match.teamAScore, let teamBScore = match.teamBScore else {
            return "未录入"
        }
        return "\(teamAScore) : \(teamBScore)"
    }

    func winnerName(for match: Match) -> String {
        if let side = match.winnerSide {
            return side.rawValue
        }
        return teamName(for: match.winnerTeamId)
    }

    private func winnerResult(for match: Match) -> WinnerResult {
        if let side = match.winnerSide {
            return (side == .affirmative) ? .affirmative : .negative
        }
        if match.winnerTeamId == match.teamAId {
            return .affirmative
        }
        if match.winnerTeamId == match.teamBId {
            return .negative
        }
        return .none
    }

    private func winnerSide(for result: WinnerResult) -> DebateSide? {
        switch result {
        case .none:
            return nil
        case .affirmative:
            return .affirmative
        case .negative:
            return .negative
        }
    }

    private func refresh() {
        if let updated = store.tournament(id: tournamentId) {
            tournament = updated
        }
        matches = store.matches(for: tournamentId)
    }
}

private extension Array where Element == TournamentDetailViewModel.LineupSlot {
    static func empty(for format: MatchFormat) -> [TournamentDetailViewModel.LineupSlot] {
        format.positions.map { position in
            TournamentDetailViewModel.LineupSlot(position: position, userId: nil)
        }
    }
}

enum ColorToken {
    case primary
    case secondary
    case info
    case danger
}
