//
//  ContentView.swift
//  BianLunMiao
//
//  Created by Icarus on 2026/2/3.
//  Updated by Codex on 2026/2/4.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 设计系统与示例内容。
//  OUTPUT: 设计预览页面。
//  POS: 仅用于预览与调试。
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: AppSpacing.l) {
                Text("辩论喵")
                    .font(AppFont.title())
                    .foregroundStyle(AppColor.textPrimary)

                AppCard {
                    HStack(spacing: AppSpacing.m) {
                        AppIconBadge(systemName: "sparkles", color: AppColor.reward)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("完成排兵布阵")
                                .font(AppFont.section())
                                .foregroundStyle(AppColor.textPrimary)
                            Text("胜利向你招手")
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.textMuted)
                        }
                        Spacer()
                        AppBadge(text: "+5", color: AppColor.reward)
                    }
                }
            }
            .padding(AppSpacing.xl)
        }
    }
}

#Preview {
    ContentView()
}
