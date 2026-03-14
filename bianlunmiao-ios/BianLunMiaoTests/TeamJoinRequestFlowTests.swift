//
//  TeamJoinRequestFlowTests.swift
//  BianLunMiaoTests
//
//  Updated by Codex on 2026/2/15.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 入队申请提交、审批与消息聚合行为。
//  OUTPUT: 申请状态机核心断言结果。
//  POS: 队伍申请流程单测。
//

import Testing
import Foundation
@testable import BianLunMiao

@MainActor
struct TeamJoinRequestFlowTests {
    @Test
    func submitRequestSuccessCreatesPendingRecord() async throws {
        let store = AppStore(mock: MockData())
        let initialCount = store.teamJoinRequests.count
        guard let team = store.discoverableTeams.first else {
            Issue.record("缺少可申请队伍")
            return
        }

        let request = try await store.submitTeamJoinRequest(
            teamPublicId: team.publicId,
            personalNote: "培风",
            reason: "我想参加训练"
        )

        #expect(request.status == .pending)
        #expect(request.teamId == team.id)
        #expect(request.personalNote == "培风")
        #expect(store.teamJoinRequests.count == initialCount + 1)
    }

    @Test
    func duplicatePendingRequestIsRejected() async throws {
        let store = AppStore(mock: MockData())
        guard let team = store.discoverableTeams.first else {
            Issue.record("缺少可申请队伍")
            return
        }

        _ = try await store.submitTeamJoinRequest(teamPublicId: team.publicId, personalNote: "培风", reason: "")

        do {
            _ = try await store.submitTeamJoinRequest(teamPublicId: team.publicId, personalNote: "培风", reason: "")
            Issue.record("重复提交应被拦截")
        } catch {
            assertActionError(error, equals: .duplicatePending)
        }
    }

    @Test
    func emptyPersonalNoteIsRejected() async throws {
        let store = AppStore(mock: MockData())
        guard let team = store.discoverableTeams.first else {
            Issue.record("缺少可申请队伍")
            return
        }

        do {
            _ = try await store.submitTeamJoinRequest(teamPublicId: team.publicId, personalNote: "   ", reason: "")
            Issue.record("空备注应被拦截")
        } catch {
            assertActionError(error, equals: .invalidRemark)
        }
    }

    @Test
    func approveRequestAddsMemberToTeam() async throws {
        let store = AppStore(mock: MockData())
        guard let request = store.teamJoinRequests.first(where: { $0.status == .pending }) else {
            Issue.record("缺少待审批申请")
            return
        }
        guard let teamBefore = store.searchableTeams().first(where: { $0.id == request.teamId }) else {
            Issue.record("缺少申请目标队伍")
            return
        }

        let memberCountBefore = teamBefore.members.count
        let updated = try await store.reviewTeamJoinRequest(requestId: request.id, decision: .approve)

        #expect(updated.status == .approved)
        guard let teamAfter = store.searchableTeams().first(where: { $0.id == request.teamId }) else {
            Issue.record("审批后队伍不存在")
            return
        }
        #expect(teamAfter.members.count == memberCountBefore + 1)
        #expect(teamAfter.members.contains(where: { $0.userId == request.applicantUserId }))
    }

    @Test
    func rejectRequestKeepsTeamMembersUnchanged() async throws {
        let store = AppStore(mock: MockData())
        guard let request = store.teamJoinRequests.first(where: { $0.status == .pending }) else {
            Issue.record("缺少待审批申请")
            return
        }
        guard let teamBefore = store.searchableTeams().first(where: { $0.id == request.teamId }) else {
            Issue.record("缺少申请目标队伍")
            return
        }

        let memberCountBefore = teamBefore.members.count
        let updated = try await store.reviewTeamJoinRequest(requestId: request.id, decision: .reject)

        #expect(updated.status == .rejected)
        guard let teamAfter = store.searchableTeams().first(where: { $0.id == request.teamId }) else {
            Issue.record("审批后队伍不存在")
            return
        }
        #expect(teamAfter.members.count == memberCountBefore)
    }

    @Test
    func nonAdminCannotReviewRequest() async throws {
        let store = AppStore(mock: MockData())
        guard let team = store.teams.first(where: { $0.publicId == "1002" }) else {
            Issue.record("缺少目标队伍")
            return
        }

        let request = TeamJoinRequest(
            id: UUID(),
            teamId: team.id,
            teamPublicId: team.publicId,
            teamName: team.name,
            applicantUserId: UUID(),
            applicantPublicId: "U9999",
            applicantNickname: "外部申请人",
            personalNote: "外部申请人",
            reason: "希望加入",
            createdAt: Date(),
            status: .pending,
            reviewedAt: nil,
            reviewedByUserId: nil,
            reviewedByNickname: nil
        )
        store.teamJoinRequests.insert(request, at: 0)

        do {
            _ = try await store.reviewTeamJoinRequest(requestId: request.id, decision: .approve)
            Issue.record("无权限用户不应通过审批")
        } catch {
            assertActionError(error, equals: .unauthorized)
        }
    }

    @Test
    func messageInboxBuildsJoinRequestFeedItems() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)

        let joinRequests = viewModel.feedItems.compactMap { item -> TeamJoinRequest? in
            guard case .joinRequest(let request) = item else { return nil }
            return request
        }

        #expect(!joinRequests.isEmpty)
        #expect(joinRequests.contains(where: { $0.status == .pending }))
        #expect(joinRequests.contains(where: { $0.status != .pending && $0.applicantUserId == store.currentUser.id }))
    }

    private func assertActionError(
        _ error: Error,
        equals expected: TeamJoinRequestError
    ) {
        guard let actionError = error as? AppStoreActionError else {
            Issue.record("收到非预期错误类型：\(String(describing: error))")
            return
        }
        #expect(actionError.message == expected.rawValue)
    }
}
