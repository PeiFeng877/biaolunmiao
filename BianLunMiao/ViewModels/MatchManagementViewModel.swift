import Foundation
import Combine

final class MatchManagementViewModel: ObservableObject {
    @Published private(set) var matches: [Match] = []
    @Published var selectedMatchForRoster: Match?
    @Published var myTeamInMatch: Team?
    
    private let store: AppStore
    private let tournamentId: UUID
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AppStore, tournamentId: UUID) {
        self.store = store
        self.tournamentId = tournamentId
        self.matches = store.matches(for: tournamentId)
        
        store.$matches
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.matches = store.matches(for: tournamentId)
            }
            .store(in: &cancellables)
    }
    
    func selectMatchIfCaptain(_ match: Match) {
        let myId = store.currentUser.id
        if let teamA = match.teamA, teamA.ownerId == myId {
            myTeamInMatch = teamA
            selectedMatchForRoster = match
        } else if let teamB = match.teamB, teamB.ownerId == myId {
            myTeamInMatch = teamB
            selectedMatchForRoster = match
        }
    }
    
    func addMatch() {
        _ = store.addMatch(tournamentId: tournamentId)
    }
    
    func saveRosters(_ rosters: [Roster]) {
        store.saveRosters(rosters)
    }
}
