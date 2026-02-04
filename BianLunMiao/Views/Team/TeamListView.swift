import SwiftUI

struct TeamListView: View {
    @StateObject private var viewModel: TeamListViewModel
    private let store: AppStore
    
    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TeamListViewModel(store: store))
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.teams) { team in
                    NavigationLink(destination: TeamDetailView(store: store, teamId: team.id)) {
                        TeamRow(team: team, isOwner: viewModel.isOwner(team: team))
                    }
                }
            }
            .navigationTitle("我的队伍")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateTeamSheet { name, intro in
                    viewModel.createTeam(name: name, intro: intro)
                }
            }
        }
    }
}

#Preview {
    TeamListView(store: AppStore())
}
