//
//  TeamJoinRequest.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 入队申请提交与审批链路的数据需求。
//  OUTPUT: TeamJoinRequest 及相关状态、错误、结果枚举。
//  POS: 模型层-队伍申请域。
//

import Foundation

enum TeamJoinRequestStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case rejected

    var title: String {
        switch self {
        case .pending:
            return "待处理"
        case .approved:
            return "已通过"
        case .rejected:
            return "已拒绝"
        }
    }
}

enum TeamJoinRequestDecision: Equatable {
    case approve
    case reject
}

enum TeamJoinRequestError: String, Error, Equatable {
    case invalidId = "请输入队伍 ID"
    case invalidRemark = "请输入个人备注"
    case notFound = "未找到对应记录"
    case alreadyMember = "申请人已在该队伍中"
    case duplicatePending = "你已提交申请，请等待审批"
    case unauthorized = "你没有审批权限"
    case alreadyProcessed = "该申请已处理"
}

enum TeamJoinRequestSubmitResult {
    case success(TeamJoinRequest)
    case failure(TeamJoinRequestError)
}

enum TeamJoinRequestReviewResult {
    case success(TeamJoinRequest)
    case failure(TeamJoinRequestError)
}

struct TeamJoinRequest: Identifiable, Codable, Hashable {
    let id: UUID
    let teamId: UUID
    let teamPublicId: String
    let teamName: String

    let applicantUserId: UUID
    let applicantPublicId: String
    let applicantNickname: String

    var personalNote: String
    var reason: String

    let createdAt: Date
    var status: TeamJoinRequestStatus
    var reviewedAt: Date?
    var reviewedByUserId: UUID?
    var reviewedByNickname: String?
}
