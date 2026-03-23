//
//  ComponentsForm.swift
//  BianLunMiao
//
//  Created by Codex on 2026/2/7.
//  Updated by Codex on 2026/3/23.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 表单语义与输入组件规范。
//  OUTPUT: FormField/TextField/IconField/TextEditor/SearchBar 等组件。
//  POS: 设计系统层-表单组件。
//

import SwiftUI
import UIKit

struct AppInputStyle {
    let text: Color
    let placeholder: Color
    let tint: Color
    let background: Color
    let stroke: Color

    static let standard = AppInputStyle(
        text: AppColor.textPrimary,
        placeholder: AppColor.textSecondary,
        tint: AppColor.primaryStrong,
        background: AppColor.surface,
        stroke: AppColor.stroke
    )

    static let tournament = AppInputStyle(
        text: AppColor.eventText,
        placeholder: AppColor.eventMuted,
        tint: AppColor.eventAccentStrong,
        background: AppColor.eventCard,
        stroke: AppColor.eventStroke
    )
}

struct AppFormFieldCounter {
    let current: Int
    let limit: Int
}

struct AppFormField<Content: View>: View {
    let title: String
    let isRequired: Bool
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
        isRequired: Bool = false,
        helper: String? = nil,
        error: String? = nil,
        counter: AppFormFieldCounter? = nil,
        labelColor: Color = AppColor.textSecondary,
        helperColor: Color = AppColor.textSecondary,
        errorColor: Color = AppColor.danger,
        counterColor: Color = AppColor.textSecondary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isRequired = isRequired
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
            fieldLabel

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
                .tracking(AppFont.tracking)
            }
        }
    }

    private var fieldLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(title)
                .font(AppFont.caption())
                .tracking(AppFont.tracking)
                .foregroundStyle(labelColor)

            if isRequired {
                Text("*")
                    .font(AppFont.caption())
                    .tracking(AppFont.tracking)
                    .foregroundStyle(AppColor.danger)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRequired ? "\(title)，必填" : title)
    }
}

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    let style: AppInputStyle
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let submitLabel: SubmitLabel
    let textInputAutocapitalization: TextInputAutocapitalization
    let autocorrectionDisabled: Bool
    let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        style: AppInputStyle = .standard,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .return,
        textInputAutocapitalization: TextInputAutocapitalization = .never,
        autocorrectionDisabled: Bool = true,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.submitLabel = submitLabel
        self.textInputAutocapitalization = textInputAutocapitalization
        self.autocorrectionDisabled = autocorrectionDisabled
        self.onSubmit = onSubmit
    }

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(AppFont.body())
                .tracking(AppFont.tracking)
                .foregroundStyle(style.placeholder)
        )
        .font(AppFont.body())
        .tracking(AppFont.tracking)
        .foregroundStyle(style.text)
        .tint(style.tint)
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .textInputAutocapitalization(textInputAutocapitalization)
        .autocorrectionDisabled(autocorrectionDisabled)
        .submitLabel(submitLabel)
        .onSubmit {
            onSubmit?()
        }
        .focused($isFocused)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(isFocused ? AppColor.primarySoft : style.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                .stroke(style.stroke, lineWidth: 2)
        )
        .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
        .shadow(
            color: isFocused ? AppShadow.accent.color : AppShadow.standard.color,
            radius: 0,
            x: isFocused ? AppShadow.accent.x : AppShadow.standard.x,
            y: isFocused ? AppShadow.accent.y : AppShadow.standard.y
        )
    }
}

struct AppIconField: View {
    let systemName: String
    let placeholder: String
    @Binding var text: String
    let style: AppInputStyle

    @FocusState private var isFocused: Bool

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
                prompt: Text(placeholder)
                    .font(AppFont.body())
                    .tracking(AppFont.tracking)
                    .foregroundStyle(style.placeholder)
            )
            .font(AppFont.body())
            .tracking(AppFont.tracking)
            .foregroundStyle(style.text)
            .tint(style.tint)
            .focused($isFocused)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(isFocused ? AppColor.primarySoft : style.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                .stroke(style.stroke, lineWidth: 2)
        )
        .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
        .shadow(
            color: isFocused ? AppShadow.accent.color : AppShadow.standard.color,
            radius: 0,
            x: isFocused ? AppShadow.accent.x : AppShadow.standard.x,
            y: isFocused ? AppShadow.accent.y : AppShadow.standard.y
        )
    }
}

struct AppTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let style: AppInputStyle

    @FocusState private var isFocused: Bool

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
            .focused($isFocused)
            .frame(minHeight: 90)
            .padding(10)
            .background(isFocused ? AppColor.primarySoft : style.background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(style.stroke, lineWidth: 2)
            )
            .clipShape(.rect(cornerRadius: AppRadius.m, style: .continuous))
            .shadow(
                color: isFocused ? AppShadow.accent.color : AppShadow.standard.color,
                radius: 0,
                x: isFocused ? AppShadow.accent.x : AppShadow.standard.x,
                y: isFocused ? AppShadow.accent.y : AppShadow.standard.y
            )
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppFont.body())
                        .tracking(AppFont.tracking)
                        .foregroundStyle(style.placeholder)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
            }
    }
}

struct AppSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let style: AppInputStyle
    let accessibilityId: String?

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "搜索赛事",
        style: AppInputStyle = .standard,
        accessibilityId: String? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.style = style
        self.accessibilityId = accessibilityId
    }

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(AppFont.icon())
                .fontWeight(.bold)
                .foregroundStyle(style.placeholder)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .font(AppFont.body())
                    .tracking(AppFont.tracking)
                    .foregroundStyle(style.placeholder)
            )
            .font(AppFont.body())
            .tracking(AppFont.tracking)
            .foregroundStyle(style.text)
            .tint(style.tint)
            .focused($isFocused)
            .accessibilityIdentifier(accessibilityId ?? "")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isFocused ? AppColor.primarySoft : style.background)
        .overlay(
            Capsule(style: .continuous)
                .stroke(style.stroke, lineWidth: 2)
        )
        .clipShape(Capsule(style: .continuous))
        .shadow(
            color: isFocused ? AppShadow.accent.color : AppShadow.standard.color,
            radius: 0,
            x: isFocused ? AppShadow.accent.x : AppShadow.standard.x,
            y: isFocused ? AppShadow.accent.y : AppShadow.standard.y
        )
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        })
    }
}
