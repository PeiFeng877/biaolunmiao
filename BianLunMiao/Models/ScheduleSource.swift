//
//  ScheduleSource.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 日程数据源类型定义。
//  OUTPUT: 日程来源模型（个人/队伍/赛事）与启用状态。
//  POS: 模型层-赛程域。
//

import Foundation

enum ScheduleSourceKind: String, Codable, CaseIterable {
    case me
    case person
    case team
    case tournament

    var title: String {
        switch self {
        case .me:
            return "我"
        case .person:
            return "个人"
        case .team:
            return "队伍"
        case .tournament:
            return "赛事"
        }
    }
}

struct ScheduleSource: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: ScheduleSourceKind
    let targetId: UUID?
    let name: String
    var isEnabled: Bool
}
