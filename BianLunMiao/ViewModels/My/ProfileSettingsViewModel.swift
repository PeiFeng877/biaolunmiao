//
//  ProfileSettingsViewModel.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: AppStore 的当前用户与资料更新动作。
//  OUTPUT: 设置页资料、协议入口、编辑资料与完赛记录状态。
//  POS: 我的设置视图模型。
//

import Foundation
import Combine



@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published private(set) var currentUser: User
    @Published private(set) var finishedMatches: [Match] = []
    @Published var nicknameDraft: String = ""
    @Published var avatarDraftData: Data?
    @Published var showEditProfileSheet = false
    @Published var showUserAgreementSheet = false
    @Published var showPrivacyPolicySheet = false

    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()
    private var initialAvatarDraftData: Data?

    init(store: AppStore) {
        self.store = store
        self.currentUser = store.currentUser
        refreshFinishedMatches()

        store.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.refreshFinishedMatches()
            }
            .store(in: &cancellables)

        let refreshTrigger = Publishers.MergeMany(
            store.$matches.map { _ in () }.eraseToAnyPublisher(),
            store.$rosters.map { _ in () }.eraseToAnyPublisher(),
            store.$teams.map { _ in () }.eraseToAnyPublisher(),
            store.$discoverableTeams.map { _ in () }.eraseToAnyPublisher(),
            store.$tournaments.map { _ in () }.eraseToAnyPublisher()
        )

        refreshTrigger
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFinishedMatches()
            }
            .store(in: &cancellables)
    }

    func beginEditProfile() {
        nicknameDraft = currentUser.nickname
        let currentAvatarData = loadCurrentAvatarData()
        avatarDraftData = currentAvatarData
        initialAvatarDraftData = currentAvatarData
        showEditProfileSheet = true
    }

    func cancelEditProfile() {
        nicknameDraft = currentUser.nickname
        avatarDraftData = initialAvatarDraftData
        showEditProfileSheet = false
    }

    @discardableResult
    func saveProfile() -> Bool {
        let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let didAvatarChange = avatarDraftData != initialAvatarDraftData
        store.updateCurrentUserProfile(
            nickname: trimmed,
            avatarImageData: didAvatarChange ? avatarDraftData : nil
        )
        initialAvatarDraftData = avatarDraftData
        showEditProfileSheet = false
        return true
    }

    var canSaveProfileDraft: Bool {
        !nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func tournamentName(for match: Match) -> String {
        store.tournament(id: match.tournamentId)?.name ?? "未关联赛事"
    }

    func teamsLine(for match: Match) -> String {
        let resolvedTeamAName = teamName(for: match.teamAId)
        let resolvedTeamBName = teamName(for: match.teamBId)
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

    func winnerText(for match: Match) -> String {
        if let winnerTeamId = match.winnerTeamId, let winnerTeamName = teamName(for: winnerTeamId) {
            return winnerTeamName
        }
        if let winnerSide = match.winnerSide {
            return winnerSide.rawValue
        }
        return "未录入"
    }

    func scoreText(for match: Match) -> String {
        guard let teamAScore = match.teamAScore, let teamBScore = match.teamBScore else {
            return "未录入"
        }
        return "\(teamAScore) : \(teamBScore)"
    }

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "v\(shortVersion) (\(build))"
    }

    private func refreshFinishedMatches() {
        finishedMatches = store.matches(forUser: currentUser.id)
            .filter { $0.status == .finished }
            .sorted { lhs, rhs in
                if lhs.startTime == rhs.startTime {
                    return lhs.name < rhs.name
                }
                return lhs.startTime > rhs.startTime
            }
    }

    private func teamName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return store.team(by: id)?.name
    }

    private func loadCurrentAvatarData() -> Data? {
        guard let avatarPath = currentUser.avatarUrl, !avatarPath.isEmpty else { return nil }
        if
            let url = URL(string: avatarPath),
            let scheme = url.scheme?.lowercased(),
            (scheme == "http" || scheme == "https")
        {
            return nil
        }
        return try? Data(contentsOf: URL(fileURLWithPath: avatarPath))
    }
}
