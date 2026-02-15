//
//  ProfileSettingsViewModel.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的当前用户与资料更新动作。
//  OUTPUT: 设置页资料、协议入口与编辑资料状态。
//  POS: 我的设置视图模型。
//

import Foundation
import Combine

final class ProfileSettingsViewModel: ObservableObject {
    @Published private(set) var currentUser: User
    @Published var nicknameDraft: String = ""
    @Published var showEditProfileSheet = false
    @Published var showUserAgreementSheet = false
    @Published var showPrivacyPolicySheet = false

    private let store: AppStore
    init(store: AppStore) {
        self.store = store
        self.currentUser = store.currentUser

        store.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentUser)
    }

    func beginEditProfile() {
        nicknameDraft = currentUser.nickname
        showEditProfileSheet = true
    }

    @discardableResult
    func saveProfile() -> Bool {
        let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        store.updateCurrentUserProfile(nickname: trimmed)
        showEditProfileSheet = false
        return true
    }

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "v\(shortVersion) (\(build))"
    }
}
