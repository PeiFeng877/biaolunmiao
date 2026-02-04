import Foundation
import Combine

final class TournamentListViewModel: ObservableObject {
    @Published private(set) var tournaments: [Tournament] = []
    @Published var showCreateSheet = false
    
    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AppStore) {
        self.store = store
        self.tournaments = store.tournaments
        
        store.$tournaments
            .receive(on: DispatchQueue.main)
            .assign(to: &$tournaments)
    }
    
    func createTournament(name: String, intro: String) {
        _ = store.createTournament(name: name, intro: intro)
    }
}
