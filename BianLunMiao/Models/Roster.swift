import Foundation

// 指派记录：谁在哪个队哪场比赛打了什么位置
struct Roster: Identifiable, Codable, Hashable {
    let id: UUID
    let matchId: UUID
    let teamId: UUID
    let userId: UUID
    var position: String // "一辩"
    
    // Helper
    var user: User? // Resolved user
}
