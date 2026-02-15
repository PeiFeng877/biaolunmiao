//
//  InboxScheduleProfileTests.swift
//  BianLunMiaoTests
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
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
    func inboxBuildsNotificationAndStatusChangeSections() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)

        #expect(!viewModel.notifications.isEmpty)
        #expect(!viewModel.statusChanges.isEmpty)
        #expect(viewModel.notifications.allSatisfy { $0.kind == .notification })
        #expect(viewModel.statusChanges.allSatisfy { $0.kind == .statusChange })
    }

    @Test
    func acknowledgeMessageUpdatesStoreState() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)
        guard let target = viewModel.notifications.first(where: { !$0.isAcknowledged }) else {
            Issue.record("缺少可确认通知消息")
            return
        }

        viewModel.acknowledgeMessage(id: target.id)

        let updated = store.inboxMessages.first(where: { $0.id == target.id })
        #expect(updated?.isAcknowledged == true)
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
    func dayPreviewCapsAtTwoAndShowsOverflow() {
        let defaults = UserDefaults(suiteName: "schedule_test_defaults_4")!
        defaults.removePersistentDomain(forName: "schedule_test_defaults_4")

        let store = AppStore(mock: MockData())
        guard let teamA = store.teams.first,
              let teamB = store.searchableTeams().first(where: { $0.id != teamA.id }) else {
            Issue.record("缺少可用队伍")
            return
        }

        let tournament = store.createTournament(name: "同日密集赛", intro: "测试")
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
    func updateCurrentUserProfileUpdatesSnapshot() {
        let store = AppStore(mock: MockData())
        let updatedNickname = "新培风"

        store.updateCurrentUserProfile(nickname: updatedNickname)

        #expect(store.currentUser.nickname == updatedNickname)

        let linkedMember = store.teams
            .flatMap(\.members)
            .first(where: { $0.userId == store.currentUser.id })
        #expect(linkedMember?.user.nickname == updatedNickname)
    }
}
