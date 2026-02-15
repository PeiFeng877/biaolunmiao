//
//  ScheduleSourceManagementView.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 日程数据源状态与搜索入口。
//  OUTPUT: 个人/队伍/赛事三类数据源管理页。
//  POS: 日程数据源管理页面。
//

import SwiftUI

struct ScheduleSourceManagementView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: ScheduleViewModel

    @State private var selectedTab: ScheduleSourceManagementTab = .person
    @State private var showPicker = false
    @State private var pendingRemovalSource: ScheduleSource?
    @State private var showRemoveConfirmation = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                AppDetailTopBar(title: "日历管理", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        Picker("数据源类型", selection: $selectedTab) {
                            ForEach(ScheduleSourceManagementTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("schedule_source_tab_segmented")

                        if displayedSources.isEmpty {
                            AppCard {
                                AppEmptyState(
                                    title: "暂无关注\(selectedTab.rawValue)",
                                    subtitle: "点击右下角添加按钮后会立即在主日历生效",
                                    systemImage: "calendar.badge.plus"
                                )
                            }
                        } else {
                            VStack(spacing: AppSpacing.s) {
                                ForEach(displayedSources) { source in
                                    sourceRow(source)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, 120)
                }
            }

            floatingAddButton
        }
        .toolbar(.hidden, for: .navigationBar)
        .appSheet(isPresented: $showPicker) {
            ScheduleSourcePickerSheet(viewModel: viewModel, tab: selectedTab)
        }
        .appAlert("确认移除", isPresented: $showRemoveConfirmation) {
            AppMenuAction("取消", role: .cancel) {
                pendingRemovalSource = nil
            }
            AppMenuAction("移除", role: .destructive) {
                guard let source = pendingRemovalSource else { return }
                viewModel.removeSource(id: source.id)
                pendingRemovalSource = nil
            }
        } message: {
            if let source = pendingRemovalSource {
                Text("确定移除“\(source.name)”吗？移除后该数据源赛事将不再显示。")
            } else {
                Text("确定移除该数据源吗？")
            }
        }
    }

    private var displayedSources: [ScheduleSource] {
        viewModel.sources(for: selectedTab)
    }

    private func sourceRow(_ source: ScheduleSource) -> some View {
        AppCard {
            HStack(spacing: AppSpacing.s) {
                Button {
                    viewModel.toggleSource(id: source.id, isEnabled: !source.isEnabled)
                } label: {
                    Image(systemName: source.isEnabled ? "checkmark.square.fill" : "square")
                        .font(AppFont.icon())
                        .foregroundStyle(source.isEnabled ? AppColor.primaryStrong : AppColor.textSecondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 0) {
                    Text(source.name)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if viewModel.canDeleteSource(source) {
                    AppButton("移除", variant: .toolbarText) {
                        pendingRemovalSource = source
                        showRemoveConfirmation = true
                    }
                }
            }
        }
    }

    private var floatingAddButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                AppRowTapButton {
                    showPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(AppColor.primaryStrong)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(AppColor.stroke, lineWidth: 2)
                        )
                        .shadow(
                            color: AppShadow.standard.color,
                            radius: 0,
                            x: AppShadow.standard.x,
                            y: AppShadow.standard.y
                        )
                }
                .accessibilityIdentifier("schedule_source_add_button")
            }
            .padding(.horizontal, AppSpacing.inset)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}
