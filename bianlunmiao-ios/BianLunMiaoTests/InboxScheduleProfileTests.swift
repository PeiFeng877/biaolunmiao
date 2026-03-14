//
//  InboxScheduleProfileTests.swift
//  BianLunMiaoTests
//
//  Created by Codex on 2026/2/13.
//  Updated by Codex on 2026/3/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 消息聚合、日程数据源与资料编辑能力。
//  OUTPUT: 核心状态聚合与动作回写断言。
//  POS: 消息/日程/我的模块单测。
//

import Foundation
import Testing
@testable import BianLunMiao

@MainActor
struct InboxScheduleProfileTests {
    @Test
    func inboxBuildsUnifiedMessageFeed() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)

        #expect(!viewModel.feedItems.isEmpty)

        let joinRequests = viewModel.feedItems.compactMap { item -> TeamJoinRequest? in
            guard case .joinRequest(let request) = item else { return nil }
            return request
        }
        let systemMessages = viewModel.feedItems.compactMap { item -> InboxMessage? in
            guard case .system(let message) = item else { return nil }
            return message
        }

        #expect(!joinRequests.isEmpty)
        #expect(!systemMessages.isEmpty)
        #expect(systemMessages.allSatisfy { $0.kind == .notification || $0.kind == .statusChange })
    }

    @Test
    func systemMessageIsDisplayOnlyInFeedModel() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)
        guard let target = viewModel.feedItems.compactMap({ item -> InboxMessage? in
            guard case .system(let message) = item else { return nil }
            return message
        }).first else {
            Issue.record("缺少系统消息")
            return
        }

        let messageInStore = store.inboxMessages.first(where: { $0.id == target.id })
        #expect(messageInStore?.isAcknowledged == target.isAcknowledged)
    }

    @Test
    func messageFeedSortsByDescendingTime() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)

        let sortedTimes = viewModel.feedItems.map(\.sortTime)
        for index in 1..<sortedTimes.count {
            #expect(sortedTimes[index - 1] >= sortedTimes[index])
        }
    }

    @Test
    func scheduleDefaultsToEnabledMeSource() {
        let defaults = UserDefaults(suiteName: "schedule_test_defaults_1")!
        defaults.removePersistentDomain(forName: "schedule_test_defaults_1")

        let store = AppStore(mock: MockData())
        let viewModel = ScheduleViewModel(store: store, defaults: defaults)

        let meSource = viewModel.sources.first(where: { $0.kind == .me })
        #expect(meSource != nil)
        #expect(meSource?.isEnabled == true)
        #expect(viewModel.enabledSources.count == 1)
    }

    @Test
    func addSourceIsEnabledByDefault() {
        let defaults = UserDefaults(suiteName: "schedule_test_defaults_2")!
        defaults.removePersistentDomain(forName: "schedule_test_defaults_2")

        let store = AppStore(mock: MockData())
        let viewModel = ScheduleViewModel(store: store, defaults: defaults)

        guard let team = store.teams.first else {
            Issue.record("缺少可用队伍")
            return
        }

        let added = viewModel.addSource(kind: .team, targetId: team.id, name: team.name)
        #expect(added)

        let source = viewModel.sources.first(where: { $0.kind == .team && $0.targetId == team.id })
        #expect(source?.isEnabled == true)
    }

    @Test
    func mergedMatchesDeduplicatesAcrossSources() {
        let defaults = UserDefaults(suiteName: "schedule_test_defaults_3")!
        defaults.removePersistentDomain(forName: "schedule_test_defaults_3")

        let store = AppStore(mock: MockData())
        guard let team = store.teams.first else {
            Issue.record("缺少可用队伍")
            return
        }

        let viewModel = ScheduleViewModel(store: store, defaults: defaults)
        _ = viewModel.addSource(kind: .team, targetId: team.id, name: team.name)

        let uniqueIds = Set(viewModel.mergedMatches.map(\.id))
        #expect(uniqueIds.count == viewModel.mergedMatches.count)
    }

    @Test
    func dayPreviewCapsAtTwoAndShowsOverflow() async throws {
        let defaults = UserDefaults(suiteName: "schedule_test_defaults_4")!
        defaults.removePersistentDomain(forName: "schedule_test_defaults_4")

        let store = AppStore(mock: MockData())
        guard let teamA = store.teams.first,
              let teamB = store.searchableTeams().first(where: { $0.id != teamA.id }) else {
            Issue.record("缺少可用队伍")
            return
        }

        let tournament = try await store.createTournament(name: "同日密集赛", intro: "测试")
        let baseDate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600 * 9)

        for index in 0..<3 {
            let start = baseDate.addingTimeInterval(Double(index * 3600))
            let draft = MatchDraft(
                name: "同日场次\(index)",
                startTime: start,
                endTime: start.addingTimeInterval(3000),
                location: "线上",
                format: .f3v3
            )
            let match = store.createMatch(tournamentId: tournament.id, draft: draft)
            _ = store.assignTeams(matchId: match.id, teamAId: teamA.id, teamBId: teamB.id)
        }

        let viewModel = ScheduleViewModel(store: store, defaults: defaults)
        _ = viewModel.addSource(kind: .team, targetId: teamA.id, name: teamA.name)

        let preview = viewModel.dayPreview(on: baseDate)
        #expect(preview.titles.count == 2)
        #expect(preview.overflowCount >= 1)
    }

    @Test
    func openDayDetailSwitchesFromMonthToDayMode() {
        let defaults = UserDefaults(suiteName: "schedule_test_defaults_5")!
        defaults.removePersistentDomain(forName: "schedule_test_defaults_5")

        let store = AppStore(mock: MockData())
        let viewModel = ScheduleViewModel(store: store, defaults: defaults)

        #expect(viewModel.presentationMode == .month)

        let targetDate = Date().addingTimeInterval(86400)
        viewModel.openDayDetail(for: targetDate)

        #expect(viewModel.presentationMode == .dayDetail)
        #expect(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: targetDate))
    }

    @Test
    func profileFinishedMatchesIncludeOnlyMineAndSortByStartTimeDescending() async throws {
        let store = AppStore(mock: MockData())
        guard let myTeam = store.teams.first,
              let opponentTeam = store.searchableTeams().first(where: { $0.id != myTeam.id }) else {
            Issue.record("缺少可用队伍")
            return
        }

        let tournament = try await store.createTournament(name: "我的完赛测试", intro: "用于时间轴排序")
        let baseStart = Date().addingTimeInterval(24 * 60 * 60)

        func createFinishedMatch(name: String, hourOffset: Int, teamAScore: Int, teamBScore: Int) {
            let start = baseStart.addingTimeInterval(TimeInterval(hourOffset * 60 * 60))
            let draft = MatchDraft(
                name: name,
                startTime: start,
                endTime: start.addingTimeInterval(AppStore.fixedMatchDuration),
                location: "线上赛场",
                format: .f3v3
            )
            let match = store.createMatch(tournamentId: tournament.id, draft: draft)

            #expect(store.assignTeams(matchId: match.id, teamAId: myTeam.id, teamBId: opponentTeam.id))
            #expect(
                store.saveRoster(
                    matchId: match.id,
                    teamId: myTeam.id,
                    assignments: [RosterAssignment(userId: store.currentUser.id, position: "一辩")]
                )
            )
            #expect(
                store.recordMatchResult(
                    matchId: match.id,
                    winnerTeamId: myTeam.id,
                    teamAScore: teamAScore,
                    teamBScore: teamBScore
                )
            )
        }

        createFinishedMatch(name: "时间轴场次-较早", hourOffset: 1, teamAScore: 3, teamBScore: 1)
        createFinishedMatch(name: "时间轴场次-较晚", hourOffset: 4, teamAScore: 4, teamBScore: 2)

        let viewModel = ProfileSettingsViewModel(store: store)
        #expect(viewModel.finishedMatches.allSatisfy { $0.status == .finished })

        guard let first = viewModel.finishedMatches.first,
              let second = viewModel.finishedMatches.dropFirst().first else {
            Issue.record("时间轴数据不足")
            return
        }

        #expect(first.name == "时间轴场次-较晚")
        #expect(second.name == "时间轴场次-较早")
    }

    @Test
    func profileMatchFormattingFallbacksAreStable() {
        let store = AppStore(mock: MockData())
        let viewModel = ProfileSettingsViewModel(store: store)

        let fallbackMatch = Match(
            id: UUID(),
            tournamentId: UUID(),
            name: "兜底场次",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            location: nil,
            teamAId: nil,
            teamBId: nil,
            format: .f3v3,
            status: .finished,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: nil,
            teamB: nil
        )

        #expect(viewModel.tournamentName(for: fallbackMatch) == "未关联赛事")
        #expect(viewModel.teamsLine(for: fallbackMatch) == "待定队伍 vs 待定队伍")
        #expect(viewModel.winnerText(for: fallbackMatch) == "未录入")
        #expect(viewModel.scoreText(for: fallbackMatch) == "未录入")
    }

    @Test
    func requiredProfileUsesDefaultNicknameWhenAvatarNotChanged() async throws {
        let store = AppStore(mock: MockData())
        let viewModel = ProfileSettingsViewModel(store: store)

        viewModel.prepareProfileDraft()
        viewModel.avatarDraftData = nil

        let saveResult = try await viewModel.saveProfile(completesPostLoginSetup: true)

        #expect(saveResult)
        #expect(store.currentUser.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    @Test
    func requiredProfileStillRejectsBlankNickname() async throws {
        let store = AppStore(mock: MockData())
        let viewModel = ProfileSettingsViewModel(store: store)

        viewModel.prepareProfileDraft()
        viewModel.nicknameDraft = "  "

        #expect(try await !viewModel.saveProfile(completesPostLoginSetup: true))
    }

    @Test
    func debugForceNewUserFlowToggleWritesThroughViewModel() {
        let key = "debug.force.new.user.flow"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let store = AppStore(mock: MockData())
        let viewModel = ProfileSettingsViewModel(store: store)

        #expect(viewModel.isForceNewUserFlowEnabled == true)

        viewModel.setForceNewUserFlowEnabled(true)
        #expect(viewModel.isForceNewUserFlowEnabled == true)

        viewModel.setForceNewUserFlowEnabled(false)
        #expect(viewModel.isForceNewUserFlowEnabled == true)
    }

    @Test
    func updateCurrentUserProfileUpdatesSnapshot() async throws {
        let store = AppStore(mock: MockData())
        let updatedNickname = "新培风"

        try await store.updateCurrentUserProfile(nickname: updatedNickname)

        #expect(store.currentUser.nickname == updatedNickname)

        let linkedMember = store.teams
            .flatMap(\.members)
            .first(where: { $0.userId == store.currentUser.id })
        #expect(linkedMember?.user.nickname == updatedNickname)
    }

    @Test
    func updateCurrentUserProfileSupportsAvatarUpdate() async throws {
        let store = AppStore(mock: MockData())
        let updatedNickname = "头像测试用户"
        let avatarData = Data([0x42, 0x4C, 0x4D])

        try await store.updateCurrentUserProfile(nickname: updatedNickname, avatarImageData: avatarData)

        #expect(store.currentUser.nickname == updatedNickname)
        #expect(store.currentUser.avatarUrl != nil)

        if let avatarPath = store.currentUser.avatarUrl {
            #expect(FileManager.default.fileExists(atPath: avatarPath))
            try? FileManager.default.removeItem(atPath: avatarPath)
        }

        let linkedMember = store.teams
            .flatMap(\.members)
            .first(where: { $0.userId == store.currentUser.id })
        #expect(linkedMember?.user.avatarUrl == store.currentUser.avatarUrl)
    }
}
