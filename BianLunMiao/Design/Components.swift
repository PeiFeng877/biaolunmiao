//
//  Components.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/4.
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 统一的视觉令牌与布局规范。
//  OUTPUT: 可复用的视图组件与样式。
//  POS: 设计系统层，供页面组合使用。
//

import SwiftUI

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
        text: AppColor.iconOnPrimary,
        icon: AppColor.iconOnPrimary,
        background: AppColor.primaryStrong,
        stroke: AppColor.outline
    )

    static let tournament = AppTopBarStyle.brand
    static let team = AppTopBarStyle.brand
}

struct AppTopBar: View {
    let title: String
    let style: AppTopBarStyle
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: AppSpacing.m) {
                AppTopBarIcon(
                    systemName: "pawprint.fill",
                    foreground: style.icon,
                    background: style.background,
                    stroke: style.stroke
                )

                Spacer()

                AppTopBarButton(
                    systemName: "plus",
                    foreground: style.icon,
                    background: style.background,
                    stroke: style.stroke,
                    action: onAdd
                )
            }

            Text(title)
                .font(AppFont.section())
                .foregroundStyle(style.text)
        }
        .padding(.horizontal, AppSpacing.l)
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
                Circle().stroke(stroke, lineWidth: 1)
            )
    }
}

struct AppTopBarButton: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let stroke: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppFont.icon())
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
    let background: Background
    let content: Content

    init(
        style: AppCardStyle = .standard,
        padding: CGFloat = AppSpacing.l,
        alignment: Alignment = .leading,
        stroke: Color = AppColor.outline,
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.alignment = alignment
        self.stroke = stroke
        self.background = background()
        self.content = content()
    }

    init(
        style: AppCardStyle = .standard,
        padding: CGFloat = AppSpacing.l,
        alignment: Alignment = .leading,
        stroke: Color = AppColor.outline,
        @ViewBuilder content: () -> Content
    ) where Background == Color {
        self.init(
            style: style,
            padding: padding,
            alignment: alignment,
            stroke: stroke,
            background: { AppColor.surface },
            content: content
        )
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(background)
            .clipShape(.rect(cornerRadius: AppRadius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    private var shadowColor: Color {
        AppShadow.subtle
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .standard:
            return 8
        case .interactive:
            return 10
        case .emphasis:
            return 12
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .standard:
            return 4
        case .interactive:
            return 6
        case .emphasis:
            return 8
        }
    }
}

extension TeamAvatarStyle {
    var tintColor: Color {
        switch self {
        case .paw:
            return AppColor.primary
        case .shield:
            return AppColor.infoBlue
        case .crown:
            return AppColor.reward
        case .bolt:
            return AppColor.eventAccentStrong
        case .flame:
            return AppColor.danger
        case .leaf:
            return AppColor.primaryStrong
        }
    }

    var backgroundColor: Color {
        tintColor.opacity(0.14)
    }
}

struct TeamAvatarBadge: View {
    let style: TeamAvatarStyle
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(style.backgroundColor)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: style.systemName)
                    .font(AppFont.iconScaled(size * AppIconScale.avatar))
                    .foregroundStyle(style.tintColor)
            )
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
                        .overlay(
                            Circle().stroke(
                                selection == style ? AppColor.primary : Color.clear,
                                lineWidth: 2
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.m), count: columns)
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
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textMuted)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(.capsule)
    }
}

struct AppBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(AppColor.textOnDark)
            .background(color)
            .clipShape(.capsule)
    }
}

struct AppIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(AppFont.iconMedium())
            .foregroundStyle(color)
            .padding(8)
            .background(color.opacity(0.12))
            .clipShape(.circle)
    }
}

struct AppInputStyle {
    let text: Color
    let placeholder: Color
    let tint: Color
    let background: Color
    let stroke: Color

    static let standard = AppInputStyle(
        text: AppColor.textPrimary,
        placeholder: AppColor.textMuted,
        tint: AppColor.primary,
        background: AppColor.background,
        stroke: AppColor.outline
    )

    static let tournament = AppInputStyle(
        text: AppColor.eventText,
        placeholder: AppColor.eventMuted,
        tint: AppColor.eventAccent,
        background: AppColor.eventBackground,
        stroke: AppColor.eventStroke
    )
}

struct AppFormFieldCounter {
    let current: Int
    let limit: Int
}

struct AppFormField<Content: View>: View {
    let title: String
    let helper: String?
    let error: String?
    let counter: AppFormFieldCounter?
    let labelColor: Color
    let helperColor: Color
    let errorColor: Color
    let counterColor: Color
    let content: Content

    init(
        title: String,
        helper: String? = nil,
        error: String? = nil,
        counter: AppFormFieldCounter? = nil,
        labelColor: Color = AppColor.textSecondary,
        helperColor: Color = AppColor.textMuted,
        errorColor: Color = AppColor.danger,
        counterColor: Color = AppColor.textMuted,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helper = helper
        self.error = error
        self.counter = counter
        self.labelColor = labelColor
        self.helperColor = helperColor
        self.errorColor = errorColor
        self.counterColor = counterColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.caption())
                .foregroundStyle(labelColor)

            content

            if helper != nil || error != nil || counter != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let error {
                        Text(error)
                            .foregroundStyle(errorColor)
                    } else if let helper {
                        Text(helper)
                            .foregroundStyle(helperColor)
                    }

                    Spacer()

                    if let counter {
                        Text("\(counter.current)/\(counter.limit)")
                            .foregroundStyle(counterColor)
                    }
                }
                .font(AppFont.caption())
            }
        }
    }
}

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    let style: AppInputStyle

    init(
        placeholder: String,
        text: Binding<String>,
        style: AppInputStyle = .standard
    ) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
    }

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundStyle(style.placeholder)
        )
        .font(AppFont.body())
        .foregroundStyle(style.text)
        .tint(style.tint)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(style.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .stroke(style.stroke, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: AppRadius.s, style: .continuous))
    }
}

struct AppIconField: View {
    let systemName: String
    let placeholder: String
    @Binding var text: String
    let style: AppInputStyle

    init(
        systemName: String,
        placeholder: String,
        text: Binding<String>,
        style: AppInputStyle = .standard
    ) {
        self.systemName = systemName
        self.placeholder = placeholder
        self._text = text
        self.style = style
    }

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: systemName)
                .font(AppFont.icon())
                .foregroundStyle(style.placeholder)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(style.placeholder)
            )
            .font(AppFont.body())
            .foregroundStyle(style.text)
            .tint(style.tint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(style.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .stroke(style.stroke, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: AppRadius.s, style: .continuous))
    }
}

struct AppTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let style: AppInputStyle

    init(
        placeholder: String,
        text: Binding<String>,
        style: AppInputStyle = .standard
    ) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
    }

    var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .font(AppFont.body())
            .foregroundStyle(style.text)
            .tint(style.tint)
            .frame(minHeight: 90)
            .padding(8)
            .background(style.background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                    .stroke(style.stroke, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: AppRadius.s, style: .continuous))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppFont.body())
                        .foregroundStyle(style.placeholder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
            }
    }
}

struct AppSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let style: AppInputStyle

    init(
        text: Binding<String>,
        placeholder: String = "搜索辩论赛… (Search tournaments)",
        style: AppInputStyle = .standard
    ) {
        self._text = text
        self.placeholder = placeholder
        self.style = style
    }

    var body: some View {
        AppIconField(
            systemName: "magnifyingglass",
            placeholder: placeholder,
            text: $text,
            style: style
        )
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.section())
            .foregroundStyle(AppColor.textOnDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.primary)
            .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.section())
            .foregroundStyle(AppColor.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(AppColor.primary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppEmptyState: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            AppIconBadge(systemName: systemImage, color: AppColor.primary)
            Text(title)
                .font(AppFont.section())
                .foregroundStyle(AppColor.textPrimary)
            Text(subtitle)
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}
