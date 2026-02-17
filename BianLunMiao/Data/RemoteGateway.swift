//
//  RemoteGateway.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/17.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 本地环境 API 地址与鉴权上下文。
//  OUTPUT: 后端接口访问、会话维护与快照拉取能力。
//  POS: 数据层-远程网关。
//

import Foundation

struct RemoteSnapshot {
    let currentUser: APIUser
    let myTeams: [APITeam]
    let discoverTeams: [APITeam]
    let joinRequests: [APIJoinRequest]
    let messages: [APIMessage]
    let tournaments: [APITournament]
    let matches: [APIMatch]
    let scheduleSources: [APIScheduleSource]
}

struct RemoteGatewayError: Error {
    let code: String?
    let message: String
    let statusCode: Int
}

private struct TokenBundle: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: APIUser
}

private struct APIList<T: Decodable>: Decodable {
    let items: [T]
    let nextCursor: String?
}

struct APIUser: Decodable {
    let id: String
    let publicId: String
    let nickname: String
    let avatarUrl: String?
    let status: Int
}

struct APITeamMember: Decodable {
    let id: String
    let teamId: String
    let userId: String
    let role: Int
    let joinTime: Date
    let nickname: String
    let publicId: String
}

struct APITeam: Decodable {
    let id: String
    let publicId: String
    let name: String
    let intro: String?
    let avatarUrl: String?
    let ownerId: String
    let status: Int
    let members: [APITeamMember]
}

struct APIJoinRequest: Decodable {
    let id: String
    let teamId: String
    let teamPublicId: String
    let teamName: String
    let applicantUserId: String
    let applicantPublicId: String
    let applicantNickname: String
    let personalNote: String
    let reason: String?
    let status: String
    let createdAt: Date
    let reviewedAt: Date?
    let reviewedByUserId: String?
    let reviewedByNickname: String?
}

struct APITournamentParticipant: Decodable {
    let id: String
    let tournamentId: String
    let teamId: String
    let status: String
    let seed: Int
}

struct APITournament: Decodable {
    let id: String
    let name: String
    let intro: String?
    let coverUrl: String?
    let creatorId: String
    let status: Int
    let participants: [APITournamentParticipant]
}

struct APIRoster: Decodable {
    let id: String
    let matchId: String
    let teamId: String
    let userId: String
    let position: String
}

struct APIMatch: Decodable {
    let id: String
    let tournamentId: String
    let name: String
    let topic: String?
    let startTime: Date
    let endTime: Date
    let location: String?
    let opponentTeamName: String?
    let teamAId: String?
    let teamBId: String?
    let format: String
    let status: String
    let winnerTeamId: String?
    let teamAScore: Int?
    let teamBScore: Int?
    let resultRecordedAt: Date?
    let resultNote: String?
    let bestDebaterPosition: String?
    let rosters: [APIRoster]
}

struct APIMessage: Decodable {
    let id: String
    let kind: String
    let title: String
    let subtitle: String
    let createdAt: Date
    let relatedMatchId: String?
    let isAcknowledged: Bool
    let payload: [String: String]?
}

struct APIScheduleSource: Decodable {
    let id: String
    let kind: String
    let targetId: String?
    let name: String
    let isEnabled: Bool
}

final class RemoteGateway {
    static let shared = RemoteGateway()

    private let session: URLSession
    private let defaults: UserDefaults
    private let baseURL: URL

    private let accessKey = "remote.access.token"
    private let refreshKey = "remote.refresh.token"
    private let debugUserKey = "remote.debug.public.id"

    private init(defaults: UserDefaults = .standard) {
        self.session = URLSession(configuration: .default)
        self.defaults = defaults
        self.baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
    }

    func bootstrap() async throws -> RemoteSnapshot {
        _ = try await ensureSession()

        async let currentUser: APIUser = request(path: "/users/me")
        async let myTeams: APIList<APITeam> = request(path: "/teams/my?limit=200")
        async let discover: APIList<APITeam> = request(path: "/teams/discover?limit=200")
        async let joinRequests: APIList<APIJoinRequest> = request(path: "/teams/join-requests?scope=related&limit=200")
        async let messages: APIList<APIMessage> = request(path: "/messages?limit=200")
        async let tournaments: APIList<APITournament> = request(path: "/tournaments?limit=200")
        async let sources: [APIScheduleSource] = request(path: "/schedule/sources")

        let tournamentRows = try await tournaments.items
        var allMatches: [APIMatch] = []
        for tournament in tournamentRows {
            let list: APIList<APIMatch> = try await request(path: "/tournaments/\(tournament.id)/matches?limit=200")
            allMatches.append(contentsOf: list.items)
        }

        return RemoteSnapshot(
            currentUser: try await currentUser,
            myTeams: try await myTeams.items,
            discoverTeams: try await discover.items,
            joinRequests: try await joinRequests.items,
            messages: try await messages.items,
            tournaments: tournamentRows,
            matches: allMatches,
            scheduleSources: try await sources
        )
    }

    @discardableResult
    func ensureSession() async throws -> APIUser {
        if let _: APIUser = try? await request(path: "/users/me") {
            return try await request(path: "/users/me")
        }
        let payload: [String: Any] = [
            "public_id": debugPublicID(),
            "nickname": "辩论喵调试用户",
        ]
        let bundle: TokenBundle = try await request(path: "/auth/debug-token", method: "POST", body: payload, requiresAuth: false)
        defaults.set(bundle.accessToken, forKey: accessKey)
        defaults.set(bundle.refreshToken, forKey: refreshKey)
        return bundle.user
    }

    func createTeam(name: String, intro: String?, avatarURL: String?) async throws -> APITeam {
        try await request(
            path: "/teams",
            method: "POST",
            body: [
                "name": name,
                "intro": intro as Any,
                "avatar_url": avatarURL as Any,
            ]
        )
    }

    func updateTeam(teamID: String, name: String, intro: String?, avatarURL: String?) async throws -> APITeam {
        try await request(
            path: "/teams/\(teamID)",
            method: "PUT",
            body: [
                "name": name,
                "intro": intro as Any,
                "avatar_url": avatarURL as Any,
            ]
        )
    }

    func dissolveTeam(teamID: String) async throws {
        let _: APITeamAction = try await request(path: "/teams/\(teamID):dissolve", method: "POST")
    }

    func transferOwner(teamID: String, memberID: String) async throws {
        let _: APITeamAction = try await request(
            path: "/teams/\(teamID):transfer-owner",
            method: "POST",
            body: ["memberId": memberID]
        )
    }

    func toggleAdmin(teamID: String, memberID: String) async throws {
        let _: APITeamAction = try await request(path: "/teams/\(teamID)/members/\(memberID):toggle-admin", method: "POST")
    }

    func removeMember(teamID: String, memberID: String) async throws {
        let _: APITeamAction = try await request(path: "/teams/\(teamID)/members/\(memberID)", method: "DELETE")
    }

    func submitJoinRequest(teamID: String, personalNote: String, reason: String) async throws -> APIJoinRequest {
        try await request(
            path: "/teams/\(teamID)/join-requests",
            method: "POST",
            body: [
                "personal_note": personalNote,
                "reason": reason,
            ]
        )
    }

    func reviewJoinRequest(requestID: String, approve: Bool) async throws -> APIJoinRequest {
        let action = approve ? "approve" : "reject"
        return try await request(path: "/teams/join-requests/\(requestID):\(action)", method: "POST")
    }

    func createTournament(name: String, intro: String, status: Int) async throws -> APITournament {
        try await request(
            path: "/tournaments",
            method: "POST",
            body: [
                "name": name,
                "intro": intro,
                "status": status,
            ]
        )
    }

    func updateTournament(id: String, name: String, intro: String, status: Int) async throws -> APITournament {
        try await request(
            path: "/tournaments/\(id)",
            method: "PUT",
            body: [
                "name": name,
                "intro": intro,
                "status": status,
                "start_date": NSNull(),
                "end_date": NSNull(),
            ]
        )
    }

    func createMatch(tournamentID: String, draft: MatchDraft) async throws -> APIMatch {
        try await request(
            path: "/tournaments/\(tournamentID)/matches",
            method: "POST",
            body: makeMatchPayload(draft: draft)
        )
    }

    func updateMatch(matchID: String, draft: MatchDraft) async throws -> APIMatch {
        try await request(path: "/tournaments/matches/\(matchID)", method: "PUT", body: makeMatchPayload(draft: draft))
    }

    func assignTeams(matchID: String, teamAID: String?, teamBID: String?) async throws -> APIMatch {
        try await request(
            path: "/tournaments/matches/\(matchID):assign-teams",
            method: "POST",
            body: [
                "team_a_id": teamAID as Any,
                "team_b_id": teamBID as Any,
            ]
        )
    }

    func saveRoster(matchID: String, teamID: String, assignments: [RosterAssignment]) async throws -> APIMatch {
        let rows = assignments.map { row in
            [
                "user_id": row.userId.uuidString.lowercased(),
                "position": row.position,
            ]
        }
        return try await request(
            path: "/tournaments/matches/\(matchID)/rosters/\(teamID)",
            method: "PUT",
            body: ["assignments": rows]
        )
    }

    func advanceMatch(matchID: String, status: String) async throws -> APIMatch {
        try await request(
            path: "/tournaments/matches/\(matchID):advance-status",
            method: "POST",
            body: ["status": status]
        )
    }

    func recordResult(matchID: String, winnerTeamID: String, teamAScore: Int, teamBScore: Int, resultNote: String?, bestDebaterPosition: String?) async throws -> APIMatch {
        try await request(
            path: "/tournaments/matches/\(matchID)/result",
            method: "PUT",
            body: [
                "winner_team_id": winnerTeamID,
                "team_a_score": teamAScore,
                "team_b_score": teamBScore,
                "result_note": resultNote as Any,
                "best_debater_position": bestDebaterPosition as Any,
            ]
        )
    }

    func acknowledgeMessage(messageID: String) async throws {
        let _: APIMessage = try await request(path: "/messages/\(messageID):ack", method: "POST")
    }

    func updateProfile(nickname: String, avatarURL: String?) async throws {
        let _: APIUser = try await request(
            path: "/users/me",
            method: "PUT",
            body: [
                "nickname": nickname,
                "avatar_url": avatarURL as Any,
            ]
        )
    }

    func listScheduleSources() async throws -> [APIScheduleSource] {
        try await request(path: "/schedule/sources")
    }

    func addScheduleSource(kind: String, targetID: String, name: String) async throws -> APIScheduleSource {
        try await request(
            path: "/schedule/sources",
            method: "POST",
            body: [
                "kind": kind,
                "target_id": targetID,
                "name": name,
            ]
        )
    }

    func toggleScheduleSource(sourceID: String, isEnabled: Bool) async throws -> APIScheduleSource {
        try await request(
            path: "/schedule/sources/\(sourceID)",
            method: "PUT",
            body: ["is_enabled": isEnabled]
        )
    }

    func removeScheduleSource(sourceID: String) async throws {
        let _: APIOk = try await request(path: "/schedule/sources/\(sourceID)", method: "DELETE")
    }

    private func makeMatchPayload(draft: MatchDraft) -> [String: Any] {
        [
            "name": draft.name,
            "topic": draft.topic.isEmpty ? NSNull() : draft.topic,
            "start_time": ISO8601DateFormatter.bianlunmiao.string(from: draft.startTime),
            "end_time": ISO8601DateFormatter.bianlunmiao.string(from: draft.startTime.addingTimeInterval(AppStore.fixedMatchDuration)),
            "location": draft.location.isEmpty ? NSNull() : draft.location,
            "format": backendFormat(draft.format),
            "opponent_team_name": draft.opponentTeamName.isEmpty ? NSNull() : draft.opponentTeamName,
        ]
    }

    private func backendFormat(_ format: MatchFormat) -> String {
        switch format {
        case .f1v1:
            return "1v1"
        case .f2v2:
            return "2v2"
        case .f3v3:
            return "3v3"
        case .f4v4:
            return "4v4"
        }
    }

    private func debugPublicID() -> String {
        if let existing = defaults.string(forKey: debugUserKey), !existing.isEmpty {
            return existing
        }
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
        let value = "U9\(suffix)"
        defaults.set(value, forKey: debugUserKey)
        return value
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            if let token = defaults.string(forKey: accessKey), !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: sanitize(body), options: [])
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteGatewayError(code: nil, message: "Invalid response", statusCode: -1)
        }

        guard (200..<300).contains(http.statusCode) else {
            if let remote = try? decoder.decode(RemoteErrorPayload.self, from: data) {
                throw RemoteGatewayError(code: remote.code, message: remote.message, statusCode: http.statusCode)
            }
            throw RemoteGatewayError(code: nil, message: "HTTP \(http.statusCode)", statusCode: http.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func sanitize(_ object: [String: Any]) -> [String: Any] {
        var output: [String: Any] = [:]
        for (key, value) in object {
            if value is NSNull {
                output[key] = NSNull()
                continue
            }
            if let optionalString = value as? String {
                output[key] = optionalString
                continue
            }
            if let optionalBool = value as? Bool {
                output[key] = optionalBool
                continue
            }
            if let optionalInt = value as? Int {
                output[key] = optionalInt
                continue
            }
            if let array = value as? [[String: Any]] {
                output[key] = array.map { sanitize($0) }
                continue
            }
            if let nested = value as? [String: Any] {
                output[key] = sanitize(nested)
                continue
            }
            output[key] = value
        }
        return output
    }

    private lazy var decoder: JSONDecoder = {
        let instance = JSONDecoder()
        instance.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let parsed = ISO8601DateFormatter.bianlunmiao.date(from: value) {
                return parsed
            }
            if let parsed = ISO8601DateFormatter.bianlunmiaoNoFraction.date(from: value) {
                return parsed
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date: \(value)"
            )
        }
        return instance
    }()
}

private struct RemoteErrorPayload: Decodable {
    let code: String
    let message: String
}

private struct APITeamAction: Decodable {
    let team: APITeam
}

private struct APIOk: Decodable {
    let ok: Bool
}

private extension ISO8601DateFormatter {
    static let bianlunmiao: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let bianlunmiaoNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
