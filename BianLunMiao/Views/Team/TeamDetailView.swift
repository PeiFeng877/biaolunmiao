import SwiftUI

struct TeamDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: TeamDetailViewModel
    
    init(store: AppStore, teamId: UUID) {
        _viewModel = StateObject(wrappedValue: TeamDetailViewModel(store: store, teamId: teamId))
    }
    
    var body: some View {
        List {
            // MARK: - Header Info
            Section {
                HStack(alignment: .top, spacing: 16) {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text(viewModel.team.name.prefix(1))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.team.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("ID: \(viewModel.team.publicId)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        
                        if let intro = viewModel.team.intro, !intro.isEmpty {
                            Text(intro)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            
            // MARK: - Actions (Admin Only)
            if viewModel.isCurrentUserAdmin {
                Section {
                    Button(action: {
                        print("Invite Tapped")
                    }) {
                        Label("邀请新成员", systemImage: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // MARK: - Members List
            Section("成员 (\(viewModel.team.members.count))") {
                ForEach(viewModel.sortedMembers) { member in
                    HStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(member.user.nickname.prefix(1))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(member.user.nickname)
                                .foregroundColor(member.role == .owner ? .primary : .primary)
                            
                            if member.userId == viewModel.currentUserId {
                                Text("我")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Role Badge
                        if member.role != .member {
                            Text(member.role.title)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(member.role == .owner ? Color.yellow.opacity(0.2) : Color.blue.opacity(0.1))
                                .foregroundColor(member.role == .owner ? .orange : .blue)
                                .cornerRadius(4)
                        }
                        
                        // MARK: Explicit Action Menu
                        if viewModel.isCurrentUserAdmin && member.userId != viewModel.currentUserId {
                            Menu {
                                Button(role: .destructive) {
                                    viewModel.removeMember(member)
                                } label: {
                                    Label("移除成员", systemImage: "trash")
                                }
                                
                                if viewModel.isCurrentUserOwner {
                                    Button {
                                        viewModel.toggleAdmin(member)
                                    } label: {
                                        Label(member.role == .admin ? "降为队员" : "设为管理", systemImage: "shield")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Important for List row
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.isCurrentUserAdmin && member.userId != viewModel.currentUserId {
                            Button(role: .destructive) {
                                viewModel.removeMember(member)
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                            
                            if viewModel.isCurrentUserOwner {
                                Button {
                                    viewModel.toggleAdmin(member)
                                } label: {
                                    Label(member.role == .admin ? "降为队员" : "设为管理", systemImage: "shield")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            
            // MARK: - Footer Actions
            Section {
                if viewModel.isCurrentUserOwner {
                    Button("解散队伍", role: .destructive) {
                        dismiss()
                    }
                } else {
                    Button("退出队伍", role: .destructive) {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(viewModel.team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isCurrentUserAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        viewModel.showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            CreateTeamSheet(team: viewModel.team) { newName, newIntro in
                viewModel.updateTeam(name: newName, intro: newIntro)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TeamDetailView(store: AppStore(), teamId: MockData.shared.myTeams[0].id)
    }
}
