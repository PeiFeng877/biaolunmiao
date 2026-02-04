import Foundation
import Combine

final class ScheduleViewModel: ObservableObject {
    @Published private(set) var myMatches: [Match] = []
    
    private let store: AppStore
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AppStore) {
        self.store = store
        self.myMatches = store.myMatches()
        
        Publishers.CombineLatest(store.$matches, store.$teams)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self = self else { return }
                self.myMatches = store.myMatches()
            }
            .store(in: &cancellables)
    }
}
