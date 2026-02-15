//
//  ScheduleView.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: ScheduleViewModel 提供的月历/日详情状态和数据源配置。
//  OUTPUT: Apple 风格日程主页面（全屏月历 + 周视图 + 时间轴 + 数据源入口）。
//  POS: 日程 Tab 根页面。
//

import SwiftUI
import EventKit

struct ScheduleView: View {
    @StateObject private var viewModel: ScheduleViewModel

    @State private var showBlockingAlert = false
    @State private var blockingAlertMessage = ""
    @State private var toast: AppToastPayload?
    @State private var showSourceManagement = false
    @State private var pendingScrollMonth: Date?

    private let calendar = Calendar.current

    init(store: AppStore) {
        _viewModel = StateObject(wrappedValue: ScheduleViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    if viewModel.presentationMode == .month {
                        AppTopBar(
                            title: "日程",
                            style: .schedule,
                            showsLeadingIcon: false,
                            showsAddAction: false,
                            onAdd: {}
                        )
                    } else {
                        AppDetailTopBar(
                            title: "日程",
                            onBack: {
                                viewModel.openMonthMode()
                                pendingScrollMonth = monthStart(viewModel.selectedDate)
                            },
                            backAccessibilityId: "schedule_day_detail_back"
                        )
                    }

                    switch viewModel.presentationMode {
                    case .month:
                        monthCalendarView
                    case .dayDetail:
                        dayDetailView
                    }
                }

                floatingButtons
            }
            .navigationDestination(isPresented: $showSourceManagement) {
                ScheduleSourceManagementView(viewModel: viewModel)
            }
            .toolbar(.hidden, for: .navigationBar)
            .appAlert("提示", isPresented: $showBlockingAlert) {
                AppMenuAction("确定", role: .cancel) {}
            } message: {
                Text(blockingAlertMessage)
            }
            .appToast(item: $toast)
        }
    }

    private var monthCalendarView: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.l, pinnedViews: []) {
                        ForEach(viewModel.monthAnchors, id: \.self) { month in
                            monthSection(month)
                                .id(month)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .preference(
                                                key: MonthSectionOffsetPreferenceKey.self,
                                                value: [month: geometry.frame(in: .named("schedule_month_scroll")).minY]
                                            )
                                    }
                                )
                        }
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, 110)
                }
                .coordinateSpace(name: "schedule_month_scroll")
                .onPreferenceChange(MonthSectionOffsetPreferenceKey.self) { offsets in
                    updateVisibleMonth(with: offsets)
                }
                .onAppear {
                    let anchor = monthStart(viewModel.visibleMonthAnchor)
                    proxy.scrollTo(anchor, anchor: .top)
                }
                .onChange(of: pendingScrollMonth) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(AppMotion.spring) {
                        proxy.scrollTo(monthStart(newValue), anchor: .top)
                    }
                    pendingScrollMonth = nil
                }

                monthOverlayHeader
            }
            .accessibilityIdentifier("schedule_month_calendar")
        }
    }

    private var dayDetailView: some View {
        VStack(spacing: 0) {
            weekStrip

            ScrollView {
                ScheduleTimelineView(
                    matches: viewModel.dayMatches,
                    selectedDate: viewModel.selectedDate,
                    tournamentNameProvider: { match in
                        viewModel.tournamentName(for: match)
                    },
                    teamsLineProvider: { match in
                        viewModel.teamsLine(for: match)
                    },
                    onAddToCalendar: { match in
                        addToCalendar(match: match)
                    }
                )
                .padding(.horizontal, AppSpacing.inset)
                .padding(.top, AppSpacing.s)
                .padding(.bottom, 120)
            }
            .accessibilityIdentifier("schedule_timeline")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule_day_detail_root")
    }

    private var monthOverlayHeader: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColor.background.opacity(0.98), AppColor.background.opacity(0.86), AppColor.background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)
            .overlay(alignment: .topLeading) {
                Text(viewModel.monthOverlayTitle)
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.s)
            }
            .accessibilityIdentifier("schedule_month_overlay")

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(viewModel.selectedDayTitle)
                .font(AppFont.section())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityIdentifier("schedule_day_detail_header")

            HStack(spacing: AppSpacing.s) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = isSameDay(date, viewModel.selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let hasMatches = !viewModel.matches(on: date).isEmpty

                    Button {
                        viewModel.openDayDetail(for: date)
                    } label: {
                        VStack(spacing: 3) {
                            Text(weekDaySymbol(for: date))
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.textSecondary)

                            Text(dayNumber(for: date))
                                .font(AppFont.body().weight(.semibold))
                                .foregroundStyle(
                                    isSelected ? AppColor.background :
                                        (isToday ? AppColor.danger : AppColor.textPrimary)
                                )
                                .frame(width: 30, height: 30)
                                .background(
                                    Group {
                                        if isSelected {
                                            Circle()
                                                .fill(AppColor.textPrimary)
                                        }
                                    }
                                )

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(hasMatches ? AppColor.danger : Color.clear)
                                .frame(width: 14, height: 4)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.s)
        .accessibilityIdentifier("schedule_week_strip")
    }

    private var floatingButtons: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: AppSpacing.s) {
                    AppRowTapButton {
                        showSourceManagement = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 56, height: 56)
                            .background(AppColor.primaryStrong)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppColor.stroke, lineWidth: 2))
                            .shadow(
                                color: AppShadow.standard.color,
                                radius: 0,
                                x: AppShadow.standard.x,
                                y: AppShadow.standard.y
                            )
                    }
                    .accessibilityIdentifier("schedule_source_fab")

                    AppRowTapButton {
                        viewModel.goToToday()
                        if viewModel.presentationMode == .month {
                            pendingScrollMonth = monthStart(viewModel.selectedDate)
                        }
                    } label: {
                        Text("今")
                            .font(AppFont.section())
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 56, height: 56)
                            .background(AppColor.primaryStrong)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppColor.stroke, lineWidth: 2))
                            .shadow(
                                color: AppShadow.standard.color,
                                radius: 0,
                                x: AppShadow.standard.x,
                                y: AppShadow.standard.y
                            )
                    }
                    .accessibilityIdentifier("schedule_today_fab")
                }
            }
            .padding(.horizontal, AppSpacing.inset)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private func monthSection(_ monthStart: Date) -> some View {
        let shouldHideMonthTitle = isSameMonth(monthStart, viewModel.visibleMonthAnchor)

        return VStack(alignment: .leading, spacing: AppSpacing.s) {
            if !shouldHideMonthTitle {
                Text(monthStart.formatted(.dateTime.year().month()))
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)
            }

            HStack(spacing: 0) {
                ForEach(weekSymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColor.stroke.opacity(0.22))
                    .frame(height: 0.8)

                ForEach(Array(monthWeekRows(for: monthStart).enumerated()), id: \.offset) { _, weekDates in
                    HStack(spacing: 0) {
                        ForEach(weekDates, id: \.self) { date in
                            dayCell(date: date, in: monthStart)
                        }
                    }
                    .frame(height: 86, alignment: .top)

                    Rectangle()
                        .fill(AppColor.stroke.opacity(0.22))
                        .frame(height: 0.8)
                }
            }
        }
    }

    private func dayCell(date: Date, in monthStart: Date) -> some View {
        let isInCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
        let isSelected = isSameDay(date, viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let preview = viewModel.dayPreview(on: date)

        return Button {
            viewModel.openDayDetail(for: date)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppColor.textPrimary)
                            .frame(width: 26, height: 26)
                    } else if isToday {
                        Circle()
                            .stroke(AppColor.textPrimary, lineWidth: 1.2)
                            .frame(width: 26, height: 26)
                    }

                    Text(dayNumber(for: date))
                        .font(AppFont.caption())
                        .foregroundStyle(isSelected ? AppColor.background : (isInCurrentMonth ? AppColor.textPrimary : AppColor.textMuted))
                        .monospacedDigit()
                }
                .frame(width: 26, height: 26, alignment: .leading)

                ForEach(preview.titles, id: \.self) { title in
                    Text(title)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }

                if preview.overflowCount > 0 {
                    Text("+\(preview.overflowCount)")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.primaryStrong)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .opacity(isInCurrentMonth ? 1 : 0.36)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(dayCellAccessibilityId(for: date, isToday: isToday))
    }

    private var weekDates: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else {
            return [viewModel.selectedDate]
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    private var weekSymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = max(calendar.firstWeekday - 1, 0)
        let head = Array(symbols[shift...])
        let tail = Array(symbols[..<shift])
        return head + tail
    }

    private func monthGridDates(for monthStart: Date) -> [Date] {
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart

        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    private func monthWeekRows(for monthStart: Date) -> [[Date]] {
        let dates = monthGridDates(for: monthStart)
        let count = dates.count / 7
        return (0..<count).map { index in
            let start = index * 7
            let end = start + 7
            return Array(dates[start..<end])
        }
    }

    private func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func weekDaySymbol(for date: Date) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        guard symbols.indices.contains(index) else {
            return symbols.first ?? "-"
        }
        return symbols[index]
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, equalTo: rhs, toGranularity: .month)
    }

    private func dayCellAccessibilityId(for date: Date, isToday: Bool) -> String {
        if isToday {
            return "schedule_day_cell_today"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyyMMdd"
        return "schedule_day_cell_\(formatter.string(from: date))"
    }

    private func updateVisibleMonth(with offsets: [Date: CGFloat]) {
        guard !offsets.isEmpty else { return }

        let threshold: CGFloat = 80
        let valid = offsets.filter { $0.value <= threshold }

        if let target = valid.max(by: { $0.value < $1.value })?.key {
            viewModel.updateVisibleMonthAnchor(target)
            return
        }

        if let nearest = offsets.min(by: { abs($0.value - threshold) < abs($1.value - threshold) })?.key {
            viewModel.updateVisibleMonthAnchor(nearest)
        }
    }

    private func monthStart(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
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
                        blockingAlertMessage = "您拒绝了日历权限。如需同步，请在设置中开启。"
                        showBlockingAlert = true
                    }
                }
            }
        case .denied, .restricted:
            blockingAlertMessage = "日历权限被禁用。请前往“设置”开启权限以同步日程。"
            showBlockingAlert = true
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
                toast = AppToastPayload(
                    title: "无需重复添加",
                    message: "该日程已存在",
                    intent: .info
                )
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
            toast = AppToastPayload(
                title: "已添加到系统日历",
                intent: .success
            )
        } catch {
            toast = AppToastPayload(
                title: "添加失败",
                message: error.localizedDescription,
                intent: .error
            )
        }
    }
}

private struct MonthSectionOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGFloat] = [:]

    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview {
    ScheduleView(store: AppStore())
}
