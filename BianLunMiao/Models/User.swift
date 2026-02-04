import Foundation

enum UserStatus: Int, Codable {
    case normal = 0
    case deleted = 1
    case banned = 2
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    let publicId: String // 用户可见 ID
    var nickname: String
    var avatarUrl: String?
    var status: UserStatus
    
    // Helper for Mocking
    static let current: User = User(
        id: UUID(),
        publicId: "U888888",
        nickname: "逻辑核心",
        avatarUrl: nil,
        status: .normal
    )
}
