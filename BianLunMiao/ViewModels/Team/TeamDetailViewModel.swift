//
//  TeamDetailViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 与指定队伍 ID。
//  OUTPUT: 队伍详情状态与管理操作。
//  POS: 队伍详情视图模型。
//

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
            slogan: nil,
            about: nil,
            avatarStyle: .paw,
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

    var dangerActionTitle: String {
        isCurrentUserOwner ? "解散队伍" : "退出队伍"
    }

    func canRemove(_ member: TeamMember) -> Bool {
        guard member.role != .owner else { return false }
        if isCurrentUserOwner {
            return true
        }
        if isCurrentUserAdmin {
            return member.role == .member
        }
        return false
    }

    func canToggleAdmin(_ member: TeamMember) -> Bool {
        isCurrentUserOwner && member.role != .owner
    }

    func canTransferOwner(_ member: TeamMember) -> Bool {
        isCurrentUserOwner && member.role != .owner
    }
    
    func removeMember(_ member: TeamMember) {
        store.removeMember(teamId: teamId, memberId: member.id)
    }
    
    func toggleAdmin(_ member: TeamMember) {
        store.toggleAdmin(teamId: teamId, memberId: member.id)
    }
    
    func transferOwner(to member: TeamMember) {
        store.transferOwner(teamId: teamId, to: member.id)
    }

    func updateTeam(name: String, slogan: String, avatarImageData: Data?) {
        store.updateTeam(
            id: teamId,
            name: name,
            slogan: slogan,
            avatarImageData: avatarImageData
        )
    }

    func performDangerAction() {
        if isCurrentUserOwner {
            store.dissolveTeam(id: teamId)
            return
        }
        store.leaveTeam(teamId: teamId)
    }
}
