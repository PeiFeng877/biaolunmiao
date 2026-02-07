//
//  ComponentsActions.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/7.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 操作按钮与反馈状态语义。
//  OUTPUT: 主次按钮样式与空状态组件。
//  POS: 设计系统层-交互反馈组件。
//

import SwiftUI

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .tracking(AppFont.tracking)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.primary)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(AppColor.stroke, lineWidth: 1.5)
            )
            .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
            .shadow(
                color: AppShadow.standard.color,
                radius: AppShadow.standard.blur,
                x: configuration.isPressed ? 0 : AppShadow.standard.x,
                y: configuration.isPressed ? 0 : AppShadow.standard.y
            )
            .offset(x: configuration.isPressed ? 4 : 0, y: configuration.isPressed ? 4 : 0)
            .animation(AppMotion.spring, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.section())
            .tracking(AppFont.tracking)
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(AppColor.stroke, lineWidth: 1.5)
            )
            .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
            .shadow(
                color: AppShadow.standard.color,
                radius: AppShadow.standard.blur,
                x: configuration.isPressed ? 0 : AppShadow.standard.x,
                y: configuration.isPressed ? 0 : AppShadow.standard.y
            )
            .offset(x: configuration.isPressed ? 4 : 0, y: configuration.isPressed ? 4 : 0)
            .animation(AppMotion.spring, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

struct AppEmptyState: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .fill(AppColor.surface)
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                            .stroke(AppColor.stroke, lineWidth: 1.5)
                    )
                    .shadow(
                        color: AppShadow.standard.color,
                        radius: 0,
                        x: AppShadow.standard.x,
                        y: AppShadow.standard.y
                    )

                Circle()
                    .fill(AppColor.primary)
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
            }

            Text(title)
                .font(AppFont.title())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textPrimary)

            Text(subtitle)
                .font(AppFont.body())
                .tracking(AppFont.tracking)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}
