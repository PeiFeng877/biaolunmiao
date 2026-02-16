//
//  AppStore+TeamHelpers.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的队伍、头像与权限判定上下文。
//  OUTPUT: 结构化的团队关联维护与文件存储辅助逻辑。
//  POS: 数据层 Store 扩展。
//

import Foundation

extension AppStore {
    func refreshTournamentStatus(tournamentId: UUID) {
        // 赛事状态由创建/编辑页手动维护，场次变更不自动改写赛事状态。
        guard tournaments.contains(where: { $0.id == tournamentId }) else { return }
    }

    func removeTeamAssociations(teamId: UUID) {
        let removedMatches = matches.filter { $0.teamAId == teamId || $0.teamBId == teamId }
        let affectedTournamentIds = Set(removedMatches.map(\.tournamentId))
        let removedMatchIds = Set(removedMatches.map(\.id))

        for tournamentIndex in tournaments.indices {
            tournaments[tournamentIndex].participants.removeAll { $0.teamId == teamId }
        }
        matches.removeAll { $0.teamAId == teamId || $0.teamBId == teamId }
        rosters.removeAll { $0.teamId == teamId }
        inboxMessages.removeAll { message in
            guard let relatedMatchId = message.relatedMatchId else { return false }
            return removedMatchIds.contains(relatedMatchId)
        }

        for tournamentId in affectedTournamentIds {
            refreshTournamentStatus(tournamentId: tournamentId)
        }
    }

    func storeTeamAvatar(_ data: Data, teamId: UUID) -> String? {
        let directoryURL = teamAvatarDirectoryURL()
        let fileURL = directoryURL
            .appendingPathComponent("team-\(teamId.uuidString)-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            return nil
        }
    }

    func storeUserAvatar(_ data: Data, userId: UUID) -> String? {
        let directoryURL = userAvatarDirectoryURL()
        let fileURL = directoryURL
            .appendingPathComponent("user-\(userId.uuidString)-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            return nil
        }
    }

    func teamAvatarDirectoryURL() -> URL {
        let rootURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return rootURL.appendingPathComponent("TeamAvatars", isDirectory: true)
    }

    func userAvatarDirectoryURL() -> URL {
        let rootURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return rootURL.appendingPathComponent("UserAvatars", isDirectory: true)
    }

    func replaceTeam(_ team: Team) {
        if let idx = teams.firstIndex(where: { $0.id == team.id }) {
            teams[idx] = team
        }

        if let idx = discoverableTeams.firstIndex(where: { $0.id == team.id }) {
            discoverableTeams[idx] = team
        }

        for tIndex in tournaments.indices {
            if let idx = tournaments[tIndex].participants.firstIndex(where: { $0.teamId == team.id }) {
                tournaments[tIndex].participants[idx].team = team
            }
        }

        for mIndex in matches.indices {
            if matches[mIndex].teamAId == team.id {
                matches[mIndex].teamA = team
            }
            if matches[mIndex].teamBId == team.id {
                matches[mIndex].teamB = team
            }
        }
    }

    func canCurrentUserManageMatch(index: Int, candidateTeamAId: UUID? = nil, candidateTeamBId: UUID? = nil) -> Bool {
        let tournamentId = matches[index].tournamentId
        let canManageTournament = canCurrentUserManageTournament(tournamentId: tournamentId)
        if canManageTournament { return true }

        let teamAId = candidateTeamAId ?? matches[index].teamAId
        let teamBId = candidateTeamBId ?? matches[index].teamBId
        let canManageAssignedTeam =
            (teamAId.map { canCurrentUserManageTeam(teamId: $0) } ?? false) ||
            (teamBId.map { canCurrentUserManageTeam(teamId: $0) } ?? false)
        return canManageAssignedTeam
    }
}
