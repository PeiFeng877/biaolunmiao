//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  Updated by Codex on 2026/3/4.
//
//  INPUT: AppStore 与主导航结构。
//  OUTPUT: 应用入口、登录门禁与全局主题注入。
//  POS: App 入口层。
//

import AuthenticationServices
import ImageIO
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
        case .signedOut, .syncing:
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
    private static let userAgreementURL = URL(string: "https://flat-saguaro-662.notion.site/318a80cd73cf801a9612e3ea6eb9c349")!
    private static let privacyPolicyURL = URL(string: "https://flat-saguaro-662.notion.site/314a80cd73cf8050aa62d4b71935d326")!

    @ObservedObject var store: AppStore
    @State private var localErrorMessage: String?
    @State private var authDebugState = "idle"

    private var isSigningIn: Bool {
        store.authState == .syncing
    }

    var body: some View {
        ZStack {
            AppColor.authBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topContent

                Spacer(minLength: AppSpacing.xxl)

                bottomContent
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

    private var topContent: some View {
        VStack(spacing: AppSpacing.m) {
            LoginHeroImage()

            Text("辩论？喵～")
                .font(AppFont.hero())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityIdentifier("login_gate_title")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, AppSpacing.l)
        .padding(.bottom, AppSpacing.xxl)
    }

    private var bottomContent: some View {
        VStack(spacing: AppSpacing.s) {
            if let message = displayedErrorMessage {
                Text(message)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.danger)
                    .multilineTextAlignment(.center)
            }

            signInButton
                .animation(.easeInOut(duration: 0.2), value: isSigningIn)

            AuthAgreementText(
                userAgreementURL: Self.userAgreementURL,
                privacyPolicyURL: Self.privacyPolicyURL
            )

            if Self.isUITestMode {
                Text(authDebugState)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityIdentifier("auth_debug_state")
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func traceAuth(_ message: String) {
        Self.authLogger.notice("\(message)")
        print("[AuthFlow] \(message)")
    }

    @ViewBuilder
    private var signInButton: some View {
        if isSigningIn {
            AuthLoadingButton()
                .accessibilityIdentifier("auth_sign_in_loading_button")
        } else {
            SignInWithAppleButton(.signIn) { request in
                authDebugState = "button_tapped"
                traceAuth("Apple sign-in state: button_tapped")
                request.requestedScopes = [.fullName, .email]
                authDebugState = "request_prepared"
                traceAuth("Apple sign-in state: request_prepared")
                authDebugState = "request_started"
                traceAuth("Apple sign-in state: request_started")
            } onCompletion: { result in
                handleAppleAuthorization(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .accessibilityIdentifier("auth_sign_in_with_apple_button")
        }
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

private struct AuthLoadingButton: View {
    var body: some View {
        HStack(spacing: AppSpacing.s) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)

            Text("登录中")
                .font(AppFont.body())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Color.black, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("登录中")
        .accessibilityAddTraits(.isButton)
    }
}

private struct LoginHeroImage: View {
    var body: some View {
        AnimatedPNGView(
            resourceName: "auth_cat_yarn_hero_apng",
            fallbackAssetName: "auth_cat_yarn_hero",
            playbackRate: 1.5
        )
            .frame(maxWidth: 320, minHeight: 190, maxHeight: 190)
            .accessibilityHidden(true)
    }
}

private struct AuthAgreementText: View {
    let userAgreementURL: URL
    let privacyPolicyURL: URL

    var body: some View {
        ViewThatFits {
            agreementLine
            agreementStack
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(AppColor.textSecondary)
        .multilineTextAlignment(.center)
    }

    private var agreementLine: some View {
        HStack(spacing: 0) {
            Text("阅读并同意")
            Link("《用户协议》", destination: userAgreementURL)
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityIdentifier("login_gate_user_agreement_link")
            Text(" ")
            Link("《隐私政策》", destination: privacyPolicyURL)
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityIdentifier("login_gate_privacy_policy_link")
        }
    }

    private var agreementStack: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("阅读并同意")
            HStack(spacing: AppSpacing.xs) {
                Link("《用户协议》", destination: userAgreementURL)
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityIdentifier("login_gate_user_agreement_link")
                Link("《隐私政策》", destination: privacyPolicyURL)
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityIdentifier("login_gate_privacy_policy_link")
            }
        }
    }
}

private struct AnimatedPNGView: UIViewRepresentable {
    let resourceName: String
    let fallbackAssetName: String
    let playbackRate: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.image = UIImage(named: fallbackAssetName)
        context.coordinator.attach(to: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        context.coordinator.render(
            resourceName: resourceName,
            fallbackAssetName: fallbackAssetName,
            playbackRate: playbackRate
        )
    }

    static func dismantleUIView(_ uiView: UIImageView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private static let minimumFrameDelay = 0.02
        private static let thumbnailMaxPixelSize = 640

        private weak var imageView: UIImageView?
        private let animationQueue = DispatchQueue(label: "com.wenwan.BianLunMiao.authHeroAnimation")
        private var currentResourceName: String?
        private var fallbackAssetName: String?
        private var currentPlaybackRate: Double?
        private var generation = UUID()
        private var shouldStop = false
        private var scheduledFrameWorkItem: DispatchWorkItem?
        private var foregroundObserver: NSObjectProtocol?
        private var backgroundObserver: NSObjectProtocol?

        deinit {
            stop()
            removeObservers()
        }

        func attach(to imageView: UIImageView) {
            self.imageView = imageView
            installObserversIfNeeded()
        }

        func render(resourceName: String, fallbackAssetName: String, playbackRate: Double) {
            self.fallbackAssetName = fallbackAssetName

            if currentResourceName == resourceName,
               currentPlaybackRate == playbackRate,
               shouldStop == false {
                return
            }

            stop()
            currentResourceName = resourceName
            self.fallbackAssetName = fallbackAssetName
            currentPlaybackRate = playbackRate
            imageView?.image = UIImage(named: fallbackAssetName)

            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png") else {
                return
            }

            let runID = UUID()
            generation = runID
            shouldStop = false

            animationQueue.async { [weak self] in
                guard let self else { return }
                guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }

                let frameCount = CGImageSourceGetCount(imageSource)
                guard frameCount > 0 else { return }

                let frameDurations = self.makeFrameDurations(
                    imageSource: imageSource,
                    frameCount: frameCount,
                    playbackRate: playbackRate
                )

                self.scheduleFrame(
                    imageSource: imageSource,
                    frameCount: frameCount,
                    frameDurations: frameDurations,
                    frameIndex: 0,
                    runID: runID
                )
            }
        }

        func stop() {
            shouldStop = true
            generation = UUID()
            scheduledFrameWorkItem?.cancel()
            scheduledFrameWorkItem = nil
        }

        private func installObserversIfNeeded() {
            guard foregroundObserver == nil, backgroundObserver == nil else { return }

            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.stop()
            }

            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard
                    let self,
                    let currentResourceName = self.currentResourceName,
                    let fallbackAssetName = self.fallbackAssetName
                else {
                    return
                }

                self.render(
                    resourceName: currentResourceName,
                    fallbackAssetName: fallbackAssetName,
                    playbackRate: self.currentPlaybackRate ?? 1
                )
            }
        }

        private func scheduleFrame(
            imageSource: CGImageSource,
            frameCount: Int,
            frameDurations: [TimeInterval],
            frameIndex: Int,
            runID: UUID
        ) {
            guard shouldStop == false, generation == runID else { return }

            let normalizedIndex = frameIndex % frameCount
            guard let cgImage = makeFrameImage(imageSource: imageSource, frameIndex: normalizedIndex) else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.shouldStop == false,
                    self.generation == runID,
                    let imageView = self.imageView
                else {
                    return
                }

                imageView.image = UIImage(
                    cgImage: cgImage,
                    scale: UIScreen.main.scale,
                    orientation: .up
                )
            }

            let delay = frameDurations[normalizedIndex]
            let nextWorkItem = DispatchWorkItem { [weak self] in
                self?.scheduleFrame(
                    imageSource: imageSource,
                    frameCount: frameCount,
                    frameDurations: frameDurations,
                    frameIndex: normalizedIndex + 1,
                    runID: runID
                )
            }
            scheduledFrameWorkItem = nextWorkItem
            animationQueue.asyncAfter(deadline: .now() + delay, execute: nextWorkItem)
        }

        private func makeFrameImage(imageSource: CGImageSource, frameIndex: Int) -> CGImage? {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixelSize
            ]

            return CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                frameIndex,
                thumbnailOptions as CFDictionary
            ) ?? CGImageSourceCreateImageAtIndex(imageSource, frameIndex, nil)
        }

        private func makeFrameDurations(
            imageSource: CGImageSource,
            frameCount: Int,
            playbackRate: Double
        ) -> [TimeInterval] {
            let normalizedPlaybackRate = max(playbackRate, 0.1)

            return (0..<frameCount).map { index in
                let frameProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any]
                let pngProperties = frameProperties?[kCGImagePropertyPNGDictionary] as? [CFString: Any]
                let unclampedDelay = pngProperties?[kCGImagePropertyAPNGUnclampedDelayTime] as? Double
                let delay = pngProperties?[kCGImagePropertyAPNGDelayTime] as? Double
                let rawDelay = unclampedDelay ?? delay ?? 0.05
                let boundedDelay = max(rawDelay, Self.minimumFrameDelay)
                return boundedDelay / normalizedPlaybackRate
            }
        }

        private func removeObservers() {
            if let backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver)
            }
            if let foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver)
            }
            backgroundObserver = nil
            foregroundObserver = nil
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
