//
//  TournamentPublishViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 发布赛事所需的摘要数据。
//  OUTPUT: 发布页面状态。
//  POS: 赛事发布视图模型。
//

import Foundation
import Combine

final class TournamentPublishViewModel: ObservableObject {
    struct Summary: Hashable {
        let tournamentName: String
        let roundsCount: Int
        let dateRange: String
        let location: String
    }

    @Published private(set) var summary: Summary

    init(summary: Summary) {
        self.summary = summary
    }
}
