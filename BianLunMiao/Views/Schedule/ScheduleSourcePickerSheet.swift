//
//  ScheduleSourcePickerSheet.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 日程数据源搜索结果。
//  OUTPUT: 添加关注对象的搜索弹窗。
//  POS: 日历管理子流程。
//

import SwiftUI

struct ScheduleSourcePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: ScheduleViewModel
    let tab: ScheduleSourceManagementTab

    @State private var query = ""
    @State private var toast: AppToastPayload?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppSearchBar(
                            text: $query,
                            placeholder: placeholder,
                            style: .standard
                        )
                        .accessibilityIdentifier("schedule_source_picker_search_input")

                        if candidates.isEmpty {
                            AppCard {
                                AppEmptyState(
                                    title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请输入关键词" : "未找到结果",
                                    subtitle: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "可按 ID 或名称搜索" : "试试完整 ID 或更短关键词",
                                    systemImage: "magnifyingglass"
                                )
                            }
                        } else {
                            VStack(spacing: AppSpacing.s) {
                                ForEach(candidates) { candidate in
                                    sourceCandidateRow(candidate)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("添加\(tab.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .appToast(item: $toast)
        }
    }

    private var candidates: [ScheduleSourceCandidate] {
        viewModel.searchCandidates(tab: tab, query: query)
    }

    private var placeholder: String {
        switch tab {
        case .person:
            return "输入用户 ID 或昵称"
        case .team:
            return "输入队伍 ID 或名称"
        case .tournament:
            return "输入赛事 ID 或名称"
        }
    }

    private func sourceCandidateRow(_ candidate: ScheduleSourceCandidate) -> some View {
        let alreadyAdded = viewModel.isSourceAdded(for: candidate)

        return AppCard {
            HStack(spacing: AppSpacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.name)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)

                    Text(candidate.subtitle)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer(minLength: 0)

                if alreadyAdded {
                    Text("已关注")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    AppButton("添加", variant: .compactSecondary) {
                        guard viewModel.addSource(candidate: candidate) else { return }
                        toast = AppToastPayload(title: "已添加", message: candidate.name, intent: .success)
                        dismiss()
                    }
                    .accessibilityIdentifier("schedule_source_picker_add_button")
                }
            }
        }
    }
}
