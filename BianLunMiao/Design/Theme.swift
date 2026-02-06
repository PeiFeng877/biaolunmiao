//
//  Theme.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/4.
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 辩论喵全局设计令牌（统一主题色与语义色）。
//  OUTPUT: 颜色、字体、间距、圆角、阴影常量。
//  POS: 设计系统层，供所有视图调用。
//

import SwiftUI

enum AppColor {
    // MARK: - Core Neutrals (Global)
    static let background = dynamicColor(light: 0xF6F6F0, dark: 0x14130F)
    static let surface = dynamicColor(light: 0xFFFFFF, dark: 0x1C1B16)
    static let outline = dynamicColor(light: 0xE6E6DE, dark: 0x2C2B24)

    static let textPrimary = dynamicColor(light: 0x1F1F1C, dark: 0xF4F3EC)
    static let textSecondary = dynamicColor(light: 0x5C5C54, dark: 0xC2C0B6)
    static let textMuted = dynamicColor(light: 0x8C8C82, dark: 0x9A978E)

    // MARK: - Brand
    static let primary = dynamicColor(light: 0x7EEA00, dark: 0x7EEA00)
    static let primaryStrong = dynamicColor(light: 0x6AD800, dark: 0x6AD800)
    static let primarySoft = dynamicColor(light: 0xCFF5A6, dark: 0x2E3D16)
    static let iconPrimary = dynamicColor(light: 0x171715, dark: 0xF4F3EC)
    static let iconOnPrimary = Color(hex: 0x171715)

    // MARK: - Semantic
    static let infoBlue = dynamicColor(light: 0x1CB0F6, dark: 0x1CB0F6)
    static let reward = dynamicColor(light: 0xFFB100, dark: 0xFFB100)
    static let danger = dynamicColor(light: 0xFF7878, dark: 0xFF7878)
    static let textOnDark = Color(hex: 0xFFFFFF)

    // MARK: - Avatar Palette
    static let avatar1 = Color(hex: 0xF2C6A0)
    static let avatar2 = Color(hex: 0xCFE0C3)
    static let avatar3 = Color(hex: 0xBFD7EA)
    static let avatar4 = Color(hex: 0xE3C7E8)

    // MARK: - Compatibility (Tournament / Legacy)
    static let eventBackground = background
    static let eventCard = surface
    static let eventStroke = outline
    static let eventText = textPrimary
    static let eventMuted = textMuted
    static let eventAccent = primary
    static let eventAccentStrong = primaryStrong
    static let eventAccentSoft = primarySoft
    static let eventIcon = iconPrimary
}

enum AppGradient {
    // 只用于“奖励/成就”，面积 < 15%
    static let reward = LinearGradient(
        colors: [AppColor.reward, AppColor.reward.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppRadius {
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 16
}

enum AppShadow {
    static let subtle = Color.black.opacity(0.06)
}

enum AppFont {
    // TODO: 引入 Nunito 字体资源后替换为 .custom("Nunito", size: ...)
    static func hero() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func title() -> Font { .system(size: 24, weight: .bold, design: .rounded) }
    static func section() -> Font { .system(size: 18, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 15, weight: .regular, design: .rounded) }
    static func caption() -> Font { .system(size: 12, weight: .regular, design: .rounded) }
    static func icon() -> Font { .system(size: 16, weight: .semibold, design: .rounded) }
    static func iconMedium() -> Font { .system(size: 14, weight: .semibold, design: .rounded) }
    static func iconSmall() -> Font { .system(size: 12, weight: .semibold, design: .rounded) }
    static func iconScaled(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

enum AppIconScale {
    static let avatar: CGFloat = 0.45
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private extension AppColor {
    static func dynamicColor(light: UInt, dark: UInt, alpha: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex, alpha: alpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: CGFloat(alpha)
        )
    }
}
