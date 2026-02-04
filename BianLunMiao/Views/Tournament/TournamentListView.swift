import SwiftUI

struct TournamentListView: View {
    @StateObject private var viewModel: TournamentListViewModel
    private let store: AppStore
    
    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TournamentListViewModel(store: store))
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.tournaments) { tour in
                    NavigationLink(destination: MatchManagementView(store: store, tournamentId: tour.id)) {
                        VStack(alignment: .leading) {
                            Text(tour.name)
                                .font(.headline)
                            if let intro = tour.intro {
                                Text(intro)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("赛事")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateTournamentView { name, intro in
                    viewModel.createTournament(name: name, intro: intro)
                }
            }
        }
    }
}

#Preview {
    TournamentListView(store: AppStore())
}
