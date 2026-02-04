import SwiftUI

struct TeamRow: View {
    let team: Team
    let isOwner: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar Placeholder
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(team.name.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(team.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isOwner {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text("ID: \(team.publicId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(team.memberCount)")
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TeamRow(
        team: MockData.shared.myTeams[0],
        isOwner: true
    )
    .padding()
}
