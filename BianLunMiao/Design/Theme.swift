//
//  Theme.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/4.
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: Duolingo 风格的全局设计令牌。
//  OUTPUT: 颜色、字体、间距、圆角、阴影常量。
//  POS: 设计系统层，供所有视图调用。
//

import SwiftUI

enum AppColor {
    // Duolingo identity color references:
    // Feather Green #58CC02, Mask Green #89E219, Eel #4B4B4B, Snow #FFFFFF
    static let background = Color(hex: 0xFFFFFF) // Snow
    static let surface = Color(hex: 0xF7F7F7)    // Polar
    static let outline = Color(hex: 0xE5E5E5)    // Swan

    static let textPrimary = Color(hex: 0x4B4B4B)   // Eel
    static let textSecondary = Color(hex: 0x777777) // Wolf
    static let textMuted = Color(hex: 0xAFAFAF)     // Hare

    static let primary = Color(hex: 0x58CC02)       // Feather Green
    static let primaryStrong = Color(hex: 0x89E219) // Mask Green
    static let infoBlue = Color(hex: 0x1CB0F6)      // Blue

    static let reward = Color(hex: 0xFFB100)        // Orange
    static let danger = Color(hex: 0xFF7878)        // Red

    // Clubhouse-inspired neutral palette for tournament feed
    static let clubhouseBackground = Color(hex: 0xF6F1E8)
    static let clubhouseCard = Color(hex: 0xFBF7F0)
    static let clubhouseStroke = Color(hex: 0xE8DFD0)
    static let clubhouseText = Color(hex: 0x2F2A24)
    static let clubhouseMuted = Color(hex: 0x8C857B)
    static let clubhouseIcon = Color(hex: 0x3A332C)
    static let clubhouseIconBackground = Color(hex: 0xEFE6D8)
    static let clubhouseAvatar1 = Color(hex: 0xF2C6A0)
    static let clubhouseAvatar2 = Color(hex: 0xCFE0C3)
    static let clubhouseAvatar3 = Color(hex: 0xBFD7EA)
    static let clubhouseAvatar4 = Color(hex: 0xE3C7E8)

    // Tournament layout palette
    static let eventBackground = Color(hex: 0xF6F6F0)
    static let eventCard = Color(hex: 0xFFFFFF)
    static let eventStroke = Color(hex: 0xE6E6DE)
    static let eventText = Color(hex: 0x1F1F1C)
    static let eventMuted = Color(hex: 0x8C8C82)
    static let eventAccent = Color(hex: 0x7EEA00)
    static let eventAccentStrong = Color(hex: 0x6AD800)
    static let eventAccentSoft = Color(hex: 0xCFF5A6)
    static let eventIcon = Color(hex: 0x171715)
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
