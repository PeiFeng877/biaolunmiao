//
//  ComponentsCore.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/7.
//  Updated by Codex on 2026/2/16.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 设计系统核心容器与展示组件。
//  OUTPUT: 背景、导航、卡片、头像、标签等复用组件。
//  POS: 设计系统层-核心组件。
//

import SwiftUI
import UIKit

struct AppBackground: View {
    var body: some View {
        AppColor.background
            .ignoresSafeArea()
    }
}

struct AppTopBarStyle {
    let text: Color
    let icon: Color
    let background: Color
    let stroke: Color

    static let brand = AppTopBarStyle(
        text: AppColor.textPrimary,
        icon: AppColor.primary,
        background: AppColor.surface,
        stroke: AppColor.stroke
    )

    static let tournament = AppTopBarStyle.brand
    static let team = AppTopBarStyle.brand
    static let schedule = AppTopBarStyle.brand
}

struct AppTopBar: View {
    let title: String
    let style: AppTopBarStyle
    let showsLeadingIcon: Bool
    let secondaryActionSystemName: String?
    let secondaryActionAccessibilityTitle: String?
    let secondaryActionAccessibilityId: String?
    let onSecondaryAction: (() -> Void)?
    let showsAddAction: Bool
    let addActionSystemName: String
    let addAccessibilityTitle: String
    let addAccessibilityId: String?
    let onAdd: () -> Void

    init(
        title: String,
        style: AppTopBarStyle,
        showsLeadingIcon: Bool,
        secondaryActionSystemName: String? = nil,
        secondaryActionAccessibilityTitle: String? = nil,
        secondaryActionAccessibilityId: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        showsAddAction: Bool = true,
        addActionSystemName: String = "plus",
        addAccessibilityTitle: String = "新增",
        addAccessibilityId: String? = nil,
        onAdd: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.showsLeadingIcon = showsLeadingIcon
        self.secondaryActionSystemName = secondaryActionSystemName
        self.secondaryActionAccessibilityTitle = secondaryActionAccessibilityTitle
        self.secondaryActionAccessibilityId = secondaryActionAccessibilityId
        self.onSecondaryAction = onSecondaryAction
        self.showsAddAction = showsAddAction
        self.addActionSystemName = addActionSystemName
        self.addAccessibilityTitle = addAccessibilityTitle
        self.addAccessibilityId = addAccessibilityId
        self.onAdd = onAdd
    }

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            if showsLeadingIcon {
                AppTopBarIcon(
                    systemName: "pawprint.fill",
                    foreground: style.icon,
                    background: .black,
                    stroke: style.stroke
                )
            }

            Text(title)
                .font(AppFont.section())
                .tracking(AppFont.tracking)
                .foregroundStyle(style.text)
                .lineLimit(1)

            Spacer()

            if let secondaryActionSystemName, let onSecondaryAction {
                AppTopBarButton(
                    systemName: secondaryActionSystemName,
                    foreground: style.text,
                    background: AppColor.primarySoft,
                    stroke: style.stroke,
                    accessibilityTitle: secondaryActionAccessibilityTitle,
                    accessibilityId: secondaryActionAccessibilityId,
                    action: onSecondaryAction
                )
            }

            if showsAddAction {
                AppTopBarButton(
                    systemName: addActionSystemName,
                    foreground: style.text,
                    background: AppColor.primarySoft,
                    stroke: style.stroke,
                    accessibilityTitle: addAccessibilityTitle,
                    accessibilityId: addAccessibilityId,
                    action: onAdd
                )
            }
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.vertical, AppSpacing.s)
    }
}

struct AppDetailTopBar: View {
    let title: String
    let onBack: () -> Void
    let backAccessibilityId: String?
    let trailingSystemName: String?
    let trailingAccessibilityId: String?
    let onTrailingAction: (() -> Void)?

    init(
        title: String,
        onBack: @escaping () -> Void,
        backAccessibilityId: String? = nil,
        trailingSystemName: String? = nil,
        trailingAccessibilityId: String? = nil,
        onTrailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.onBack = onBack
        self.backAccessibilityId = backAccessibilityId
        self.trailingSystemName = trailingSystemName
        self.trailingAccessibilityId = trailingAccessibilityId
        self.onTrailingAction = onTrailingAction
    }

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            AppTopBarButton(
                systemName: "arrow.left",
                foreground: AppColor.textPrimary,
                background: AppColor.primarySoft,
                stroke: AppColor.stroke,
                accessibilityId: backAccessibilityId,
                action: onBack
            )

            Spacer(minLength: AppSpacing.s)

            Text(title)
                .font(AppFont.section())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.s)

            if let trailingSystemName, let onTrailingAction {
                AppTopBarButton(
                    systemName: trailingSystemName,
                    foreground: AppColor.textPrimary,
                    background: AppColor.primarySoft,
                    stroke: AppColor.stroke,
                    accessibilityId: trailingAccessibilityId,
                    action: onTrailingAction
                )
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, AppSpacing.inset)
        .padding(.vertical, AppSpacing.s)
    }
}

struct AppTopBarIcon: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let stroke: Color

    var body: some View {
        Image(systemName: systemName)
            .font(AppFont.icon())
            .foregroundStyle(foreground)
            .frame(width: 40, height: 40)
            .background(background)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(stroke, lineWidth: 1.5)
            )
    }
}

struct AppTopBarButton: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let stroke: Color
    let accessibilityTitle: String?
    let accessibilityId: String?
    let action: () -> Void

    init(
        systemName: String,
        foreground: Color,
        background: Color,
        stroke: Color,
        accessibilityTitle: String? = nil,
        accessibilityId: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.foreground = foreground
        self.background = background
        self.stroke = stroke
        self.accessibilityTitle = accessibilityTitle
        self.accessibilityId = accessibilityId
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        if let accessibilityId {
            button
                .accessibilityIdentifier(accessibilityId)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppFont.icon())
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(stroke, lineWidth: 1.5)
                )
        }
        .buttonStyle(AppHapticPressStyle())
        .accessibilityLabel(accessibilityTitle ?? systemName)
    }
}

struct AppHapticPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? 4 : 0, y: configuration.isPressed ? 4 : 0)
            .animation(AppMotion.spring, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

enum AppCardStyle {
    case standard
    case interactive
    case emphasis
}

struct AppCard<Content: View, Background: View>: View {
    let style: AppCardStyle
    let padding: CGFloat
    let alignment: Alignment
    let stroke: Color
    let isBreathing: Bool
    let background: Background
    let content: Content

    @State private var isPressed = false
    @State private var pulse = false
    @State private var hapticTick = 0
    private let projectionX: CGFloat = 2
    private let projectionY: CGFloat = 5

    init(
        style: AppCardStyle = .standard,
        padding: CGFloat = AppSpacing.l,
        alignment: Alignment = .leading,
        stroke: Color = AppColor.stroke,
        isBreathing: Bool = false,
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.alignment = alignment
        self.stroke = stroke
        self.isBreathing = isBreathing
        self.background = background()
        self.content = content()
    }

    init(
        style: AppCardStyle = .standard,
        padding: CGFloat = AppSpacing.l,
        alignment: Alignment = .leading,
        stroke: Color = AppColor.stroke,
        isBreathing: Bool = false,
        @ViewBuilder content: () -> Content
    ) where Background == Color {
        self.init(
            style: style,
            padding: padding,
            alignment: alignment,
            stroke: stroke,
            isBreathing: isBreathing,
            background: { AppColor.surface },
            content: content
        )
    }

    @ViewBuilder
    var body: some View {
        if style == .interactive {
            baseCard
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTick)
                .simultaneousGesture(pressGesture)
        } else {
            baseCard
        }
    }

    private var baseCard: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(background)
            .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
            .background(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .fill(projectionColor)
                    .offset(x: projectionOffsetX, y: projectionOffsetY)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(effectiveStroke, lineWidth: 1.5)
            )
            .offset(x: cardOffsetX, y: cardOffsetY)
            .padding(.trailing, projectionX)
            .padding(.bottom, projectionY)
            .animation(AppMotion.spring, value: isPressed)
            .onAppear {
                guard isBreathing else { return }
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }

    private var cardOffsetX: CGFloat {
        style == .interactive && isPressed ? projectionX : 0
    }

    private var cardOffsetY: CGFloat {
        style == .interactive && isPressed ? projectionY : 0
    }

    private var projectionOffsetX: CGFloat {
        style == .interactive && isPressed ? 0 : projectionX
    }

    private var projectionOffsetY: CGFloat {
        style == .interactive && isPressed ? 0 : projectionY
    }

    private var effectiveStroke: Color {
        if style == .emphasis {
            return AppColor.primary
        }
        if isBreathing {
            return pulse ? AppColor.primary : stroke
        }
        return stroke
    }

    private var projectionColor: Color {
        if style == .emphasis {
            return AppColor.primary
        }
        return AppColor.stroke
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard style == .interactive else { return }
                if !isPressed {
                    isPressed = true
                    hapticTick += 1
                }
            }
            .onEnded { _ in
                guard style == .interactive else { return }
                isPressed = false
            }
    }
}

extension TeamAvatarStyle {
    var tintColor: Color {
        switch self {
        case .paw:
            return .black
        case .shield:
            return .black
        case .crown:
            return .black
        case .bolt:
            return .black
        case .flame:
            return .black
        case .leaf:
            return .black
        }
    }

    var backgroundColor: Color {
        switch self {
        case .paw:
            return AppColor.primarySoft
        case .shield:
            return AppColor.avatar1
        case .crown:
            return AppColor.avatar2
        case .bolt:
            return AppColor.avatar3
        case .flame:
            return AppColor.reward
        case .leaf:
            return AppColor.avatar4
        }
    }
}

struct TeamAvatarBadge: View {
    let style: TeamAvatarStyle
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.stroke, lineWidth: 1.5)
                .frame(width: size, height: size)

            Circle()
                .fill(style.backgroundColor)
                .frame(width: size - 6, height: size - 6)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )

            Image(systemName: style.systemName)
                .font(AppFont.iconScaled((size - 10) * AppIconScale.avatar))
                .foregroundStyle(style.tintColor)
        }
    }
}

struct TeamAvatarView: View {
    let team: Team
    let size: CGFloat

    var body: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .overlay(
                    Circle().stroke(AppColor.stroke, lineWidth: 1.5)
                )
        } else {
            TeamAvatarBadge(style: team.avatarStyle, size: size)
        }
    }

    private var avatarImage: UIImage? {
        guard let avatarUrl = team.avatarUrl, !avatarUrl.isEmpty else { return nil }
        return UIImage(contentsOfFile: avatarUrl)
    }
}

struct AppAvatarPicker: View {
    let styles: [TeamAvatarStyle]
    @Binding var selection: TeamAvatarStyle?
    let columns: Int
    let size: CGFloat

    init(
        styles: [TeamAvatarStyle] = TeamAvatarStyle.allCases,
        selection: Binding<TeamAvatarStyle?>,
        columns: Int = 3,
        size: CGFloat = 60
    ) {
        self.styles = styles
        self._selection = selection
        self.columns = columns
        self.size = size
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: AppSpacing.m) {
            ForEach(styles) { style in
                Button {
                    selection = style
                } label: {
                    TeamAvatarBadge(style: style, size: size)
                        .overlay {
                            Circle()
                                .stroke(
                                    selection == style ? AppColor.primary : Color.clear,
                                    lineWidth: 2
                                )
                                .frame(width: size + 6, height: size + 6)
                        }
                }
                .buttonStyle(AppHapticPressStyle())
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.m), count: columns)
    }
}

struct AppAvatarStack: View {
    let styles: [TeamAvatarStyle]
    let size: CGFloat
    let overlap: CGFloat

    init(styles: [TeamAvatarStyle], size: CGFloat = 36, overlap: CGFloat = -10) {
        self.styles = styles
        self.size = size
        self.overlap = overlap
    }

    var body: some View {
        HStack(spacing: overlap) {
            ForEach(Array(styles.enumerated()), id: \.offset) { index, style in
                TeamAvatarBadge(style: style, size: size)
                    .zIndex(Double(index))
            }
        }
    }
}

struct AppSectionHeader: View {
    let title: String
    let trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.section())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.caption())
                    .tracking(AppFont.tracking)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

struct AppTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .tracking(AppFont.tracking)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColor.surface)
            .foregroundStyle(color)
            .overlay(
                Capsule().stroke(color, lineWidth: 1.5)
            )
            .clipShape(.capsule)
    }
}

struct AppBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .tracking(AppFont.tracking)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.black)
            .background(color)
            .overlay(
                Capsule().stroke(AppColor.stroke, lineWidth: 1.5)
            )
            .clipShape(.capsule)
    }
}

struct AppIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(AppFont.iconMedium())
            .foregroundStyle(.black)
            .padding(8)
            .background(color)
            .overlay(
                Circle().stroke(AppColor.stroke, lineWidth: 1.5)
            )
            .clipShape(.circle)
    }
}
