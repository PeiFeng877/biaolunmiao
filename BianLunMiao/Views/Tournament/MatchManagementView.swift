import SwiftUI

struct MatchManagementView: View {
    @StateObject private var viewModel: MatchManagementViewModel
    
    init(store: AppStore, tournamentId: UUID) {
        _viewModel = StateObject(wrappedValue: MatchManagementViewModel(store: store, tournamentId: tournamentId))
    }
    
    var body: some View {
        List {
            Section("赛程表") {
                ForEach(viewModel.matches) { match in
                    Button {
                        viewModel.selectMatchIfCaptain(match)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text(match.startTime.formatted(date: .numeric, time: .shortened))
                                Spacer()
                                Text(match.format.rawValue)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .foregroundColor(.secondary)
                            .font(.caption)
                            
                            HStack {
                                Text(match.teamA?.name ?? "待定")
                                Text("VS")
                                    .foregroundColor(.secondary)
                                Text(match.teamB?.name ?? "待定")
                            }
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("赛程管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加赛程") {
                    viewModel.addMatch()
                }
            }
        }
        .sheet(item: $viewModel.selectedMatchForRoster) { match in
            if let team = viewModel.myTeamInMatch {
                RosterEditView(match: match, team: team) { rosters in
                    viewModel.saveRosters(rosters)
                }
            }
        }
    }
}
