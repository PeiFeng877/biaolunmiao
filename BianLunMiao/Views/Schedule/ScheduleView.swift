//
//  ScheduleView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: ScheduleViewModel 提供的赛程与日历权限。
//  OUTPUT: 个人日程列表与同步入口。
//  POS: 日程 Tab 根页面。
//

import SwiftUI
import EventKit

struct ScheduleView: View {
    @StateObject private var viewModel: ScheduleViewModel
    @State private var showingAlert = false
    @State private var alertMessage = ""

    init(store: AppStore) {
        _viewModel = StateObject(wrappedValue: ScheduleViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                    AppSectionHeader("全部比赛", trailing: "共 \(viewModel.myMatches.count) 场")

                        if viewModel.myMatches.isEmpty {
                            VStack {
                                AppEmptyState(title: "暂无日程", subtitle: "指派完成后会自动出现", systemImage: "calendar")
                            }
                            .padding(AppSpacing.l)
                            .background(AppColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                                    .stroke(AppColor.outline, lineWidth: 1)
                            )
                            .cornerRadius(AppRadius.l)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(viewModel.myMatches) { match in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(match.name)
                                                .font(AppFont.body())
                                                .foregroundColor(AppColor.textPrimary)
                                            Spacer()
                                            Button {
                                                addToCalendar(match: match)
                                            } label: {
                                                Text("添加到日历")
                                                    .font(AppFont.caption())
                                                    .foregroundColor(AppColor.primary)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        Text(match.startTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(AppFont.caption())
                                            .foregroundColor(AppColor.textMuted)

                                        HStack(spacing: 6) {
                                            Image(systemName: "mappin.and.ellipse")
                                                .font(.caption)
                                            Text(match.location ?? "地点待定")
                                                .font(AppFont.caption())
                                        }
                                        .foregroundColor(AppColor.textSecondary)
                                    }
                                    .padding(.vertical, AppSpacing.m)

                                    if match.id != viewModel.myMatches.last?.id {
                                        Divider().overlay(AppColor.outline)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.l)
                            .background(AppColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                                    .stroke(AppColor.outline, lineWidth: 1)
                            )
                            .cornerRadius(AppRadius.l)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("日程")
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func addToCalendar(match: Match) {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        saveEvent(store: store, match: match)
                    } else {
                        alertMessage = "您拒绝了日历权限。如需同步，请在设置中开启。"
                        showingAlert = true
                    }
                }
            }
        case .denied, .restricted:
            alertMessage = "日历权限被禁用。请前往“设置”开启权限以同步日程。"
            showingAlert = true
        case .authorized, .fullAccess:
            checkForDuplicateAndSave(store: store, match: match)
        case .writeOnly:
            saveEvent(store: store, match: match)
        @unknown default:
            break
        }
    }

    private func checkForDuplicateAndSave(store: EKEventStore, match: Match) {
        let predicate = store.predicateForEvents(withStart: match.startTime, end: match.endTime, calendars: nil)
        let existingEvents = store.events(matching: predicate)

        let eventTitle = "辩论赛：\(match.name)"
        let isDuplicate = existingEvents.contains { event in
            event.title == eventTitle
        }

        if isDuplicate {
            DispatchQueue.main.async {
                alertMessage = "该日程已存在，无需重复添加。"
                showingAlert = true
            }
        } else {
            saveEvent(store: store, match: match)
        }
    }

    private func saveEvent(store: EKEventStore, match: Match) {
        let event = EKEvent(eventStore: store)
        event.title = "辩论赛：\(match.name)"
        event.startDate = match.startTime
        event.endDate = match.endTime
        event.location = match.location
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            alertMessage = "已成功添加到系统日历！"
            showingAlert = true
        } catch {
            alertMessage = "添加失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    ScheduleView(store: AppStore())
}
