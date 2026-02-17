//
//  ScheduleView+CalendarSync.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: ScheduleView 的赛程数据与系统日历权限状态。
//  OUTPUT: 日历同步与去重写入逻辑。
//  POS: 日程页日历同步扩展。
//

import SwiftUI
import EventKit

extension ScheduleView {
    func addToCalendar(match: Match) {
        syncMatchesToCalendar([match], trigger: .single)
    }

    func syncMatchesToCalendar(_ matches: [Match], trigger: CalendarSyncTrigger) {
        let deduplicatedMatches = uniqueMatches(matches)

        guard !deduplicatedMatches.isEmpty else {
            toast = AppToastPayload(
                title: "暂无可同步赛程",
                intent: .info
            )
            return
        }

        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        let result = upsertMatches(store: store, matches: deduplicatedMatches)
                        presentSyncToast(result: result, trigger: trigger)
                    } else {
                        blockingAlertMessage = "您拒绝了日历权限。如需同步，请在设置中开启。"
                        showBlockingAlert = true
                    }
                }
            }
        case .denied, .restricted:
            blockingAlertMessage = "日历权限被禁用。请前往“设置”开启权限以同步日程。"
            showBlockingAlert = true
        case .authorized, .fullAccess, .writeOnly:
            let result = upsertMatches(store: store, matches: deduplicatedMatches)
            presentSyncToast(result: result, trigger: trigger)
        @unknown default:
            break
        }
    }

    private func upsertMatches(store: EKEventStore, matches: [Match]) -> CalendarSyncResult {
        var mapping = loadCalendarEventMapping()
        var syncedCount = 0
        var deduplicatedCount = 0
        var failedCount = 0

        let existingEvents = lookupWindowEvents(store: store, matches: matches)

        for match in matches {
            let key = match.id.uuidString.lowercased()
            let marker = syncMarker(for: match.id)
            let markerURL = syncMarkerURL(for: match.id)
            let title = eventTitle(for: match)

            var existingEvent: EKEvent?

            if let knownIdentifier = mapping[key],
               let knownItem = store.calendarItem(withIdentifier: knownIdentifier) as? EKEvent {
                existingEvent = knownItem
            } else if let located = existingEvents.first(where: { event in
                event.url?.absoluteString == markerURL ||
                (event.notes?.contains(marker) ?? false)
            }) {
                existingEvent = located
            } else if let fallback = existingEvents.first(where: { event in
                event.title == title &&
                abs(event.startDate.timeIntervalSince1970 - match.startTime.timeIntervalSince1970) < 1 &&
                abs(event.endDate.timeIntervalSince1970 - match.endTime.timeIntervalSince1970) < 1
            }) {
                existingEvent = fallback
            }

            do {
                if let existingEvent {
                    if isEventUpToDate(existingEvent, match: match, marker: marker, markerURL: markerURL) {
                        deduplicatedCount += 1
                        mapping[key] = existingEvent.calendarItemIdentifier
                        continue
                    }

                    applyMatch(match, to: existingEvent)
                    try store.save(existingEvent, span: .thisEvent)
                    syncedCount += 1
                    mapping[key] = existingEvent.calendarItemIdentifier
                } else {
                    let event = EKEvent(eventStore: store)
                    applyMatch(match, to: event)
                    event.calendar = store.defaultCalendarForNewEvents
                    try store.save(event, span: .thisEvent)
                    syncedCount += 1
                    mapping[key] = event.calendarItemIdentifier
                }
            } catch {
                failedCount += 1
            }
        }

        persistCalendarEventMapping(mapping)
        return CalendarSyncResult(
            syncedCount: syncedCount,
            deduplicatedCount: deduplicatedCount,
            failedCount: failedCount
        )
    }

    private func lookupWindowEvents(store: EKEventStore, matches: [Match]) -> [EKEvent] {
        guard let earliest = matches.map(\.startTime).min(),
              let latest = matches.map(\.endTime).max() else {
            return []
        }

        let start = calendar.date(byAdding: .day, value: -365, to: earliest) ?? earliest
        let end = calendar.date(byAdding: .day, value: 365, to: latest) ?? latest
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }

    private func uniqueMatches(_ matches: [Match]) -> [Match] {
        let table = Dictionary(matches.map { ($0.id, $0) }, uniquingKeysWith: { lhs, _ in lhs })
        return table.values.sorted { lhs, rhs in
            if lhs.startTime == rhs.startTime {
                return lhs.name < rhs.name
            }
            return lhs.startTime < rhs.startTime
        }
    }

    private func eventTitle(for match: Match) -> String {
        "辩论赛：\(match.name)"
    }

    private func syncMarker(for id: UUID) -> String {
        "BLM_MATCH_ID:\(id.uuidString.lowercased())"
    }

    private func syncMarkerURL(for id: UUID) -> String {
        "bianlunmiao://match/\(id.uuidString.lowercased())"
    }

    private func applyMatch(_ match: Match, to event: EKEvent) {
        let marker = syncMarker(for: match.id)
        let markerURLString = syncMarkerURL(for: match.id)

        event.title = eventTitle(for: match)
        event.startDate = match.startTime
        event.endDate = match.endTime
        event.location = match.location
        event.url = URL(string: markerURLString)
        event.notes = mergeNotes(existingNotes: event.notes, marker: marker)
    }

    private func mergeNotes(existingNotes: String?, marker: String) -> String {
        let markerLine = "同步标识：\(marker)"
        if let existingNotes, existingNotes.contains(markerLine) {
            return existingNotes
        }
        if let existingNotes, !existingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(existingNotes)\n\(markerLine)"
        }
        return markerLine
    }

    private func isEventUpToDate(_ event: EKEvent, match: Match, marker: String, markerURL: String) -> Bool {
        let normalizedLocation = (event.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLocation = (match.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMarker = event.url?.absoluteString == markerURL || (event.notes?.contains(marker) ?? false)

        return event.title == eventTitle(for: match) &&
        abs(event.startDate.timeIntervalSince1970 - match.startTime.timeIntervalSince1970) < 1 &&
        abs(event.endDate.timeIntervalSince1970 - match.endTime.timeIntervalSince1970) < 1 &&
        normalizedLocation == targetLocation &&
        hasMarker
    }

    private func loadCalendarEventMapping() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: Self.calendarEventMapStorageKey),
              let mapping = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return mapping
    }

    private func persistCalendarEventMapping(_ mapping: [String: String]) {
        guard let data = try? JSONEncoder().encode(mapping) else { return }
        UserDefaults.standard.set(data, forKey: Self.calendarEventMapStorageKey)
    }

    private func presentSyncToast(result: CalendarSyncResult, trigger: CalendarSyncTrigger) {
        if result.failedCount > 0 && result.syncedCount == 0 {
            toast = AppToastPayload(
                title: "同步失败",
                message: "请稍后重试",
                intent: .error
            )
            return
        }

        switch trigger {
        case .single:
            if result.syncedCount > 0 {
                toast = AppToastPayload(
                    title: "已同步到系统日历",
                    intent: .success
                )
            } else {
                toast = AppToastPayload(
                    title: "无需重复同步",
                    message: "该赛程已在系统日历中",
                    intent: .info
                )
            }
        case .batch:
            let message: String?
            if result.deduplicatedCount > 0 {
                message = "已自动去重 \(result.deduplicatedCount) 条"
            } else {
                message = nil
            }
            toast = AppToastPayload(
                title: "已同步 \(result.syncedCount) 条赛程",
                message: message,
                intent: result.failedCount > 0 ? .warning : .success
            )
        }
    }
}

enum CalendarSyncTrigger {
    case single
    case batch
}

private struct CalendarSyncResult {
    let syncedCount: Int
    let deduplicatedCount: Int
    let failedCount: Int
}
