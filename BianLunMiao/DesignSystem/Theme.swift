//
//  Theme.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/4.
//  Updated by Codex on 2026/2/13.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 辩论喵全局设计令牌（Neo-Brutalism v2）。
//  OUTPUT: 颜色、字体、间距、圆角、阴影常量。
//  POS: 设计系统层，供所有视图调用。
//

import SwiftUI

enum AppColor {
    // MARK: - Core Neutrals (Global)
    static let background = dynamicColor(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let surface = dynamicColor(light: 0xFFFFFF, dark: 0x121212)
    static let stroke = dynamicColor(light: 0x000000, dark: 0x33FF00)
    static let noise = dynamicColor(light: 0xDAEBC4, dark: 0x0F1608)

    static let textPrimary = dynamicColor(light: 0x000000, dark: 0xFFFFFF)
    static let textSecondary = dynamicColor(light: 0x4D4D4D, dark: 0x999999)
    static let textMuted = textSecondary

    // MARK: - Brand
    static let primary = dynamicColor(light: 0xCCFF00, dark: 0xCCFF00)
    static let primaryStrong = dynamicColor(light: 0xA3CC00, dark: 0xA3CC00)
    static let primarySoft = dynamicColor(light: 0xE6FFAD, dark: 0x1A2600)
    static let iconPrimary = dynamicColor(light: 0x000000, dark: 0xCCFF00)
    static let iconOnPrimary = Color(hex: 0x000000)

    // MARK: - Semantic
    static let infoBlue = dynamicColor(light: 0x1CB0F6, dark: 0x1CB0F6)
    static let reward = dynamicColor(light: 0xFFDE00, dark: 0xFFDE00)
    static let danger = dynamicColor(light: 0xFF3B30, dark: 0xFF3B30)
    static let textOnDark = Color(hex: 0xFFFFFF)

    // MARK: - Avatar Palette
    static let avatar1 = Color(hex: 0xF2C6A0)
    static let avatar2 = Color(hex: 0xCFE0C3)
    static let avatar3 = Color(hex: 0xBFD7EA)
    static let avatar4 = Color(hex: 0xE3C7E8)

    // MARK: - Compatibility (Tournament / Legacy)
    static let outline = stroke
    static let eventBackground = background
    static let eventCard = surface
    static let eventStroke = stroke
    static let eventText = textPrimary
    static let eventMuted = textMuted
    static let eventAccent = primary
    static let eventAccentStrong = primaryStrong
    static let eventAccentSoft = primarySoft
    static let eventIcon = iconPrimary
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let inset: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppRadius {
    static let s: CGFloat = 12
    static let m: CGFloat = 24
    static let l: CGFloat = 32
}

struct AppShadowSpec {
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
}

enum AppShadow {
    static let standard = AppShadowSpec(color: .black.opacity(0.72), x: 2, y: 2, blur: 0)
    static let accent = AppShadowSpec(color: AppColor.primary, x: 4, y: 4, blur: 0)

    // Compatibility
    static let subtle: Color = standard.color
}

enum AppFont {
    static let tracking: CGFloat = -0.2

    static func hero() -> Font { .system(size: 32, weight: .heavy, design: .rounded) }
    static func title() -> Font { .system(size: 24, weight: .black, design: .rounded) }
    static func section() -> Font { .system(size: 18, weight: .bold, design: .rounded) }
    static func body() -> Font { .system(size: 16, weight: .medium, design: .rounded) }
    static func caption() -> Font { .system(size: 12, weight: .bold, design: .monospaced) }
    static func icon() -> Font { .system(size: 16, weight: .bold, design: .rounded) }
    static func iconMedium() -> Font { .system(size: 14, weight: .bold, design: .rounded) }
    static func iconSmall() -> Font { .system(size: 12, weight: .bold, design: .rounded) }
    static func iconScaled(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

enum AppMotion {
    static let spring = Animation.interpolatingSpring(mass: 1, stiffness: 220, damping: 14)
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
