//
//  BianLunMiaoApp.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  Updated by Codex on 2026/3/19.
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
                .preferredColorScheme(Self.uiTestPreferredColorScheme)
                .tint(AppColor.eventAccentStrong)
                .toolbar(.visible, for: .tabBar)
        }
    }

    private static func applyUITestRuntimeConfiguration() {
        guard RuntimeOverrides.isEnabled("BLM_UI_TEST_MODE") else { return }

        UIView.setAnimationsEnabled(false)

        guard RuntimeOverrides.isEnabled("BLM_UI_TEST_RESET_STATE"),
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        UserDefaults.standard.synchronize()
    }

    private static var uiTestPreferredColorScheme: ColorScheme? {
        switch RuntimeOverrides.uiTestColorScheme {
        case .dark:
            return .dark
        case .light:
            return .light
        case nil:
            return nil
        }
    }
}

private struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var store: AppStore

    var body: some View {
        Group {
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
                switch store.postLoginDestination {
                case .teamHome:
                    MainTabsView(store: store)
                case .profileSetup:
                    NewUserProfileSetupView(store: store)
                }
            case .fatalError(let message):
                RootErrorView(message: message, onRetry: store.retryBootstrap)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            store.refreshIfPossible()
        }
    }
}

private struct MainTabsView: View {
    private enum MainTab: Int, Hashable {
        case team
        case tournament
        case schedule
        case message
        case my

        var title: String {
            switch self {
            case .team:
                return "队伍"
            case .tournament:
                return "赛事"
            case .schedule:
                return "日程"
            case .message:
                return "消息"
            case .my:
                return "我的"
            }
        }

        var systemImage: String {
            switch self {
            case .team:
                return "person.crop.circle"
            case .tournament:
                return "trophy"
            case .schedule:
                return "calendar"
            case .message:
                return "bubble.left.and.bubble.right"
            case .my:
                return "person.text.rectangle"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .team:
                return "main_tab_team"
            case .tournament:
                return "main_tab_tournament"
            case .schedule:
                return "main_tab_schedule"
            case .message:
                return "main_tab_message"
            case .my:
                return "main_tab_my"
            }
        }
    }

    let store: AppStore
    @State private var selectedTab: MainTab = .team
    @State private var scheduleScrollToTodayToken = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TeamListView(store: store)
                .tag(MainTab.team)
                .tabItem {
                    Label(MainTab.team.title, systemImage: MainTab.team.systemImage)
                        .accessibilityIdentifier(MainTab.team.accessibilityIdentifier)
                }

            TournamentListView(store: store)
                .tag(MainTab.tournament)
                .tabItem {
                    Label(MainTab.tournament.title, systemImage: MainTab.tournament.systemImage)
                        .accessibilityIdentifier(MainTab.tournament.accessibilityIdentifier)
                }

            ScheduleView(store: store, scrollToTodayToken: scheduleScrollToTodayToken)
                .tag(MainTab.schedule)
                .tabItem {
                    Label(MainTab.schedule.title, systemImage: MainTab.schedule.systemImage)
                        .accessibilityIdentifier(MainTab.schedule.accessibilityIdentifier)
                }

            MessageHubView(store: store)
                .tag(MainTab.message)
                .tabItem {
                    Label(MainTab.message.title, systemImage: MainTab.message.systemImage)
                        .accessibilityIdentifier(MainTab.message.accessibilityIdentifier)
                }

            MyHubView(store: store)
                .tag(MainTab.my)
                .tabItem {
                    Label(MainTab.my.title, systemImage: MainTab.my.systemImage)
                        .accessibilityIdentifier(MainTab.my.accessibilityIdentifier)
                }
        }
        .accessibilityIdentifier("main_tab_container")
        .background(
            TabBarReselectObserver { index in
                guard let tab = MainTab(rawValue: index) else { return }
                if tab == .schedule {
                    scheduleScrollToTodayToken += 1
                }
            }
        )
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .tournament || newValue == .schedule else { return }
            store.refreshIfPossible()
        }
    }
}

private struct TabBarReselectObserver: UIViewControllerRepresentable {
    let onReselect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReselect: onReselect)
    }

    func makeUIViewController(context: Context) -> ObserverViewController {
        let controller = ObserverViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.coordinator = context.coordinator
        uiViewController.attachIfNeeded()
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        private let onReselect: (Int) -> Void
        private var lastSelectedIndex: Int?
        private var lastTapAt: Date = .distantPast
        private let doubleTapThreshold: TimeInterval = 0.45

        init(onReselect: @escaping (Int) -> Void) {
            self.onReselect = onReselect
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let selectedIndex = tabBarController.selectedIndex
            let now = Date()
            if lastSelectedIndex == selectedIndex, now.timeIntervalSince(lastTapAt) <= doubleTapThreshold {
                onReselect(selectedIndex)
            }
            lastSelectedIndex = selectedIndex
            lastTapAt = now
        }
    }

    final class ObserverViewController: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
        }

        func attachIfNeeded() {
            guard let tabBarController, let coordinator else { return }
            tabBarController.delegate = coordinator
        }
    }
}

private struct LoginGateView: View {
    private static let authLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wenwan.BianLunMiao",
        category: "AuthFlow"
    )
    private static let isUITestMode = RuntimeOverrides.isEnabled("BLM_UI_TEST_MODE")
    private static let userAgreementURL = URL(string: "https://flat-saguaro-662.notion.site/318a80cd73cf801a9612e3ea6eb9c349")!
    private static let privacyPolicyURL = URL(string: "https://flat-saguaro-662.notion.site/314a80cd73cf8050aa62d4b71935d326")!

    @ObservedObject var store: AppStore
    @State private var localErrorMessage: String?
    @State private var authDebugState = "idle"
    @State private var showPhoneLoginSheet = false

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
        .appSheet(isPresented: $showPhoneLoginSheet) {
            PhoneLoginSheet(store: store)
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

            VStack(spacing: AppSpacing.s) {
                signInButton
                    .animation(.easeInOut(duration: 0.2), value: isSigningIn)

                phoneSignInButton
                    .opacity(isSigningIn ? 0.56 : 1)
                    .disabled(isSigningIn)
            }

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

    private var phoneSignInButton: some View {
        AppButton("手机号登录", variant: .secondary) {
            showPhoneLoginSheet = true
        }
        .accessibilityIdentifier("auth_sign_in_with_phone_button")
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

private struct PhoneLoginSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: AppStore
    @State private var phone = ""
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isSendingCode = false
    @State private var isSigningIn = false
    @State private var resendCountdown = 0
    @State private var resendCountdownTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        AppDetailTopBar(title: "手机号登录", onBack: {
                            dismiss()
                        })

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("验证码登录")
                                .font(AppFont.section())
                                .foregroundStyle(AppColor.textPrimary)

                            Text("输入手机号后获取验证码，登录成功后继续进入当前账号流程。")
                                .font(AppFont.body())
                                .foregroundStyle(AppColor.textSecondary)
                                .lineSpacing(2)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.danger)
                                .multilineTextAlignment(.leading)
                                .accessibilityIdentifier("phone_login_error_message")
                        }

                        AppFormField(
                            title: "手机号",
                            helper: "请输入中国大陆手机号"
                        ) {
                            AppTextField(
                                placeholder: "例如 13800000000",
                                text: $phone,
                                keyboardType: .phonePad,
                                textContentType: .telephoneNumber,
                                submitLabel: .next
                            )
                            .accessibilityIdentifier("phone_login_phone_input")
                        }

                        AppFormField(
                            title: "验证码",
                            helper: resendHelperText
                        ) {
                            HStack(alignment: .top, spacing: AppSpacing.s) {
                                AppTextField(
                                    placeholder: "输入 6 位验证码",
                                    text: $code,
                                    keyboardType: .numberPad,
                                    textContentType: .oneTimeCode,
                                    submitLabel: .go,
                                    onSubmit: {
                                        Task { @MainActor in
                                            await signIn()
                                        }
                                    }
                                )
                                .accessibilityIdentifier("phone_login_code_input")
                                .frame(maxWidth: .infinity)

                                AppButton(sendCodeButtonTitle, variant: .compactSecondary) {
                                    Task { @MainActor in
                                        await sendCode()
                                    }
                                }
                                .accessibilityIdentifier("phone_login_send_code_button")
                                .disabled(!canSendCode)
                                .opacity(canSendCode ? 1 : 0.56)
                            }
                        }

                        AppButton(isSigningIn ? "登录中" : "登录", variant: .primary) {
                            Task { @MainActor in
                                await signIn()
                            }
                        }
                        .accessibilityIdentifier("phone_login_submit_button")
                        .disabled(!canSubmit || isSigningIn)
                        .opacity((canSubmit && !isSigningIn) ? 1 : 0.56)

#if DEBUG
                        Text("本地调试模式下验证码 123456 直接通过。")
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.textSecondary)
#endif
                    }
                    .padding(.horizontal, AppSpacing.inset)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnTap()
        .onDisappear {
            resendCountdownTask?.cancel()
            resendCountdownTask = nil
        }
    }

    private var canSendCode: Bool {
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSendingCode
            && resendCountdown == 0
            && !isSigningIn
    }

    private var canSubmit: Bool {
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSendingCode
    }

    private var sendCodeButtonTitle: String {
        if resendCountdown > 0 {
            return "重新发送 \(resendCountdown)s"
        }
        return "获取验证码"
    }

    private var resendHelperText: String {
        if resendCountdown > 0 {
            return "验证码已发送，\(resendCountdown)s 后可重新获取。"
        }
        return "验证码将发送到你的手机号。"
    }

    @MainActor
    private func sendCode() async {
        guard canSendCode else { return }
        isSendingCode = true
        errorMessage = nil
        defer { isSendingCode = false }

        do {
            try await store.sendPhoneCode(phone: phone)
            startResendCountdown()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func signIn() async {
        guard canSubmit, !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            try await store.signInWithPhone(phone: phone, code: code)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func startResendCountdown(seconds: Int = 60) {
        resendCountdownTask?.cancel()
        resendCountdown = seconds
        resendCountdownTask = Task { @MainActor in
            while !Task.isCancelled, resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, resendCountdown > 0 else { break }
                resendCountdown -= 1
            }
            if !Task.isCancelled {
                resendCountdownTask = nil
            }
        }
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
