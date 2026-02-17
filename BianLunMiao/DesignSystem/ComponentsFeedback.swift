//
//  ComponentsFeedback.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 业务层反馈语义（成功、失败、确认、输入流程）。
//  OUTPUT: Toast / Alert / ConfirmationDialog / Sheet 统一入口。
//  POS: 设计系统层-反馈 API。
//

import SwiftUI

enum AppFeedbackIntent: String, CaseIterable {
    case success
    case info
    case warning
    case error
}

struct AppToastPayload: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String?
    let intent: AppFeedbackIntent
    let duration: TimeInterval

    init(
        title: String,
        message: String? = nil,
        intent: AppFeedbackIntent = .info,
        duration: TimeInterval = 2.0
    ) {
        self.title = title
        self.message = message
        self.intent = intent
        self.duration = duration
    }
}

private struct AppToastModifier: ViewModifier {
    @Binding var item: AppToastPayload?

    @State private var presented: AppToastPayload?
    @State private var queue: [AppToastPayload] = []
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let presented {
                    AppToastView(payload: presented)
                        .padding(.horizontal, AppSpacing.inset)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .onAppear {
                enqueueIncomingItem()
            }
            .onChange(of: item?.id) { _, _ in
                enqueueIncomingItem()
            }
            .onDisappear {
                dismissTask?.cancel()
                dismissTask = nil
            }
    }

    private func enqueueIncomingItem() {
        guard let incoming = item else { return }

        if presented == nil {
            present(incoming)
        } else {
            queue.append(incoming)
        }

        item = nil
    }

    private func present(_ payload: AppToastPayload) {
        withAnimation(AppMotion.spring) {
            presented = payload
        }

        dismissTask?.cancel()
        dismissTask = Task {
            let nanoseconds = UInt64(payload.duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                dismissCurrentAndContinue()
            }
        }
    }

    private func dismissCurrentAndContinue() {
        withAnimation(AppMotion.spring) {
            presented = nil
        }

        dismissTask?.cancel()
        dismissTask = nil

        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            present(next)
        }
    }
}

private struct AppToastView: View {
    let payload: AppToastPayload

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            Image(systemName: iconName)
                .font(AppFont.icon())
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(iconBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(payload.title)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)

                if let message = payload.message, !message.isEmpty {
                    Text(message)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
        .shadow(
            color: AppShadow.standard.color,
            radius: AppShadow.standard.blur,
            x: AppShadow.standard.x,
            y: AppShadow.standard.y
        )
    }

    private var iconName: String {
        switch payload.intent {
        case .success:
            return "checkmark"
        case .info:
            return "info"
        case .warning:
            return "exclamationmark"
        case .error:
            return "xmark"
        }
    }

    private var iconBackground: Color {
        switch payload.intent {
        case .success:
            return AppColor.primary
        case .info:
            return AppColor.infoBlue
        case .warning:
            return AppColor.reward
        case .error:
            return AppColor.danger
        }
    }

    private var borderColor: Color {
        switch payload.intent {
        case .success:
            return AppColor.primaryStrong
        case .info:
            return AppColor.infoBlue
        case .warning:
            return AppColor.reward
        case .error:
            return AppColor.danger
        }
    }
}

extension View {
    func appToast(item: Binding<AppToastPayload?>) -> some View {
        modifier(AppToastModifier(item: item))
    }

    func appAlert<A: View, M: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        alert(title, isPresented: isPresented, actions: actions, message: message)
    }

    func appConfirmationDialog<A: View, M: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, actions: actions, message: message)
    }

    func appConfirmationDialog<Item: Identifiable, A: View, M: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        presenting data: Item?,
        @ViewBuilder actions: (Item) -> A,
        @ViewBuilder message: (Item) -> M
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: isPresented,
            presenting: data,
            actions: actions,
            message: message
        )
    }

    func appSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, content: content)
    }

    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, content: content)
    }
}
