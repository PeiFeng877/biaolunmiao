//
//  ComponentsButtonAPI.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 业务层按钮语义（文案、图标、行为）。
//  OUTPUT: 统一按钮入口，禁止业务层直接定义裸 Button。
//  POS: 设计系统层-按钮 API。
//

import SwiftUI

enum AppButtonVariant: String, CaseIterable {
    case primary
    case secondary
    case compactSecondary
    case ghost
    case toolbarText
    case topBarIcon
}

struct AppButton: View {
    let title: String
    let variant: AppButtonVariant
    let role: ButtonRole?
    let action: () -> Void

    init(
        _ title: String,
        variant: AppButtonVariant = .primary,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.role = role
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        switch variant {
        case .primary:
            Button(title, role: role, action: action)
                .buttonStyle(AppPrimaryButtonStyle())
        case .secondary:
            Button(title, role: role, action: action)
                .buttonStyle(AppSecondaryButtonStyle())
        case .compactSecondary:
            Button(title, role: role, action: action)
                .buttonStyle(AppCompactSecondaryButtonStyle())
        case .ghost:
            Button(title, role: role, action: action)
                .buttonStyle(AppGhostButtonStyle())
        case .toolbarText:
            Button(title, role: role, action: action)
                .buttonStyle(AppToolbarTextButtonStyle())
        case .topBarIcon:
            Button(title, role: role, action: action)
                .buttonStyle(AppToolbarTextButtonStyle())
        }
    }
}

struct AppIconButton: View {
    let systemName: String
    let accessibilityTitle: String
    let foreground: Color
    let background: Color
    let stroke: Color
    let action: () -> Void

    init(
        systemName: String,
        accessibilityTitle: String,
        foreground: Color = AppColor.textPrimary,
        background: Color = AppColor.primarySoft,
        stroke: Color = AppColor.stroke,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityTitle = accessibilityTitle
        self.foreground = foreground
        self.background = background
        self.stroke = stroke
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppFont.icon())
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(background)
                .clipShape(Circle())
                .overlay(Circle().stroke(stroke, lineWidth: 1.5))
        }
        .buttonStyle(AppHapticPressStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}

struct AppRowTapButtonStyle: ButtonStyle {
    private let pressOffsetX: CGFloat = 2
    private let pressOffsetY: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(
                x: configuration.isPressed ? pressOffsetX : 0,
                y: configuration.isPressed ? pressOffsetY : 0
            )
            .animation(AppMotion.spring, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

struct AppRowTapButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    init(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(AppRowTapButtonStyle())
    }
}

struct AppMenuAction: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        if let systemImage {
            Button(role: role, action: action) {
                Label(title, systemImage: systemImage)
            }
        } else {
            Button(title, role: role, action: action)
        }
    }
}
