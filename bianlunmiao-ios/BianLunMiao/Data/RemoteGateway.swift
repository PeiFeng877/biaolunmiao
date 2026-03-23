//
//  RemoteGateway.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/17.
//  Updated by Codex on 2026/3/6.
//  Updated by Codex on 2026/3/23.
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

nonisolated struct PhoneSignInResult: Sendable {
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
    let displayName: String?
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
    let createdAt: Date?
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
    let uploadFields: [String: String]?
    let uploadFileFieldName: String?
    let publicUrl: String
    let provider: String
}

final class RemoteGateway {
    private static let localDebugBaseURL = URL(string: "http://127.0.0.1:8788")!
    private static let productionBaseURL = URL(
        string: "https://bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run"
    )!

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
        if let url = RuntimeOverrides.url(named: "BLM_API_BASE_URL") {
            return url
        }
#if DEBUG
        #if targetEnvironment(simulator)
        return localDebugBaseURL
        #else
        return RuntimeOverrides.url(named: "BLM_PROD_API_BASE_URL") ?? productionBaseURL
        #endif
#else
        return RuntimeOverrides.url(named: "BLM_PROD_API_BASE_URL") ?? productionBaseURL
#endif
    }

    func bootstrap() async throws -> RemoteSnapshot {
        _ = try await ensureSession()

        async let currentUser: APIUser = tracedRequest(path: "/users/me")
        async let myTeams: APIList<APITeam> = bootstrapList(path: "/teams/my?limit=100")
        async let discover: APIList<APITeam> = bootstrapList(path: "/teams/discover?limit=100")
        async let joinRequests: APIList<APIJoinRequest> = bootstrapList(path: "/teams/join-requests?scope=related&limit=100")
        async let messages: APIList<APIMessage> = bootstrapList(path: "/messages?limit=100")
        async let tournaments: APIList<APITournament> = bootstrapList(path: "/tournaments?limit=100")
        async let sources: [APIScheduleSource] = bootstrapValue(path: "/schedule/sources", fallback: [])

        let tournamentRows = await tournaments.items
        var allMatches: [APIMatch] = []
        for tournament in tournamentRows {
            let list: APIList<APIMatch> = await bootstrapList(path: "/tournaments/\(tournament.id)/matches?limit=200")
            allMatches.append(contentsOf: list.items)
        }

        return RemoteSnapshot(
            currentUser: try await currentUser,
            myTeams: await myTeams.items,
            discoverTeams: await discover.items,
            joinRequests: await joinRequests.items,
            messages: await messages.items,
            tournaments: tournamentRows,
            matches: allMatches,
            scheduleSources: await sources
        )
    }

    @discardableResult
    func ensureSession() async throws -> APIUser {
        do {
            return try await request(path: "/users/me")
        } catch {
            if Self.isCancellationLike(error) {
                traceAuth("RemoteGateway ensureSession cancelled before refresh fallback")
                throw error
            }
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
            message: "当前未登录，请先完成登录。",
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

    func sendPhoneCode(phone: String) async throws {
        let normalizedPhone = try normalizeMainlandPhone(phone)
        if shouldUsePhoneAuthMock() {
            traceAuth("RemoteGateway mock phone code request accepted for \(normalizedPhone)")
            return
        }

        let _: APIOk = try await request(
            path: "/auth/phone/send-code",
            method: "POST",
            body: ["phone": normalizedPhone],
            requiresAuth: false
        )
    }

    func signInWithPhone(phone: String, code: String) async throws -> PhoneSignInResult {
        let normalizedPhone = try normalizeMainlandPhone(phone)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCode.isEmpty else {
            throw RemoteGatewayError(code: "PHONE_CODE_INVALID", message: "验证码不能为空", statusCode: 422)
        }

        if shouldUsePhoneAuthMock() {
            guard trimmedCode == "1234" else {
                throw RemoteGatewayError(code: "PHONE_CODE_INVALID", message: "验证码错误，请重试。", statusCode: 401)
            }
            return try await issueMockPhoneSession(phone: normalizedPhone)
        }

        let bundle: TokenBundle = try await request(
            path: "/auth/phone/sign-in",
            method: "POST",
            body: [
                "phone": normalizedPhone,
                "code": trimmedCode,
            ],
            requiresAuth: false
        )
        persistTokenBundle(bundle)
        return PhoneSignInResult(user: bundle.user, isNewUser: bundle.isNewUser)
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

    func updateTeamMember(teamID: String, memberID: String, displayName: String) async throws {
        let _: APITeamAction = try await request(
            path: "/teams/\(teamID)/members/\(memberID)",
            method: "PATCH",
            body: ["display_name": displayName]
        )
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

    func deleteAccount() async throws {
        let _: APIDeleteAccountResponse = try await request(path: "/account", method: "DELETE")
    }

    func requestAvatarUploadToken() async throws -> APIUploadToken {
        try await request(path: "/media/avatar-upload-token", method: "POST")
    }

    func requestCoverUploadToken() async throws -> APIUploadToken {
        try await request(path: "/media/cover-upload-token", method: "POST")
    }

    func uploadImage(_ token: APIUploadToken, data: Data) async throws {
        guard let url = URL(string: token.uploadUrl) else {
            throw RemoteGatewayError(code: nil, message: "Invalid upload URL", statusCode: -1)
        }

        var request = URLRequest(url: url)
        request.httpMethod = token.method.uppercased()
        request.timeoutInterval = 30
        let shouldUseMultipartForm = token.method.uppercased() == "POST" && !(token.uploadFields?.isEmpty ?? true)

        if shouldUseMultipartForm {
            let boundary = Self.multipartBoundary()
            let fileFieldName = {
                let trimmed = token.uploadFileFieldName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? "file" : trimmed
            }()
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            for (key, value) in token.uploadHeaders {
                guard key.caseInsensitiveCompare("Content-Type") != .orderedSame else { continue }
                request.setValue(value, forHTTPHeaderField: key)
            }
            let body = Self.makeMultipartBody(
                boundary: boundary,
                fields: token.uploadFields ?? [:],
                fileFieldName: fileFieldName,
                fileName: Self.uploadFileName(from: token.objectKey),
                fileMimeType: Self.uploadMimeType(for: data),
                fileData: data
            )
            request.httpBody = body
            let (_, response) = try await session.data(for: request)
            try Self.validateUploadResponse(response)
            return
        }

        for (key, value) in token.uploadHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.upload(for: request, from: data)
        try Self.validateUploadResponse(response)
    }

    private static func validateUploadResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw RemoteGatewayError(code: nil, message: "Invalid upload response", statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteGatewayError(code: nil, message: "Upload failed: HTTP \(http.statusCode)", statusCode: http.statusCode)
        }
    }

    private static func multipartBoundary() -> String {
        "Boundary-\(UUID().uuidString)"
    }

    private static func uploadFileName(from objectKey: String) -> String {
        let name = URL(fileURLWithPath: objectKey).lastPathComponent
        return name.isEmpty ? "upload.jpg" : name
    }

    private static func uploadMimeType(for data: Data) -> String {
        if data.count >= 4 {
            let prefix = Array(data.prefix(4))
            if prefix.starts(with: [0xFF, 0xD8, 0xFF]) {
                return "image/jpeg"
            }
            if prefix == [0x89, 0x50, 0x4E, 0x47] {
                return "image/png"
            }
            if prefix == [0x47, 0x49, 0x46, 0x38] {
                return "image/gif"
            }
            if prefix == [0x49, 0x49, 0x2A, 0x00] || prefix == [0x4D, 0x4D, 0x00, 0x2A] {
                return "image/tiff"
            }
        }
        return "image/jpeg"
    }

    private static func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        fileMimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()

        for key in fields.keys.sorted() {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(fields[key] ?? "")\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: \(fileMimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return body
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
        if let override = RuntimeOverrides.string(named: "BLM_DEBUG_PUBLIC_ID")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            defaults.set(override, forKey: debugUserKey)
            return override
        }
        if let existing = defaults.string(forKey: debugUserKey), !existing.isEmpty {
            return existing
        }
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
        let value = "U9\(suffix)"
        defaults.set(value, forKey: debugUserKey)
        return value
    }

    private func processIdentityTokenFromEnvironment() -> String? {
        guard let raw = RuntimeOverrides.string(named: "BLM_APPLE_IDENTITY_TOKEN") else {
            return nil
        }
        return raw.isEmpty ? nil : raw
    }

    private func shouldEnableDebugSessionFallback() -> Bool {
        RuntimeOverrides.isEnabled("BLM_ENABLE_DEBUG_SESSION_FALLBACK")
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
            if remote.code == "ACCOUNT_DELETED" {
                clearSessionTokens()
                throw remote
            }
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

    private func rpcRequestDescriptor(
        path: String,
        method: String,
        body: [String: Any]?
    ) throws -> (action: String, params: [String: Any]) {
        guard let components = URLComponents(string: "https://rpc.local\(path)") else {
            throw RemoteGatewayError(code: nil, message: "Invalid request path", statusCode: -1)
        }

        let normalizedMethod = method.uppercased()
        let normalizedPath = components.path
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { item in
                (item.name, item.value ?? "")
            }
        )

        func merged(_ values: [String: Any] = [:]) -> [String: Any] {
            var output = body ?? [:]
            for (key, value) in values {
                output[key] = value
            }
            return output
        }

        switch (normalizedMethod, normalizedPath) {
        case ("GET", "/users/me"):
            return ("users.me.get", [:])
        case ("PUT", "/users/me"):
            return ("users.me.update", body ?? [:])
        case ("GET", "/users/search"):
            return ("users.search", queryItems)
        case ("POST", "/teams"):
            return ("teams.create", body ?? [:])
        case ("GET", "/teams/my"):
            return ("teams.my.list", queryItems)
        case ("GET", "/teams/discover"):
            return ("teams.discover.list", queryItems)
        case ("GET", "/teams/join-requests"):
            return ("teams.join_requests.list", queryItems)
        case ("GET", "/messages"):
            return ("messages.list", queryItems)
        case ("GET", "/tournaments"):
            return ("tournaments.list", queryItems)
        case ("POST", "/tournaments"):
            return ("tournaments.create", body ?? [:])
        case ("GET", "/schedule/sources"):
            return ("schedule.sources.list", [:])
        case ("DELETE", "/account"):
            return ("account.delete", [:])
        case ("POST", "/media/avatar-upload-token"):
            return ("media.avatar_upload_token", body ?? [:])
        case ("POST", "/media/cover-upload-token"):
            return ("media.cover_upload_token", body ?? [:])
        case ("POST", "/schedule/sources"):
            return ("schedule.sources.create", body ?? [:])
        case ("POST", "/auth/refresh"):
            return ("auth.refresh", body ?? [:])
        case ("POST", "/auth/apple"):
            return ("auth.apple.sign_in", body ?? [:])
        case ("POST", "/auth/phone/send-code"):
            return ("auth.phone.send_code", body ?? [:])
        case ("POST", "/auth/phone/sign-in"):
            return ("auth.phone.sign_in", body ?? [:])
        case ("POST", "/auth/debug-token"):
            return ("auth.debug_token", body ?? [:])
        default:
            break
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+)$/) {
            let teamID = String(match.1)
            if normalizedMethod == "GET" {
                return ("teams.detail.get", ["team_id": teamID])
            }
            if normalizedMethod == "PUT" {
                return ("teams.update", merged(["team_id": teamID]))
            }
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+):dissolve$/), normalizedMethod == "POST" {
            return ("teams.dissolve", ["team_id": String(match.1)])
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+):transfer-owner$/), normalizedMethod == "POST" {
            return ("teams.transfer_owner", [
                "team_id": String(match.1),
                "member_id": body?["memberId"] as Any,
            ])
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+)\/members\/([^\/]+):toggle-admin$/), normalizedMethod == "POST" {
            return ("teams.member.toggle_admin", [
                "team_id": String(match.1),
                "member_id": String(match.2),
            ])
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+)\/members\/([^\/]+)$/), normalizedMethod == "DELETE" {
            return ("teams.member.remove", [
                "team_id": String(match.1),
                "member_id": String(match.2),
            ])
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+)\/members\/([^\/]+)$/), normalizedMethod == "PATCH" {
            return ("teams.member.update", merged([
                "team_id": String(match.1),
                "member_id": String(match.2),
            ]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/([^\/]+)\/join-requests$/), normalizedMethod == "POST" {
            return ("teams.join_request.submit", merged(["team_id": String(match.1)]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/teams\/join-requests\/([^:]+):(approve|reject)$/), normalizedMethod == "POST" {
            return ("teams.join_request.review", [
                "request_id": String(match.1),
                "approve": String(match.2) == "approve",
            ])
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/([^\/]+)\/matches$/) {
            let tournamentID = String(match.1)
            if normalizedMethod == "GET" {
                var params = queryItems.reduce(into: [String: Any]()) { partialResult, item in
                    partialResult[item.key] = item.value
                }
                params["tournament_id"] = tournamentID
                return ("tournaments.matches.list", params)
            }
            if normalizedMethod == "POST" {
                return ("matches.create", merged(["tournament_id": tournamentID]))
            }
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/([^\/]+)$/), normalizedMethod == "PUT" {
            return ("tournaments.update", merged(["tournament_id": String(match.1)]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/matches\/([^\/]+)$/), normalizedMethod == "PUT" {
            return ("matches.update", merged(["match_id": String(match.1)]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/matches\/([^:]+):assign-teams$/), normalizedMethod == "POST" {
            return ("matches.assign_teams", merged(["match_id": String(match.1)]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/matches\/([^\/]+)\/rosters\/([^\/]+)$/), normalizedMethod == "PUT" {
            return ("matches.roster.save", merged([
                "match_id": String(match.1),
                "team_id": String(match.2),
            ]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/matches\/([^:]+):advance-status$/), normalizedMethod == "POST" {
            return ("matches.advance_status", merged(["match_id": String(match.1)]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/tournaments\/matches\/([^\/]+)\/result$/), normalizedMethod == "PUT" {
            return ("matches.result.record", merged(["match_id": String(match.1)]))
        }

        if let match = normalizedPath.firstMatch(of: /^\/messages\/([^:]+):ack$/), normalizedMethod == "POST" {
            return ("messages.ack", ["message_id": String(match.1)])
        }

        if let match = normalizedPath.firstMatch(of: /^\/schedule\/sources\/([^\/]+)$/) {
            let sourceID = String(match.1)
            if normalizedMethod == "PUT" {
                return ("schedule.sources.toggle", merged(["source_id": sourceID]))
            }
            if normalizedMethod == "DELETE" {
                return ("schedule.sources.delete", ["source_id": sourceID])
            }
        }

        throw RemoteGatewayError(
            code: nil,
            message: "未支持的 RPC 映射：\(normalizedMethod) \(normalizedPath)",
            statusCode: -1
        )
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

    private func bootstrapList<T: Decodable & Sendable>(path: String) async -> APIList<T> {
        await bootstrapValue(path: path, fallback: APIList(items: [], nextCursor: nil))
    }

    private func bootstrapValue<T: Decodable & Sendable>(path: String, fallback: T) async -> T {
        do {
            return try await tracedRequest(path: path)
        } catch {
            traceAuth("RemoteGateway bootstrap fallback for \(path): \(error.localizedDescription)")
            return fallback
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let descriptor = try rpcRequestDescriptor(path: path, method: method, body: body)
        let url = try makeRPCURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            if let token = defaults.string(forKey: accessKey), !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        request.httpBody = try JSONSerialization.data(
            withJSONObject: sanitize([
                "action": descriptor.action,
                "params": descriptor.params,
                "request_id": UUID().uuidString.lowercased(),
            ]),
            options: []
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            traceAuth("RemoteGateway transport failed for \(descriptor.action): \(error.localizedDescription)")
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            throw RemoteGatewayError(code: nil, message: "Invalid response", statusCode: -1)
        }

        guard (200..<300).contains(http.statusCode) else {
            if let remote = try? decoder.decode(RemoteErrorPayload.self, from: data) {
                throw RemoteGatewayError(
                    code: remote.code,
                    message: localizedRemoteMessage(code: remote.code, fallback: remote.message),
                    statusCode: http.statusCode
                )
            }
            throw RemoteGatewayError(code: nil, message: "HTTP \(http.statusCode)", statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let payload = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            traceAuth("RemoteGateway decode failed for \(descriptor.action): \(payload)")
            throw RemoteGatewayError(
                code: nil,
                message: "服务器响应格式错误，请稍后重试。",
                statusCode: -1
            )
        }
    }

    private func makeRPCURL() throws -> URL {
        let base = baseURL.absoluteString.hasSuffix("/") ? baseURL.absoluteString : "\(baseURL.absoluteString)/"
        guard let url = URL(string: "api", relativeTo: URL(string: base))?.absoluteURL else {
            throw RemoteGatewayError(code: nil, message: "Invalid RPC URL", statusCode: -1)
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

    private func localizedRemoteMessage(code: String, fallback: String) -> String {
        switch code {
        case "ACCOUNT_DELETED":
            return "这个账号已经注销，暂时无法登录。"
        case "PHONE_INVALID":
            return "请输入有效的中国大陆手机号。"
        case "PHONE_CODE_INVALID":
            return "验证码错误，请重试。"
        case "PHONE_CODE_EXPIRED":
            return "验证码已过期，请重新获取。"
        case "PHONE_CODE_TOO_FREQUENT":
            return "获取验证码过于频繁，请稍后再试。"
        case "PHONE_AUTH_NOT_AVAILABLE":
            return "手机号登录暂时不可用，请稍后再试。"
        default:
            return fallback
        }
    }

    private static func isCancellationLike(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func shouldUsePhoneAuthMock() -> Bool {
        RuntimeOverrides.isEnabled("BLM_PHONE_AUTH_MOCK")
    }

    private func normalizeMainlandPhone(_ rawPhone: String) throws -> String {
        let trimmed = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter { $0.isNumber }

        if digits.count == 11, digits.hasPrefix("1") {
            return "+86\(digits)"
        }

        if digits.count == 13, digits.hasPrefix("86") {
            return "+\(digits)"
        }

        if trimmed.hasPrefix("+86"), digits.count == 13, digits.hasPrefix("86") {
            return "+\(digits)"
        }

        throw RemoteGatewayError(code: "PHONE_INVALID", message: "请输入有效的中国大陆手机号。", statusCode: 422)
    }

    private func issueDebugSessionBundle(
        publicID: String? = nil,
        nickname: String? = nil
    ) async throws -> TokenBundle {
        let payload: [String: Any] = [
            "public_id": (publicID ?? debugPublicID()),
            "nickname": (nickname ?? "辩论喵调试用户"),
        ]
        let bundle: TokenBundle = try await request(
            path: "/auth/debug-token",
            method: "POST",
            body: payload,
            requiresAuth: false
        )
        persistTokenBundle(bundle)
        return bundle
    }

    private func issueDebugSession(publicID: String? = nil, nickname: String? = nil) async throws -> APIUser {
        try await issueDebugSessionBundle(publicID: publicID, nickname: nickname).user
    }

    private func issueMockPhoneSession(phone: String) async throws -> PhoneSignInResult {
        let bundle = try await issueDebugSessionBundle(
            publicID: mockPhonePublicID(for: phone),
            nickname: "辩论喵用户"
        )
        let isNewUser = registerMockPhoneLoginIfNeeded(phone)
        return PhoneSignInResult(user: bundle.user, isNewUser: isNewUser)
    }

    private func mockPhonePublicID(for phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        return "P\(digits)"
    }

    private func registerMockPhoneLoginIfNeeded(_ phone: String) -> Bool {
        let key = mockPhoneLoginKey(for: phone)
        let isNewUser = !defaults.bool(forKey: key)
        defaults.set(true, forKey: key)
        return isNewUser
    }

    private func mockPhoneLoginKey(for phone: String) -> String {
        "remote.phone.mock.seen.\(phone.replacingOccurrences(of: "+", with: ""))"
    }
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

nonisolated private struct APIDeleteAccountResponse: Decodable, Sendable {
    let ok: Bool
    let status: String
    let deletedAt: Date
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

private extension Data {
    mutating func appendString(_ string: String) {
        append(contentsOf: string.utf8)
    }
}
