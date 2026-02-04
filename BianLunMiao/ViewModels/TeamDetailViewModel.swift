import Foundation
import Combine

final class TeamDetailViewModel: ObservableObject {
    @Published private(set) var team: Team
    @Published var showEditSheet = false
    
    private let store: AppStore
    private let teamId: UUID
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AppStore, teamId: UUID) {
        self.store = store
        self.teamId = teamId
        self.team = store.teams.first(where: { $0.id == teamId }) ?? Team(
            id: teamId,
            publicId: "0000",
            name: "未知队伍",
            intro: nil,
            avatarUrl: nil,
            ownerId: store.currentUser.id,
            status: .normal,
            members: []
        )
        
        store.$teams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] teams in
                guard let self = self else { return }
                if let updated = teams.first(where: { $0.id == self.teamId }) {
                    self.team = updated
                }
            }
            .store(in: &cancellables)
    }
    
    var isCurrentUserOwner: Bool {
        team.ownerId == store.currentUser.id
    }
    
    var currentUserId: UUID {
        store.currentUser.id
    }
    
    var isCurrentUserAdmin: Bool {
        guard let myMember = team.members.first(where: { $0.userId == store.currentUser.id }) else {
            return false
        }
        return myMember.role == .admin || myMember.role == .owner
    }
    
    var sortedMembers: [TeamMember] {
        team.members.sorted { $0.role > $1.role }
    }
    
    func removeMember(_ member: TeamMember) {
        store.removeMember(teamId: teamId, memberId: member.id)
    }
    
    func toggleAdmin(_ member: TeamMember) {
        store.toggleAdmin(teamId: teamId, memberId: member.id)
    }
    
    func updateTeam(name: String, intro: String) {
        store.updateTeam(id: teamId, name: name, intro: intro)
    }
}
