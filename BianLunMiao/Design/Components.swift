//
//  Components.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/4.
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
                .foregroundColor(AppColor.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.caption())
                    .foregroundColor(AppColor.textMuted)
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
            .foregroundColor(color)
            .clipShape(Capsule())
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
            .foregroundColor(.white)
            .background(color)
            .clipShape(Capsule())
    }
}

struct AppIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(color)
            .padding(8)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }
}

struct AppTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .font(AppFont.body())
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColor.background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                    .stroke(AppColor.outline, lineWidth: 1)
            )
            .cornerRadius(AppRadius.s)
    }
}

struct AppTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(AppFont.body())
            .frame(minHeight: 90)
            .padding(8)
            .background(AppColor.background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                    .stroke(AppColor.outline, lineWidth: 1)
            )
            .cornerRadius(AppRadius.s)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(title)
                        .font(AppFont.body())
                        .foregroundColor(AppColor.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
            }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.section())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.section())
            .foregroundColor(AppColor.primary)
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
                .foregroundColor(AppColor.textPrimary)
            Text(subtitle)
                .font(AppFont.caption())
                .foregroundColor(AppColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}
