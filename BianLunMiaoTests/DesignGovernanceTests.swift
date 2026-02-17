//
//  DesignGovernanceTests.swift
//  BianLunMiaoTests
//
//  Created by Codex on 2026/2/8.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 视图层源码与治理清单。
//  OUTPUT: 设计一致性规则与生成一致性断言。
//  POS: 设计治理自动化测试。
//

import Foundation
import Testing

struct DesignGovernanceTests {
    @Test
    func repositoryHasNoForbiddenPatterns() throws {
        let root = repositoryRoot()
        let result = try audit(root: root)

        #expect(result.violations.isEmpty)
        if !result.violations.isEmpty {
            let text = result.violations
                .map { "\($0.file):\($0.line) [\($0.rule)] \($0.snippet)" }
                .joined(separator: "\n")
            Issue.record("governance violations found:\n\(text)")
        }
    }

    @Test
    func generateThenCheckIsStableOnFixture() throws {
        let fixtureRoot = try makeFixtureRoot(withRawButton: false)
        let result = try audit(root: fixtureRoot)

        try write(result.buttonInventoryContent, to: fixtureRoot.appendingPathComponent("docs/03_Governance/按钮使用清单.md"))
        try write(result.feedbackInventoryContent, to: fixtureRoot.appendingPathComponent("docs/03_Governance/反馈使用清单.md"))

        let mismatches = try checkInventory(root: fixtureRoot)
        #expect(mismatches.isEmpty)
        if !mismatches.isEmpty {
            Issue.record("inventory mismatch: \(mismatches.joined(separator: "; "))")
        }
    }

    @Test
    func detectsRawButtonViolationOnFixture() throws {
        let fixtureRoot = try makeFixtureRoot(withRawButton: true)
        let result = try audit(root: fixtureRoot)

        #expect(result.violations.contains(where: { $0.rule == "no-raw-button" }))
    }
}

private struct AuditResult {
    let buttonRecords: [ButtonUsageRecord]
    let feedbackRecords: [FeedbackUsageRecord]
    let violations: [ViolationRecord]
    let buttonInventoryContent: String
    let feedbackInventoryContent: String
}

private struct ButtonUsageRecord {
    let page: String
    let file: String
    let line: Int
    let name: String
    let component: String
}

private struct FeedbackUsageRecord {
    let page: String
    let file: String
    let line: Int
    let scenario: String
    let component: String
}

private struct ViolationRecord {
    let file: String
    let line: Int
    let rule: String
    let snippet: String
}

private extension DesignGovernanceTests {
    func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func audit(root: URL) throws -> AuditResult {
        let viewsRoot = root.appendingPathComponent("BianLunMiao/Views", isDirectory: true)
        let files = try listSwiftFiles(in: viewsRoot)
        let allowedVariants: Set<String> = [
            "primary",
            "secondary",
            "compactSecondary",
            "ghost",
            "toolbarText",
            "topBarIcon"
        ]

        var buttonRecords: [ButtonUsageRecord] = []
        var feedbackRecords: [FeedbackUsageRecord] = []
        var violations: [ViolationRecord] = []

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let relative = relativePath(of: file, root: root)
            let page = file.deletingPathExtension().lastPathComponent

            for (offset, line) in lines.enumerated() {
                let lineNumber = offset + 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if matches(trimmed, pattern: #"\bButton\s*\("#) {
                    violations.append(.init(file: relative, line: lineNumber, rule: "no-raw-button", snippet: trimmed))
                }
                if trimmed.contains(".buttonStyle(.plain)") {
                    violations.append(.init(file: relative, line: lineNumber, rule: "no-plain-button-style", snippet: trimmed))
                }
                if matches(trimmed, pattern: #"\.(alert|sheet|confirmationDialog|fullScreenCover)\s*\("#) {
                    violations.append(.init(file: relative, line: lineNumber, rule: "no-raw-feedback-api", snippet: trimmed))
                }

                if trimmed.contains("AppButton(") {
                    let variant = firstMatch(in: trimmed, pattern: #"variant:\s*\.([A-Za-z]+)"#, group: 1) ?? "primary"
                    let name = firstMatch(in: trimmed, pattern: #"AppButton\(\"([^\"]+)\""#, group: 1) ?? "dynamic-title"
                    if !allowedVariants.contains(variant) {
                        violations.append(.init(file: relative, line: lineNumber, rule: "unsupported-button-variant", snippet: trimmed))
                    }
                    buttonRecords.append(.init(page: page, file: relative, line: lineNumber, name: name, component: "AppButton(.\(variant))"))
                }
                if trimmed.contains("AppRowTapButton") {
                    buttonRecords.append(.init(page: page, file: relative, line: lineNumber, name: "custom-row-tap", component: "AppRowTapButton"))
                }
                if trimmed.contains("AppMenuAction(") {
                    let name = firstMatch(in: trimmed, pattern: #"AppMenuAction\(\"([^\"]+)\""#, group: 1) ?? "menu-action"
                    buttonRecords.append(.init(page: page, file: relative, line: lineNumber, name: name, component: "AppMenuAction"))
                }

                if trimmed.contains(".appToast(") {
                    feedbackRecords.append(.init(page: page, file: relative, line: lineNumber, scenario: "toast-host", component: "appToast"))
                }
                if trimmed.contains("AppToastPayload(") {
                    let scenario = firstMatch(in: trimmed, pattern: #"title:\s*\"([^\"]+)\""#, group: 1) ?? "toast"
                    feedbackRecords.append(.init(page: page, file: relative, line: lineNumber, scenario: scenario, component: "AppToastPayload"))
                }
                if trimmed.contains(".appAlert(") {
                    feedbackRecords.append(.init(page: page, file: relative, line: lineNumber, scenario: "alert", component: "appAlert"))
                }
                if trimmed.contains(".appConfirmationDialog(") {
                    feedbackRecords.append(.init(page: page, file: relative, line: lineNumber, scenario: "confirmation", component: "appConfirmationDialog"))
                }
                if trimmed.contains(".appSheet(") {
                    feedbackRecords.append(.init(page: page, file: relative, line: lineNumber, scenario: "sheet", component: "appSheet"))
                }
            }
        }

        return AuditResult(
            buttonRecords: buttonRecords,
            feedbackRecords: feedbackRecords,
            violations: violations,
            buttonInventoryContent: renderButtonInventory(buttonRecords),
            feedbackInventoryContent: renderFeedbackInventory(feedbackRecords)
        )
    }

    func renderButtonInventory(_ records: [ButtonUsageRecord]) -> String {
        let sorted = records.sorted {
            if $0.page != $1.page { return $0.page < $1.page }
            if $0.file != $1.file { return $0.file < $1.file }
            return $0.line < $1.line
        }

        var lines: [String] = []
        lines.append("# Button Usage Inventory")
        lines.append("")
        lines.append("[PROTOCOL]: 变更时更新此头部，然后检查 agents.md")
        lines.append("")
        lines.append("**类型**: AUTO-GENERATED")
        lines.append("**脚本**: `docs/03_Governance/tools/governance_audit.swift --mode generate`")
        lines.append("")
        lines.append("| 页面 | 文件 | 行号 | 按钮名称 | 规范组件 |")
        lines.append("| --- | --- | --- | --- | --- |")

        if sorted.isEmpty {
            lines.append("| - | - | - | - | - |")
        } else {
            for record in sorted {
                lines.append("| \(record.page) | `\(record.file)` | \(record.line) | \(record.name) | `\(record.component)` |")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    func renderFeedbackInventory(_ records: [FeedbackUsageRecord]) -> String {
        let sorted = records.sorted {
            if $0.page != $1.page { return $0.page < $1.page }
            if $0.file != $1.file { return $0.file < $1.file }
            return $0.line < $1.line
        }

        var lines: [String] = []
        lines.append("# Feedback Usage Inventory")
        lines.append("")
        lines.append("[PROTOCOL]: 变更时更新此头部，然后检查 agents.md")
        lines.append("")
        lines.append("**类型**: AUTO-GENERATED")
        lines.append("**脚本**: `docs/03_Governance/tools/governance_audit.swift --mode generate`")
        lines.append("")
        lines.append("| 页面 | 文件 | 行号 | 场景 | 规范组件 |")
        lines.append("| --- | --- | --- | --- | --- |")

        if sorted.isEmpty {
            lines.append("| - | - | - | - | - |")
        } else {
            for record in sorted {
                lines.append("| \(record.page) | `\(record.file)` | \(record.line) | \(record.scenario) | `\(record.component)` |")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    func checkInventory(root: URL) throws -> [String] {
        let result = try audit(root: root)
        let buttonPath = root.appendingPathComponent("docs/03_Governance/按钮使用清单.md")
        let feedbackPath = root.appendingPathComponent("docs/03_Governance/反馈使用清单.md")

        var mismatches: [String] = []

        let currentButton = try String(contentsOf: buttonPath, encoding: .utf8)
        if currentButton != result.buttonInventoryContent {
            mismatches.append("button inventory")
        }

        let currentFeedback = try String(contentsOf: feedbackPath, encoding: .utf8)
        if currentFeedback != result.feedbackInventoryContent {
            mismatches.append("feedback inventory")
        }

        return mismatches
    }

    func makeFixtureRoot(withRawButton: Bool) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesignGovernanceFixture-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("BianLunMiao/Views", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("docs/03_Governance", isDirectory: true),
            withIntermediateDirectories: true
        )

        let content: String
        if withRawButton {
            content = "import SwiftUI\\nstruct Demo: View { var body: some View { Button(\\\"X\\\") {} } }\\n"
        } else {
            content = "import SwiftUI\\nstruct Demo: View { var body: some View { AppButton(\\\"X\\\", variant: .primary) {} } }\\n"
        }

        try write(content, to: root.appendingPathComponent("BianLunMiao/Views/DemoView.swift"))
        try write(renderButtonInventory([]), to: root.appendingPathComponent("docs/03_Governance/按钮使用清单.md"))
        try write(renderFeedbackInventory([]), to: root.appendingPathComponent("docs/03_Governance/反馈使用清单.md"))

        return root
    }

    func write(_ text: String, to path: URL) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: path, atomically: true, encoding: .utf8)
    }

    func listSwiftFiles(in root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            files.append(item)
        }

        return files.sorted { $0.path < $1.path }
    }

    func relativePath(of file: URL, root: URL) -> String {
        let prefix = root.path + "/"
        if file.path.hasPrefix(prefix) {
            return String(file.path.dropFirst(prefix.count))
        }
        return file.path
    }

    func matches(_ input: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(input.startIndex..., in: input)
        return regex.firstMatch(in: input, range: range) != nil
    }

    func firstMatch(in input: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard
            let match = regex.firstMatch(in: input, range: range),
            let capture = Range(match.range(at: group), in: input)
        else {
            return nil
        }
        return String(input[capture])
    }
}
