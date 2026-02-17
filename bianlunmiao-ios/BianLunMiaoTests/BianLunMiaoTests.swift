//
//  BianLunMiaoTests.swift
//  BianLunMiaoTests
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 应用核心模块的可测行为。
//  OUTPUT: 单元级行为断言结果。
//  POS: 单元测试入口层。
//

import Testing
import Foundation
@testable import BianLunMiao

struct BianLunMiaoTests {

    @Test func example() async throws {
        // 基础占位测试，保留用于快速连通性校验。
    }
}

@MainActor
struct TournamentFlowTests {
    @Test
    func createTournamentAndMatchPersistsInStore() {
        let store = AppStore(mock: MockData())
        let tournament = store.createTournament(name: "闭环测试赛事", intro: "用于单测")

        let draft = MatchDraft(
            name: "第一轮",
            startTime: Date().addingTimeInterval(7200),
            endTime: Date().addingTimeInterval(10800),
            location: "线上",
            format: .f3v3
        )
        let match = store.createMatch(tournamentId: tournament.id, draft: draft)

        #expect(store.tournament(id: tournament.id) != nil)
        #expect(store.matches(for: tournament.id).contains(where: { $0.id == match.id }))
    }

    @Test
    func readyOnlyAfterBothTeamsSavedRoster() {
        let store = AppStore(mock: MockData())
        guard let setup = makeAssignedMatch(store: store) else {
            Issue.record("无法初始化测试赛程")
            return
        }

        let required = setup.match.format.positions
        let teamAAssignments = makeAssignments(team: setup.teamA, positions: required)
        #expect(store.saveRoster(matchId: setup.match.id, teamId: setup.teamA.id, assignments: teamAAssignments))

        guard let ownerOfTeamB = setup.teamB.members.first(where: { $0.role == .owner })?.user else {
            Issue.record("缺少 B 队队长")
            return
        }
        store.currentUser = ownerOfTeamB

        let teamBAssignments = makeAssignments(team: setup.teamB, positions: required)
        #expect(store.saveRoster(matchId: setup.match.id, teamId: setup.teamB.id, assignments: teamBAssignments))

        guard let updated = store.matches(for: setup.tournament.id).first(where: { $0.id == setup.match.id }) else {
            Issue.record("缺少更新后的赛程")
            return
        }
        #expect(updated.status == .ready)
    }

    @Test
    func adminCanAssignButMemberCannot() {
        let store = AppStore(mock: MockData())
        guard let setup = makeAssignedMatch(store: store) else {
            Issue.record("无法初始化测试赛程")
            return
        }

        guard let admin = setup.teamA.members.first(where: { $0.role == .admin })?.user,
              let member = setup.teamA.members.first(where: { $0.role == .member })?.user else {
            Issue.record("缺少管理员或普通成员")
            return
        }

        let required = setup.match.format.positions
        let assignments = makeAssignments(team: setup.teamA, positions: required)

        store.currentUser = admin
        #expect(store.saveRoster(matchId: setup.match.id, teamId: setup.teamA.id, assignments: assignments))

        store.currentUser = member
        #expect(!store.saveRoster(matchId: setup.match.id, teamId: setup.teamA.id, assignments: assignments))
    }

    @Test
    func recordResultStoresWinnerAndScores() {
        let store = AppStore(mock: MockData())
        guard let setup = makeAssignedMatch(store: store) else {
            Issue.record("无法初始化测试赛程")
            return
        }

        #expect(store.advanceMatchStatus(matchId: setup.match.id, to: .ongoing))
        #expect(store.advanceMatchStatus(matchId: setup.match.id, to: .finished))
        #expect(store.recordMatchResult(matchId: setup.match.id, winnerTeamId: setup.teamA.id, teamAScore: 9, teamBScore: 7))

        guard let updated = store.matches(for: setup.tournament.id).first(where: { $0.id == setup.match.id }) else {
            Issue.record("缺少更新后的赛程")
            return
        }

        #expect(updated.winnerTeamId == setup.teamA.id)
        #expect(updated.teamAScore == 9)
        #expect(updated.teamBScore == 7)
        #expect(updated.status == .finished)
    }

    @Test
    func saveRosterOverridesInsteadOfAppending() {
        let store = AppStore(mock: MockData())
        guard let setup = makeAssignedMatch(store: store) else {
            Issue.record("无法初始化测试赛程")
            return
        }

        let positions = setup.match.format.positions
        let first = makeAssignments(team: setup.teamA, positions: Array(positions.prefix(2)))
        #expect(store.saveRoster(matchId: setup.match.id, teamId: setup.teamA.id, assignments: first))

        let second = makeAssignments(team: setup.teamA, positions: [positions[0]])
        #expect(store.saveRoster(matchId: setup.match.id, teamId: setup.teamA.id, assignments: second))

        let finalEntries = store.rosterEntries(matchId: setup.match.id, teamId: setup.teamA.id)
        #expect(finalEntries.count == 1)
        #expect(finalEntries.first?.userId == second.first?.userId)
    }

    @Test
    func scheduleViewModelShowsOnlyAssignedMatches() {
        let store = AppStore(mock: MockData())
        guard let setup = makeAssignedMatch(store: store) else {
            Issue.record("无法初始化测试赛程")
            return
        }

        let required = setup.match.format.positions
        let assignments = makeAssignments(team: setup.teamA, positions: required)
        #expect(store.saveRoster(matchId: setup.match.id, teamId: setup.teamA.id, assignments: assignments))

        guard let assignedUserId = assignments.first?.userId,
              let assignedUser = setup.teamA.members.first(where: { $0.userId == assignedUserId })?.user,
              let unassignedUser = setup.teamA.members.first(where: { !assignments.map(\.userId).contains($0.userId) })?.user else {
            Issue.record("缺少可用测试用户")
            return
        }

        store.currentUser = assignedUser
        let assignedViewModel = ScheduleViewModel(store: store)
        #expect(assignedViewModel.myMatches.contains(where: { $0.id == setup.match.id }))

        store.currentUser = unassignedUser
        let unassignedViewModel = ScheduleViewModel(store: store)
        #expect(!unassignedViewModel.myMatches.contains(where: { $0.id == setup.match.id }))
    }

    private func makeAssignedMatch(store: AppStore) -> (tournament: Tournament, match: Match, teamA: Team, teamB: Team)? {
        guard let teamA = store.teams.first,
              let teamB = store.searchableTeams().first(where: { $0.id != teamA.id }) else {
            return nil
        }

        let tournament = store.createTournament(name: "流程闭环赛", intro: "测试")
        let draft = MatchDraft(
            name: "初赛第一场",
            startTime: Date().addingTimeInterval(7200),
            endTime: Date().addingTimeInterval(10800),
            location: "线上会议室",
            format: .f3v3
        )
        let match = store.createMatch(tournamentId: tournament.id, draft: draft)
        guard store.assignTeams(matchId: match.id, teamAId: teamA.id, teamBId: teamB.id) else {
            return nil
        }
        return (tournament, match, teamA, teamB)
    }

    private func makeAssignments(team: Team, positions: [String]) -> [RosterAssignment] {
        Array(zip(team.members.prefix(positions.count), positions)).map { member, position in
            RosterAssignment(userId: member.userId, position: position)
        }
    }
}
