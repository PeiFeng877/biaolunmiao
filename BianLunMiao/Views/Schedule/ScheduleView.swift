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
            List {
                if viewModel.myMatches.isEmpty {
                    ContentUnavailableView("暂无日程", systemImage: "calendar.badge.exclamationmark")
                } else {
                    ForEach(viewModel.myMatches) { match in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(match.name)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    addToCalendar(match: match)
                                } label: {
                                    Label("添加到日历", systemImage: "calendar.badge.plus")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            
                            Text(match.startTime.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Label(match.location ?? "地点待定", systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("我的日程")
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
            store.requestFullAccessToEvents { granted, error in
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
            return event.title == eventTitle
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
