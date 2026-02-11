//
//  TeamJoinRequestFlowTests.swift
//  BianLunMiaoTests
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
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
    func submitRequestSuccessCreatesPendingRecord() {
        let store = AppStore(mock: MockData())
        let initialCount = store.teamJoinRequests.count
        guard let team = store.discoverableTeams.first else {
            Issue.record("缺少可申请队伍")
            return
        }

        let result = store.submitTeamJoinRequest(
            teamPublicId: team.publicId,
            personalNote: "培风",
            reason: "我想参加训练"
        )

        switch result {
        case .success(let request):
            #expect(request.status == .pending)
            #expect(request.teamId == team.id)
            #expect(request.personalNote == "培风")
            #expect(store.teamJoinRequests.count == initialCount + 1)
        case .failure(let error):
            Issue.record("提交申请失败：\(error.rawValue)")
        }
    }

    @Test
    func duplicatePendingRequestIsRejected() {
        let store = AppStore(mock: MockData())
        guard let team = store.discoverableTeams.first else {
            Issue.record("缺少可申请队伍")
            return
        }

        _ = store.submitTeamJoinRequest(teamPublicId: team.publicId, personalNote: "培风", reason: "")
        let second = store.submitTeamJoinRequest(teamPublicId: team.publicId, personalNote: "培风", reason: "")

        switch second {
        case .success:
            Issue.record("重复提交应被拦截")
        case .failure(let error):
            #expect(error == .duplicatePending)
        }
    }

    @Test
    func emptyPersonalNoteIsRejected() {
        let store = AppStore(mock: MockData())
        guard let team = store.discoverableTeams.first else {
            Issue.record("缺少可申请队伍")
            return
        }

        let result = store.submitTeamJoinRequest(teamPublicId: team.publicId, personalNote: "   ", reason: "")
        switch result {
        case .success:
            Issue.record("空备注应被拦截")
        case .failure(let error):
            #expect(error == .invalidRemark)
        }
    }

    @Test
    func approveRequestAddsMemberToTeam() {
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
        let result = store.reviewTeamJoinRequest(requestId: request.id, decision: .approve)

        switch result {
        case .success(let updated):
            #expect(updated.status == .approved)
            guard let teamAfter = store.searchableTeams().first(where: { $0.id == request.teamId }) else {
                Issue.record("审批后队伍不存在")
                return
            }
            #expect(teamAfter.members.count == memberCountBefore + 1)
            #expect(teamAfter.members.contains(where: { $0.userId == request.applicantUserId }))
        case .failure(let error):
            Issue.record("审批通过失败：\(error.rawValue)")
        }
    }

    @Test
    func rejectRequestKeepsTeamMembersUnchanged() {
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
        let result = store.reviewTeamJoinRequest(requestId: request.id, decision: .reject)

        switch result {
        case .success(let updated):
            #expect(updated.status == .rejected)
            guard let teamAfter = store.searchableTeams().first(where: { $0.id == request.teamId }) else {
                Issue.record("审批后队伍不存在")
                return
            }
            #expect(teamAfter.members.count == memberCountBefore)
        case .failure(let error):
            Issue.record("审批拒绝失败：\(error.rawValue)")
        }
    }

    @Test
    func nonAdminCannotReviewRequest() {
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

        let result = store.reviewTeamJoinRequest(requestId: request.id, decision: .approve)
        switch result {
        case .success:
            Issue.record("无权限用户不应通过审批")
        case .failure(let error):
            #expect(error == .unauthorized)
        }
    }

    @Test
    func messageInboxBuildsIncomingAndOutgoingSections() {
        let store = AppStore(mock: MockData())
        let viewModel = MessageInboxViewModel(store: store)

        #expect(!viewModel.incoming.isEmpty)
        #expect(!viewModel.outgoing.isEmpty)
        #expect(viewModel.incoming.allSatisfy { $0.status == .pending })
        #expect(viewModel.outgoing.allSatisfy { $0.status != .pending && $0.applicantUserId == store.currentUser.id })
    }
}
