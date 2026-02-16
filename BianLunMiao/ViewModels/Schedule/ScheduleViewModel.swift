//
//  ScheduleViewModel.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的比赛、队伍、用户与赛事数据。
//  OUTPUT: 日程页面状态机（月视图/日详情）与数据源管理状态。
//  POS: 日程视图模型。
//

import Foundation
import Combine

enum SchedulePresentationMode: Equatable {
    case month
    case dayDetail
}

enum ScheduleSourceManagementTab: String, CaseIterable, Identifiable {
    case person = "个人"
    case team = "队伍"
    case tournament = "赛事"

    var id: String { rawValue }
}

struct ScheduleSourceCandidate: Identifiable, Hashable {
    let kind: ScheduleSourceKind
    let targetId: UUID
    let name: String
    let subtitle: String

    var id: String {
        "\(kind.rawValue)-\(targetId.uuidString)"
    }
}

struct ScheduleDayPreview {
    let titles: [String]
    let overflowCount: Int
}



@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var visibleMonthAnchor: Date
    @Published var presentationMode: SchedulePresentationMode = .month

    @Published private(set) var sources: [ScheduleSource] = []
    @Published private(set) var mergedMatches: [Match] = []
    @Published private(set) var groupedMatches: [Date: [Match]] = [:]
    @Published private(set) var dayMatches: [Match] = []
    @Published private(set) var monthAnchors: [Date] = []

    private let store: AppStore
    private let calendar: Calendar
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private static let sourceStorageKey = "schedule.sources.v1"
    private static let meSourceId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init(
        store: AppStore,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.calendar = calendar
        self.defaults = defaults

        let today = calendar.startOfDay(for: Date())
        self.selectedDate = today
        self.visibleMonthAnchor = calendar.startOfMonth(for: today)

        self.sources = Self.loadSources(from: defaults)
        normalizeAndPersistSources()
        rebuildMatches()
        rebuildMonthAnchors()

        let refreshTrigger = Publishers.MergeMany(
            store.$matches.map { _ in () }.eraseToAnyPublisher(),
            store.$rosters.map { _ in () }.eraseToAnyPublisher(),
            store.$teams.map { _ in () }.eraseToAnyPublisher(),
            store.$discoverableTeams.map { _ in () }.eraseToAnyPublisher(),
            store.$tournaments.map { _ in () }.eraseToAnyPublisher(),
            store.$currentUser.map { _ in () }.eraseToAnyPublisher()
        )

        refreshTrigger
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAll()
            }
            .store(in: &cancellables)
    }

    var myMatches: [Match] {
        store.myMatches()
    }

    var selectedDayTitle: String {
        selectedDate.formatted(.dateTime.year().month().day())
    }

    var monthOverlayTitle: String {
        visibleMonthAnchor.formatted(.dateTime.year().month())
    }

    var enabledSources: [ScheduleSource] {
        sources.filter(\.isEnabled)
    }

    func openDayDetail(for date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        presentationMode = .dayDetail
        refreshDayMatches()
    }

    func openMonthMode() {
        visibleMonthAnchor = calendar.startOfMonth(for: selectedDate)
        presentationMode = .month
    }

    func goToToday() {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        visibleMonthAnchor = calendar.startOfMonth(for: today)
        refreshDayMatches()
    }

    func updateVisibleMonthAnchor(_ date: Date) {
        visibleMonthAnchor = calendar.startOfMonth(for: date)
    }

    func matches(on date: Date) -> [Match] {
        groupedMatches[calendar.startOfDay(for: date)] ?? []
    }

    func dayPreview(on date: Date, limit: Int = 2) -> ScheduleDayPreview {
        let titles = matches(on: date).map(\.name)
        let capped = Array(titles.prefix(limit))
        let overflow = max(titles.count - limit, 0)
        return ScheduleDayPreview(titles: capped, overflowCount: overflow)
    }

    func tournamentName(for match: Match) -> String? {
        store.tournament(id: match.tournamentId)?.name
    }

    func teamsLine(for match: Match) -> String {
        let resolvedTeamAName = match.teamA?.name ?? match.teamAId.flatMap { store.team(by: $0)?.name }
        let resolvedTeamBName = match.teamB?.name ?? match.teamBId.flatMap { store.team(by: $0)?.name }
        let opponentName = match.opponentTeamName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let resolvedTeamAName, let resolvedTeamBName {
            return "\(resolvedTeamAName) vs \(resolvedTeamBName)"
        }

        if let resolvedTeamAName, let opponentName, !opponentName.isEmpty {
            return "\(resolvedTeamAName) vs \(opponentName)"
        }

        if let opponentName, !opponentName.isEmpty {
            return "我方 vs \(opponentName)"
        }

        let fallbackTeamA = resolvedTeamAName ?? "待定队伍"
        let fallbackTeamB = resolvedTeamBName ?? "待定队伍"
        return "\(fallbackTeamA) vs \(fallbackTeamB)"
    }

    func sources(for tab: ScheduleSourceManagementTab) -> [ScheduleSource] {
        switch tab {
        case .person:
            return sources.filter { $0.kind == .person }.sorted { $0.name < $1.name }
        case .team:
            return sources.filter { $0.kind == .team }.sorted { $0.name < $1.name }
        case .tournament:
            return sources.filter { $0.kind == .tournament }.sorted { $0.name < $1.name }
        }
    }

    func canDeleteSource(_ source: ScheduleSource) -> Bool {
        source.kind != .me
    }

    func toggleSource(id: UUID, isEnabled: Bool) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }

        if sources[index].kind == .me {
            sources[index].isEnabled = true
        } else {
            sources[index].isEnabled = isEnabled
        }

        persistSources()
        rebuildMatches()
        rebuildMonthAnchors()
    }

    func removeSource(id: UUID) {
        guard let source = sources.first(where: { $0.id == id }), source.kind != .me else { return }
        sources.removeAll { $0.id == id }
        persistSources()
        rebuildMatches()
        rebuildMonthAnchors()
    }

    func searchCandidates(tab: ScheduleSourceManagementTab, query: String) -> [ScheduleSourceCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch tab {
        case .person:
            return store.searchableUsers(query: trimmed)
                .filter { $0.id != store.currentUser.id }
                .map {
                    ScheduleSourceCandidate(
                        kind: .person,
                        targetId: $0.id,
                        name: $0.nickname,
                        subtitle: "ID: \($0.publicId)"
                    )
                }

        case .team:
            return store.searchableTeams()
                .filter {
                    $0.name.localizedStandardContains(trimmed) ||
                    $0.publicId.localizedStandardContains(trimmed)
                }
                .sorted { $0.name < $1.name }
                .map {
                    ScheduleSourceCandidate(
                        kind: .team,
                        targetId: $0.id,
                        name: $0.name,
                        subtitle: "ID: \($0.publicId)"
                    )
                }

        case .tournament:
            return store.searchableTournaments(query: trimmed)
                .map {
                    ScheduleSourceCandidate(
                        kind: .tournament,
                        targetId: $0.id,
                        name: $0.name,
                        subtitle: "ID: \(store.tournamentShortCode(for: $0.id))"
                    )
                }
        }
    }

    func isSourceAdded(for candidate: ScheduleSourceCandidate) -> Bool {
        sources.contains { source in
            source.kind == candidate.kind && source.targetId == candidate.targetId
        }
    }

    @discardableResult
    func addSource(candidate: ScheduleSourceCandidate) -> Bool {
        addSource(kind: candidate.kind, targetId: candidate.targetId, name: candidate.name)
    }

    @discardableResult
    func addSource(kind: ScheduleSourceKind, targetId: UUID?, name: String) -> Bool {
        guard kind != .me else { return false }
        guard let targetId else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let exists = sources.contains { source in
            source.kind == kind && source.targetId == targetId
        }
        guard !exists else { return false }

        sources.append(
            ScheduleSource(
                id: UUID(),
                kind: kind,
                targetId: targetId,
                name: trimmedName,
                isEnabled: true
            )
        )

        persistSources()
        rebuildMatches()
        rebuildMonthAnchors()
        return true
    }

    private func refreshAll() {
        normalizeAndPersistSources()
        rebuildMatches()
        rebuildMonthAnchors()
    }

    private func rebuildMatches() {
        var dedup = [UUID: Match]()

        for source in enabledSources {
            for match in store.matches(forSource: source) {
                dedup[match.id] = match
            }
        }

        mergedMatches = dedup.values.sorted { lhs, rhs in
            if lhs.startTime == rhs.startTime {
                return lhs.name < rhs.name
            }
            return lhs.startTime < rhs.startTime
        }

        groupedMatches = Dictionary(grouping: mergedMatches) { match in
            calendar.startOfDay(for: match.startTime)
        }
        .mapValues { $0.sorted { $0.startTime < $1.startTime } }

        refreshDayMatches()
    }

    private func refreshDayMatches() {
        dayMatches = matches(on: selectedDate)
    }

    private func rebuildMonthAnchors() {
        let todayMonth = calendar.startOfMonth(for: Date())
        let selectedMonth = calendar.startOfMonth(for: selectedDate)
        let mergedMonths = mergedMatches.map { calendar.startOfMonth(for: $0.startTime) }

        let minMonth = ([todayMonth, selectedMonth] + mergedMonths).min() ?? todayMonth
        let maxMonth = ([todayMonth, selectedMonth] + mergedMonths).max() ?? todayMonth

        let startMonth = calendar.date(byAdding: .month, value: -6, to: minMonth) ?? minMonth
        let endMonth = calendar.date(byAdding: .month, value: 12, to: maxMonth) ?? maxMonth

        var anchors: [Date] = []
        var cursor = startMonth
        while cursor <= endMonth {
            anchors.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }

        monthAnchors = anchors

        if !monthAnchors.contains(visibleMonthAnchor) {
            visibleMonthAnchor = selectedMonth
        }
    }

    private func normalizeAndPersistSources() {
        var normalized: [ScheduleSource] = []

        let meSource = ScheduleSource(
            id: Self.meSourceId,
            kind: .me,
            targetId: nil,
            name: "我的赛事",
            isEnabled: true
        )
        normalized.append(meSource)

        for source in sources where source.kind != .me {
            guard let targetId = source.targetId else { continue }
            guard let resolvedName = resolveName(for: source.kind, targetId: targetId) else { continue }

            let exists = normalized.contains { existing in
                existing.kind == source.kind && existing.targetId == source.targetId
            }
            guard !exists else { continue }

            normalized.append(
                ScheduleSource(
                    id: source.id,
                    kind: source.kind,
                    targetId: targetId,
                    name: resolvedName,
                    isEnabled: source.isEnabled
                )
            )
        }

        if normalized != sources {
            sources = normalized
        }

        persistSources()
    }

    private func resolveName(for kind: ScheduleSourceKind, targetId: UUID) -> String? {
        switch kind {
        case .me:
            return "我的赛事"
        case .person:
            return store.searchableUsers(query: "").first(where: { $0.id == targetId })?.nickname
        case .team:
            return store.searchableTeams().first(where: { $0.id == targetId })?.name
        case .tournament:
            return store.tournament(id: targetId)?.name
        }
    }

    private func persistSources() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: Self.sourceStorageKey)
    }

    private static func loadSources(from defaults: UserDefaults) -> [ScheduleSource] {
        guard let data = defaults.data(forKey: sourceStorageKey),
              let decoded = try? JSONDecoder().decode([ScheduleSource].self, from: data) else {
            return [
                ScheduleSource(
                    id: meSourceId,
                    kind: .me,
                    targetId: nil,
                    name: "我的赛事",
                    isEnabled: true
                )
            ]
        }
        return decoded
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
