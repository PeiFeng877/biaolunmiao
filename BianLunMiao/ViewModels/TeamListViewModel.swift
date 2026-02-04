import Foundation
import Combine

final class TeamListViewModel: ObservableObject {
    @Published private(set) var teams: [Team] = []
    @Published var showCreateSheet = false
    
    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AppStore) {
        self.store = store
        self.teams = store.teams
        
        store.$teams
            .receive(on: DispatchQueue.main)
            .assign(to: &$teams)
    }
    
    func createTeam(name: String, intro: String) {
        _ = store.createTeam(name: name, intro: intro)
    }
    
    func isOwner(team: Team) -> Bool {
        team.ownerId == store.currentUser.id
    }
}
