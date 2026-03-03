//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  Updated by Codex on 2026/3/3.
//
//  INPUT: AppStore 与主导航结构。
//  OUTPUT: 应用入口、登录门禁与全局主题注入。
//  POS: App 入口层。
//

import AuthenticationServices
import OSLog
import SwiftUI
import UIKit

@main
struct BianLunMiaoApp: App {
    @StateObject private var store: AppStore

    init() {
        Self.applyUITestRuntimeConfiguration()
        _store = StateObject(wrappedValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
            .tint(AppColor.eventAccentStrong)
            .toolbar(.visible, for: .tabBar)
        }
    }

    private static func applyUITestRuntimeConfiguration() {
        let env = ProcessInfo.processInfo.environment
        guard env["BLM_UI_TEST_MODE"] == "1" else { return }

        UIView.setAnimationsEnabled(false)

        guard env["BLM_UI_TEST_RESET_STATE"] == "1",
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        UserDefaults.standard.synchronize()
    }
}

private struct AppRootView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        switch store.authState {
        case .restoringSession:
            RootStatusView(
                title: "正在恢复会话",
                subtitle: "正在连接正式服务并同步你的数据。",
                showsProgress: true
            )
        case .syncing:
            RootStatusView(
                title: "正在同步数据",
                subtitle: "登录成功，正在拉取远端快照。",
                showsProgress: true
            )
        case .signedOut:
            LoginGateView(store: store)
        case .ready:
            MainTabsView(store: store)
        case .fatalError(let message):
            RootErrorView(message: message, onRetry: store.retryBootstrap)
        }
    }
}

private struct MainTabsView: View {
    let store: AppStore

    var body: some View {
        TabView {
            TeamListView(store: store)
                .tabItem {
                    Label("队伍", systemImage: "person.crop.circle")
                }

            TournamentListView(store: store)
                .tabItem {
                    Label("赛事", systemImage: "trophy")
                }

            ScheduleView(store: store)
                .tabItem {
                    Label("日程", systemImage: "calendar")
                }

            MessageHubView(store: store)
                .tabItem {
                    Label("消息", systemImage: "bubble.left.and.bubble.right")
                }

            MyHubView(store: store)
                .tabItem {
                    Label("我的", systemImage: "person.text.rectangle")
                }
        }
    }
}

private struct LoginGateView: View {
    private static let authLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wenwan.BianLunMiao",
        category: "AuthFlow"
    )
    private static let isUITestMode = ProcessInfo.processInfo.environment["BLM_UI_TEST_MODE"] == "1"

    @ObservedObject var store: AppStore
    @State private var localErrorMessage: String?
    @State private var authDebugState = "idle"

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                VStack(spacing: AppSpacing.m) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(AppColor.primaryStrong)

                    Text("使用 Apple 登录")
                        .font(AppFont.hero())
                        .foregroundStyle(AppColor.textPrimary)

                    Text("提审版本只接受真实账号链路，不再展示本地演示数据。")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                AppleSignInControl { state in
                    authDebugState = state
                    traceAuth("Apple sign-in state: \(state)")
                } onCompletion: { result in
                    handleAppleAuthorization(result)
                }
                .frame(height: 52)

                if Self.isUITestMode {
                    Text(authDebugState)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityIdentifier("auth_debug_state")
                }

                if let message = displayedErrorMessage {
                    Text(message)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.danger)
                        .multilineTextAlignment(.center)
                }

                AppButton("重新检查服务", variant: .secondary) {
                    localErrorMessage = nil
                    store.retryBootstrap()
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.xxl)
        }
        .onChange(of: store.authState) { _, newState in
            if newState == .ready {
                localErrorMessage = nil
            }
        }
    }

    private var displayedErrorMessage: String? {
        localErrorMessage ?? store.authErrorMessage
    }

    private func traceAuth(_ message: String) {
        Self.authLogger.notice("\(message)")
        print("[AuthFlow] \(message)")
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            traceAuth("Apple sign-in authorization succeeded")
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                traceAuth("Apple sign-in credential type mismatch")
                authDebugState = "invalid_credential"
                localErrorMessage = "Apple 授权返回格式异常，请重试。"
                return
            }
            guard
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                !identityToken.isEmpty
            else {
                traceAuth("Apple sign-in missing identity token")
                authDebugState = "missing_identity_token"
                localErrorMessage = "未获取到 Apple identity token，请重试。"
                return
            }

            authDebugState = "sending_to_backend"
            localErrorMessage = nil
            Task {
                do {
                    try await store.signInWithApple(
                        identityToken: identityToken,
                        firstName: credential.fullName?.givenName,
                        lastName: credential.fullName?.familyName
                    )
                    authDebugState = "signed_in"
                    traceAuth("Apple sign-in finished successfully")
                } catch {
                    authDebugState = "backend_failure"
                    traceAuth("Apple sign-in failed after authorization: \(error.localizedDescription)")
                    localErrorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            authDebugState = "authorization_failed"
            traceAuth("Apple sign-in authorization failed: \(error.localizedDescription)")
            localErrorMessage = error.localizedDescription
        }
    }
}

private struct AppleSignInControl: UIViewRepresentable {
    let onStateChange: (String) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange, onCompletion: onCompletion)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = AppRadius.m
        button.accessibilityIdentifier = "auth_sign_in_with_apple_button"
        button.addTarget(context.coordinator, action: #selector(Coordinator.beginSignIn), for: .touchUpInside)
        context.coordinator.button = button
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.button = uiView
        context.coordinator.onStateChange = onStateChange
        context.coordinator.onCompletion = onCompletion
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        var onStateChange: (String) -> Void
        var onCompletion: (Result<ASAuthorization, Error>) -> Void
        weak var button: ASAuthorizationAppleIDButton?

        init(
            onStateChange: @escaping (String) -> Void,
            onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
        ) {
            self.onStateChange = onStateChange
            self.onCompletion = onCompletion
        }

        @objc
        func beginSignIn() {
            onStateChange("button_tapped")

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            onStateChange("request_prepared")

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
            onStateChange("request_started")
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            if let window = button?.window {
                return window
            }

            let windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            return windowScene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

private struct RootStatusView: View {
    let title: String
    let subtitle: String
    let showsProgress: Bool

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: AppSpacing.l) {
                if showsProgress {
                    ProgressView()
                        .tint(AppColor.primaryStrong)
                }

                Text(title)
                    .font(AppFont.section())
                    .foregroundStyle(AppColor.textPrimary)

                Text(subtitle)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
    }
}

private struct RootErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: AppSpacing.l) {
                AppEmptyState(
                    title: "服务暂时不可用",
                    subtitle: message,
                    systemImage: "wifi.exclamationmark"
                )

                AppButton("重新连接", variant: .primary, action: onRetry)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
    }
}
