//
//  RemoteGateway.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/17.
//  Updated by Codex on 2026/3/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 本地环境 API 地址与鉴权上下文。
//  OUTPUT: 后端接口访问、会话维护与快照拉取能力。
//  POS: 数据层-远程网关。
//

import Foundation
import OSLog

nonisolated struct RemoteSnapshot: Sendable {
    let currentUser: APIUser
    let myTeams: [APITeam]
    let discoverTeams: [APITeam]
    let joinRequests: [APIJoinRequest]
    let messages: [APIMessage]
    let tournaments: [APITournament]
    let matches: [APIMatch]
    let scheduleSources: [APIScheduleSource]
}

nonisolated struct RemoteGatewayError: Error, LocalizedError, Sendable {
    let code: String?
    let message: String
    let statusCode: Int

    var errorDescription: String? {
        message
    }
}

nonisolated private struct TokenBundle: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let user: APIUser
    let isNewUser: Bool

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
        case isNewUser
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        user = try container.decode(APIUser.self, forKey: .user)
        isNewUser = try container.decodeIfPresent(Bool.self, forKey: .isNewUser) ?? false
    }
}

nonisolated struct AppleSignInResult: Sendable {
    let user: APIUser
    let isNewUser: Bool
}

nonisolated private struct APIList<T: Decodable & Sendable>: Decodable, Sendable {
    let items: [T]
    let nextCursor: String?
}

nonisolated struct APIUser: Decodable, Sendable {
    let id: String
    let publicId: String
    let nickname: String
    let avatarUrl: String?
    let status: Int
}

nonisolated struct APITeamMember: Decodable, Sendable {
    let id: String
    let teamId: String
    let userId: String
    let role: Int
    let joinTime: Date
    let nickname: String
    let publicId: String
}

nonisolated struct APITeam: Decodable, Sendable {
    let id: String
    let publicId: String
    let name: String
    let intro: String?
    let avatarUrl: String?
    let ownerId: String
    let status: Int
    let members: [APITeamMember]
}

nonisolated struct APIJoinRequest: Decodable, Sendable {
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

nonisolated struct APITournamentParticipant: Decodable, Sendable {
    let id: String
    let tournamentId: String
    let teamId: String
    let status: String
    let seed: Int
}

nonisolated struct APITournament: Decodable, Sendable {
    let id: String
    let name: String
    let intro: String?
    let coverUrl: String?
    let creatorId: String
    let status: Int
    let participants: [APITournamentParticipant]
}

nonisolated struct APIRoster: Decodable, Sendable {
    let id: String
    let matchId: String
    let teamId: String
    let userId: String
    let position: String
}

nonisolated struct APIMatch: Decodable, Sendable {
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

nonisolated struct APIMessage: Decodable, Sendable {
    let id: String
    let kind: String
    let title: String
    let subtitle: String
    let createdAt: Date
    let relatedMatchId: String?
    let isAcknowledged: Bool
    let payload: [String: String]?
}

nonisolated struct APIScheduleSource: Decodable, Sendable {
    let id: String
    let kind: String
    let targetId: String?
    let name: String
    let isEnabled: Bool
}

nonisolated struct APIUploadToken: Decodable, Sendable {
    let objectKey: String
    let uploadUrl: String
    let expiresAt: Date
    let method: String
    let uploadHeaders: [String: String]
    let publicUrl: String
    let provider: String
}

final class RemoteGateway {
    private static let authLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wenwan.BianLunMiao",
        category: "RemoteAuth"
    )

    static let shared = RemoteGateway()

    private let session: URLSession
    private let defaults: UserDefaults
    private let baseURL: URL

    private func traceAuth(_ message: String) {
        Self.authLogger.notice("\(message)")
        print("[RemoteAuth] \(message)")
    }

    private let accessKey = "remote.access.token"
    private let refreshKey = "remote.refresh.token"
    private let debugUserKey = "remote.debug.public.id"
    private let appleFirstNameKey = "remote.apple.first.name"
    private let appleLastNameKey = "remote.apple.last.name"

    private init(defaults: UserDefaults = .standard) {
        self.session = URLSession(configuration: .default)
        self.defaults = defaults
        self.baseURL = Self.resolveBaseURL()
    }

    private static func resolveBaseURL() -> URL {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["BLM_API_BASE_URL"], let url = URL(string: raw) {
            return url
        }
#if DEBUG
        return URL(string: "http://120.55.115.147/api/v1")!
#else
        return URL(string: "https://api.bianlunmiao.top/api/v1")!
#endif
    }

    func bootstrap() async throws -> RemoteSnapshot {
        _ = try await ensureSession()

        async let currentUser: APIUser = tracedRequest(path: "/users/me")
        async let myTeams: APIList<APITeam> = tracedRequest(path: "/teams/my?limit=100")
        async let discover: APIList<APITeam> = tracedRequest(path: "/teams/discover?limit=100")
        async let joinRequests: APIList<APIJoinRequest> = tracedRequest(path: "/teams/join-requests?scope=related&limit=100")
        async let messages: APIList<APIMessage> = tracedRequest(path: "/messages?limit=100")
        async let tournaments: APIList<APITournament> = tracedRequest(path: "/tournaments?limit=100")
        async let sources: [APIScheduleSource] = tracedRequest(path: "/schedule/sources")

        let tournamentRows = try await tournaments.items
        var allMatches: [APIMatch] = []
        for tournament in tournamentRows {
            let list: APIList<APIMatch> = try await tracedRequest(path: "/tournaments/\(tournament.id)/matches?limit=200")
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

        if let user = try await refreshSessionIfNeeded() {
            return user
        }

#if DEBUG
        if let identityToken = processIdentityTokenFromEnvironment() {
            return try await issueAppleSession(identityToken: identityToken).user
        }
        if shouldEnableDebugSessionFallback() {
            return try await issueDebugSession()
        }
        throw RemoteGatewayError(
            code: "SESSION_REQUIRED",
            message: "当前未登录，请先完成 Apple 登录。",
            statusCode: 401
        )
#else
        throw RemoteGatewayError(
            code: "SESSION_REQUIRED",
            message: "Release 构建未找到可用会话，请先完成正式登录。",
            statusCode: 401
        )
#endif
    }

    func signInWithApple(identityToken: String, firstName: String?, lastName: String?) async throws -> AppleSignInResult {
        traceAuth("RemoteGateway starting Apple token exchange")
        storeAppleProfile(firstName: firstName, lastName: lastName)
        return try await issueAppleSession(identityToken: identityToken)
    }

    func clearSession() {
        clearSessionTokens()
    }

    func createTeam(name: String, intro: String?, avatarURL: String?) async throws -> APITeam {
        traceAuth("RemoteGateway createTeam request prepared")
        let team: APITeam = try await request(
            path: "/teams",
            method: "POST",
            body: [
                "name": name,
                "intro": intro as Any,
                "avatar_url": avatarURL as Any,
            ]
        )
        return team
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

    func requestAvatarUploadToken() async throws -> APIUploadToken {
        try await request(path: "/media/avatar-upload-token", method: "POST")
    }

    func requestCoverUploadToken() async throws -> APIUploadToken {
        try await request(path: "/media/cover-upload-token", method: "POST")
    }

    func uploadImage(to urlString: String, method: String, headers: [String: String], data: Data) async throws {
        guard let url = URL(string: urlString) else {
            throw RemoteGatewayError(code: nil, message: "Invalid upload URL", statusCode: -1)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteGatewayError(code: nil, message: "Invalid upload response", statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteGatewayError(code: nil, message: "Upload failed: HTTP \(http.statusCode)", statusCode: http.statusCode)
        }
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

    private func processIdentityTokenFromEnvironment() -> String? {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["BLM_APPLE_IDENTITY_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return raw.isEmpty ? nil : raw
    }

    private func shouldEnableDebugSessionFallback() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["BLM_ENABLE_DEBUG_SESSION_FALLBACK"] == "1"
    }

    private func storeAppleProfile(firstName: String?, lastName: String?) {
        let trimmedFirstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedFirstName.isEmpty {
            defaults.removeObject(forKey: appleFirstNameKey)
        } else {
            defaults.set(trimmedFirstName, forKey: appleFirstNameKey)
        }

        if trimmedLastName.isEmpty {
            defaults.removeObject(forKey: appleLastNameKey)
        } else {
            defaults.set(trimmedLastName, forKey: appleLastNameKey)
        }
    }

    private func persistTokenBundle(_ bundle: TokenBundle) {
        defaults.set(bundle.accessToken, forKey: accessKey)
        defaults.set(bundle.refreshToken, forKey: refreshKey)
    }

    private func clearSessionTokens() {
        defaults.removeObject(forKey: accessKey)
        defaults.removeObject(forKey: refreshKey)
    }

    private func refreshSessionIfNeeded() async throws -> APIUser? {
        guard let refreshToken = defaults.string(forKey: refreshKey), !refreshToken.isEmpty else {
            return nil
        }
        do {
            let bundle: TokenBundle = try await request(
                path: "/auth/refresh",
                method: "POST",
                body: ["refresh_token": refreshToken],
                requiresAuth: false
            )
            persistTokenBundle(bundle)
            return bundle.user
        } catch let remote as RemoteGatewayError {
            if remote.statusCode == 401 || remote.code == "INVALID_TOKEN" {
                clearSessionTokens()
                return nil
            }
            throw remote
        }
    }

    private func issueAppleSession(identityToken: String) async throws -> AppleSignInResult {
        var payload: [String: Any] = ["identity_token": identityToken]
        if let firstName = defaults.string(forKey: appleFirstNameKey), !firstName.isEmpty {
            payload["first_name"] = firstName
        }
        if let lastName = defaults.string(forKey: appleLastNameKey), !lastName.isEmpty {
            payload["last_name"] = lastName
        }
        do {
            let bundle: TokenBundle = try await request(
                path: "/auth/apple",
                method: "POST",
                body: payload,
                requiresAuth: false
            )
            persistTokenBundle(bundle)
            traceAuth("RemoteGateway Apple token exchange succeeded")
            return AppleSignInResult(user: bundle.user, isNewUser: bundle.isNewUser)
        } catch {
            traceAuth("RemoteGateway Apple token exchange failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func issueDebugSession() async throws -> APIUser {
        let payload: [String: Any] = [
            "public_id": debugPublicID(),
            "nickname": "辩论喵调试用户",
        ]
        let bundle: TokenBundle = try await request(
            path: "/auth/debug-token",
            method: "POST",
            body: payload,
            requiresAuth: false
        )
        persistTokenBundle(bundle)
        return bundle.user
    }

    private func tracedRequest<T: Decodable & Sendable>(path: String) async throws -> T {
        do {
            return try await request(path: path)
        } catch let remote as RemoteGatewayError {
            traceAuth("RemoteGateway request failed for \(path): \(remote.message) [\(remote.statusCode)]")
            throw remote
        } catch {
            traceAuth("RemoteGateway request failed for \(path): \(error.localizedDescription)")
            throw error
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = try makeURL(path: path)
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

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            traceAuth("RemoteGateway transport failed for \(path): \(error.localizedDescription)")
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            throw RemoteGatewayError(code: nil, message: "Invalid response", statusCode: -1)
        }

        guard (200..<300).contains(http.statusCode) else {
            if let remote = try? decoder.decode(RemoteErrorPayload.self, from: data) {
                throw RemoteGatewayError(code: remote.code, message: remote.message, statusCode: http.statusCode)
            }
            throw RemoteGatewayError(code: nil, message: "HTTP \(http.statusCode)", statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let payload = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            traceAuth("RemoteGateway decode failed for \(path): \(payload)")
            throw RemoteGatewayError(
                code: nil,
                message: "服务器响应格式错误，请稍后重试。",
                statusCode: -1
            )
        }
    }

    private func makeURL(path: String) throws -> URL {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = baseURL.absoluteString.hasSuffix("/") ? baseURL.absoluteString : "\(baseURL.absoluteString)/"
        guard let url = URL(string: trimmedPath, relativeTo: URL(string: base))?.absoluteURL else {
            throw RemoteGatewayError(code: nil, message: "Invalid request URL", statusCode: -1)
        }
        return url
    }

    private func sanitize(_ object: [String: Any]) -> [String: Any] {
        var output: [String: Any] = [:]
        for (key, value) in object {
            output[key] = sanitizeValue(value)
        }
        return output
    }

    private func sanitizeValue(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else {
                return NSNull()
            }
            return sanitizeValue(wrapped)
        }

        if value is NSNull {
            return NSNull()
        }
        if let nested = value as? [String: Any] {
            return sanitize(nested)
        }
        if let array = value as? [Any] {
            return array.map(sanitizeValue)
        }
        return value
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
            if let parsed = DateFormatter.bianlunmiaoNaiveFractional.date(from: value) {
                return parsed
            }
            if let parsed = DateFormatter.bianlunmiaoNaiveNoFraction.date(from: value) {
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

nonisolated private struct RemoteErrorPayload: Decodable, Sendable {
    let code: String
    let message: String
}

nonisolated private struct APITeamAction: Decodable, Sendable {
    let team: APITeam
}

nonisolated private struct APIOk: Decodable, Sendable {
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

private extension DateFormatter {
    static let bianlunmiaoNaiveFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    static let bianlunmiaoNaiveNoFraction: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
