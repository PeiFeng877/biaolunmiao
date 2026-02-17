//
//  InboxMessage.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 站内消息展示与确认需求。
//  OUTPUT: InboxMessage 模型与消息类别枚举。
//  POS: 模型层-消息域。
//

import Foundation

enum InboxMessageKind: String, Codable, CaseIterable {
    case application
    case notification
    case statusChange

    var title: String {
        switch self {
        case .application:
            return "待处理"
        case .notification:
            return "通知"
        case .statusChange:
            return "状态变更"
        }
    }
}

struct InboxMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: InboxMessageKind
    var title: String
    var subtitle: String
    let createdAt: Date
    var isAcknowledged: Bool
    var relatedMatchId: UUID?
}
