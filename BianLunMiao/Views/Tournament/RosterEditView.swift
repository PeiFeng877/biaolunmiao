import SwiftUI

struct RosterEditView: View {
    @Environment(\.dismiss) var dismiss
    let match: Match
    let team: Team // My team
    
    @State private var assignments: [UUID: String] = [:] // userId: position
    var onSave: ([Roster]) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section("选择上场队员 (\(match.format.rawValue))") {
                    ForEach(team.members) { member in
                        HStack {
                            Text(member.user.nickname)
                            Spacer()
                            if let pos = assignments[member.userId] {
                                Text(pos)
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(for: member.userId)
                        }
                    }
                }
            }
            .navigationTitle("排兵布阵")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let rosters = assignments.map { (uid, pos) in
                            Roster(id: UUID(), matchId: match.id, teamId: team.id, userId: uid, position: pos)
                        }
                        onSave(rosters)
                        dismiss()
                    }
                    .disabled(assignments.isEmpty)
                }
            }
        }
    }
    
    // Mock Logic: Auto-assign positions based on click order
    private func toggleSelection(for uid: UUID) {
        if assignments[uid] != nil {
            assignments.removeValue(forKey: uid)
        } else {
            let count = assignments.count
            let positions = match.format.positions
            if count < positions.count {
                assignments[uid] = positions[count]
            }
        }
    }
}
