#!/usr/bin/env swift

import Foundation

// [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
// INPUT: 仓库源码与治理文档。
// OUTPUT: 违规清单 + 自动生成 Inventory 文档。
// POS: 文档治理层-一致性审计脚本。

struct ButtonUsageRecord {
    let page: String
    let file: String
    let line: Int
    let name: String
    let component: String
}

struct FeedbackUsageRecord {
    let page: String
    let file: String
    let line: Int
    let scenario: String
    let component: String
}

struct ViolationRecord {
    let file: String
    let line: Int
    let rule: String
    let snippet: String
}

enum Mode: String {
    case generate
    case check
}

struct Config {
    let mode: Mode
    let root: URL
}

enum GovernanceError: Error, CustomStringConvertible {
    case invalidArguments(String)

    var description: String {
        switch self {
        case .invalidArguments(let message):
            return message
        }
    }
}

private func parseArguments() throws -> Config {
    var mode: Mode = .check
    var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    var index = 1
    let args = CommandLine.arguments

    while index < args.count {
        let key = args[index]
        switch key {
        case "--mode":
            guard index + 1 < args.count, let parsed = Mode(rawValue: args[index + 1]) else {
                throw GovernanceError.invalidArguments("--mode expects generate|check")
            }
            mode = parsed
            index += 2
        case "--root":
            guard index + 1 < args.count else {
                throw GovernanceError.invalidArguments("--root expects a path")
            }
            root = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            index += 2
        default:
            throw GovernanceError.invalidArguments("Unknown argument: \(key)")
        }
    }

    return Config(mode: mode, root: root)
}

private struct AuditResult {
    let buttonRecords: [ButtonUsageRecord]
    let feedbackRecords: [FeedbackUsageRecord]
    let violations: [ViolationRecord]
    let buttonInventoryContent: String
    let feedbackInventoryContent: String
    let buttonInventoryPath: URL
    let feedbackInventoryPath: URL

    func writeInventories() throws {
        try FileManager.default.createDirectory(
            at: buttonInventoryPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try buttonInventoryContent.write(to: buttonInventoryPath, atomically: true, encoding: .utf8)
        try feedbackInventoryContent.write(to: feedbackInventoryPath, atomically: true, encoding: .utf8)
    }

    func inventoryMismatches() throws -> [String] {
        var mismatches: [String] = []

        let currentButton = try readFileOrEmpty(buttonInventoryPath)
        let currentFeedback = try readFileOrEmpty(feedbackInventoryPath)

        if currentButton != buttonInventoryContent {
            mismatches.append("Button inventory is out of date: \(buttonInventoryPath.path)")
        }
        if currentFeedback != feedbackInventoryContent {
            mismatches.append("Feedback inventory is out of date: \(feedbackInventoryPath.path)")
        }

        return mismatches
    }

    private func readFileOrEmpty(_ path: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: path.path) else { return "" }
        return try String(contentsOf: path, encoding: .utf8)
    }
}

private struct Auditor {
    let config: Config

    private var viewsRoot: URL {
        config.root.appendingPathComponent("BianLunMiao/Views", isDirectory: true)
    }

    private var buttonInventoryPath: URL {
        config.root.appendingPathComponent("docs/03_Governance/按钮使用清单.md")
    }

    private var feedbackInventoryPath: URL {
        config.root.appendingPathComponent("docs/03_Governance/反馈使用清单.md")
    }

    func run() throws -> AuditResult {
        let swiftFiles = try listSwiftFiles(in: viewsRoot)
        let allowedVariants: Set<String> = [
            "primary",
            "secondary",
            "compactSecondary",
            "miniSecondary",
            "ghost",
            "toolbarText",
            "topBarIcon"
        ]

        var buttonRecords: [ButtonUsageRecord] = []
        var feedbackRecords: [FeedbackUsageRecord] = []
        var violations: [ViolationRecord] = []

        for file in swiftFiles {
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let relativePath = relativePath(of: file)
            let page = file.deletingPathExtension().lastPathComponent

            for (offset, line) in lines.enumerated() {
                let lineNumber = offset + 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if matches(trimmed, pattern: #"\bButton\s*\("#) {
                    violations.append(
                        ViolationRecord(
                            file: relativePath,
                            line: lineNumber,
                            rule: "no-raw-button",
                            snippet: trimmed
                        )
                    )
                }

                if trimmed.contains(".buttonStyle(.plain)") {
                    violations.append(
                        ViolationRecord(
                            file: relativePath,
                            line: lineNumber,
                            rule: "no-plain-button-style",
                            snippet: trimmed
                        )
                    )
                }

                if matches(trimmed, pattern: #"\.(alert|sheet|confirmationDialog|fullScreenCover)\s*\("#) {
                    violations.append(
                        ViolationRecord(
                            file: relativePath,
                            line: lineNumber,
                            rule: "no-raw-feedback-api",
                            snippet: trimmed
                        )
                    )
                }

                if trimmed.contains("AppButton(") {
                    let variant = firstMatch(in: trimmed, pattern: #"variant:\s*\.([A-Za-z]+)"#, group: 1) ?? "primary"
                    let name = parseAppButtonName(from: trimmed)

                    if !allowedVariants.contains(variant) {
                        violations.append(
                            ViolationRecord(
                                file: relativePath,
                                line: lineNumber,
                                rule: "unsupported-button-variant",
                                snippet: trimmed
                            )
                        )
                    }

                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: name,
                            component: "AppButton(.\(variant))"
                        )
                    )
                }

                if trimmed.contains("AppIconButton(") {
                    let name = firstMatch(in: trimmed, pattern: #"accessibilityTitle:\s*\"([^\"]+)\""#, group: 1) ?? "icon"
                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: name,
                            component: "AppIconButton(.topBarIcon)"
                        )
                    )
                }

                if trimmed.contains("AppRowTapButton") {
                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: "custom-row-tap",
                            component: "AppRowTapButton"
                        )
                    )
                }

                if trimmed.contains("AppTopBarButton(") {
                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: "top-bar-action",
                            component: "AppTopBarButton(.topBarIcon)"
                        )
                    )
                }

                if trimmed.contains("AppNavBarBackButton") {
                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: "back-button",
                            component: "AppNavBarBackButton"
                        )
                    )
                }

                if trimmed.contains("AppDetailTopBar(") {
                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: "返回",
                            component: "AppDetailTopBar.back"
                        )
                    )

                    let upperBound = min(lines.count - 1, offset + 8)
                    let window = lines[offset...upperBound].joined(separator: "\n")
                    if let symbol = firstMatch(
                        in: window,
                        pattern: #"trailingSystemName:\s*[^"\n]*"([^"]+)""#,
                        group: 1
                    ) {
                        buttonRecords.append(
                            ButtonUsageRecord(
                                page: page,
                                file: relativePath,
                                line: lineNumber,
                                name: "顶部动作(\(symbol))",
                                component: "AppDetailTopBar.trailing"
                            )
                        )
                    }
                }

                if trimmed.contains("AppMenuAction(") {
                    let title = firstMatch(in: trimmed, pattern: #"AppMenuAction\(\"([^\"]+)\""#, group: 1) ?? "menu-action"
                    buttonRecords.append(
                        ButtonUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            name: title,
                            component: "AppMenuAction"
                        )
                    )
                }

                if trimmed.contains(".appToast(") {
                    feedbackRecords.append(
                        FeedbackUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            scenario: "toast-host",
                            component: "appToast"
                        )
                    )
                }

                if trimmed.contains("AppToastPayload(") {
                    let title = firstMatch(in: trimmed, pattern: #"title:\s*\"([^\"]+)\""#, group: 1) ?? "toast"
                    feedbackRecords.append(
                        FeedbackUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            scenario: title,
                            component: "AppToastPayload"
                        )
                    )
                }

                if trimmed.contains(".appAlert(") {
                    let title = firstMatch(in: trimmed, pattern: #"\.appAlert\(\"([^\"]+)\""#, group: 1) ?? "alert"
                    feedbackRecords.append(
                        FeedbackUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            scenario: title,
                            component: "appAlert"
                        )
                    )
                }

                if trimmed.contains(".appConfirmationDialog(") {
                    let title = firstMatch(in: trimmed, pattern: #"\.appConfirmationDialog\(\"([^\"]+)\""#, group: 1) ?? "confirmation"
                    feedbackRecords.append(
                        FeedbackUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            scenario: title,
                            component: "appConfirmationDialog"
                        )
                    )
                }

                if trimmed.contains(".appSheet(") {
                    feedbackRecords.append(
                        FeedbackUsageRecord(
                            page: page,
                            file: relativePath,
                            line: lineNumber,
                            scenario: "sheet",
                            component: "appSheet"
                        )
                    )
                }
            }
        }

        let buttonInventoryContent = renderButtonInventory(records: buttonRecords.sorted(by: sortButtonRecords))
        let feedbackInventoryContent = renderFeedbackInventory(records: feedbackRecords.sorted(by: sortFeedbackRecords))

        return AuditResult(
            buttonRecords: buttonRecords,
            feedbackRecords: feedbackRecords,
            violations: violations,
            buttonInventoryContent: buttonInventoryContent,
            feedbackInventoryContent: feedbackInventoryContent,
            buttonInventoryPath: buttonInventoryPath,
            feedbackInventoryPath: feedbackInventoryPath
        )
    }

    private func parseAppButtonName(from line: String) -> String {
        if let quoted = firstMatch(in: line, pattern: #"AppButton\(\"([^\"]+)\""#, group: 1) {
            return quoted
        }

        guard let startRange = line.range(of: "AppButton(") else { return "dynamic-title" }
        let tail = line[startRange.upperBound...]
        let token = tail
            .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "dynamic-title"

        return token.isEmpty ? "dynamic-title" : token
    }

    private func renderButtonInventory(records: [ButtonUsageRecord]) -> String {
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

        if records.isEmpty {
            lines.append("| - | - | - | - | - |")
        } else {
            for record in records {
                lines.append("| \(record.page) | `\(record.file)` | \(record.line) | \(escapePipes(record.name)) | `\(record.component)` |")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func renderFeedbackInventory(records: [FeedbackUsageRecord]) -> String {
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

        if records.isEmpty {
            lines.append("| - | - | - | - | - |")
        } else {
            for record in records {
                lines.append("| \(record.page) | `\(record.file)` | \(record.line) | \(escapePipes(record.scenario)) | `\(record.component)` |")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func sortButtonRecords(lhs: ButtonUsageRecord, rhs: ButtonUsageRecord) -> Bool {
        if lhs.page != rhs.page { return lhs.page < rhs.page }
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        return lhs.line < rhs.line
    }

    private func sortFeedbackRecords(lhs: FeedbackUsageRecord, rhs: FeedbackUsageRecord) -> Bool {
        if lhs.page != rhs.page { return lhs.page < rhs.page }
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        return lhs.line < rhs.line
    }

    private func listSwiftFiles(in root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            files.append(item)
        }

        return files.sorted { $0.path < $1.path }
    }

    private func relativePath(of url: URL) -> String {
        let fullPath = url.path
        let rootPath = config.root.path + "/"
        if fullPath.hasPrefix(rootPath) {
            return String(fullPath.dropFirst(rootPath.count))
        }
        return fullPath
    }

    private func matches(_ input: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(input.startIndex..., in: input)
        return regex.firstMatch(in: input, range: range) != nil
    }

    private func firstMatch(in input: String, pattern: String, group: Int) -> String? {
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

    private func escapePipes(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}

do {
    let config = try parseArguments()
    let auditor = Auditor(config: config)
    let result = try auditor.run()

    if !result.violations.isEmpty {
        print("❌ Governance violations found:")
        for violation in result.violations {
            print("- \(violation.file):\(violation.line) [\(violation.rule)] \(violation.snippet)")
        }
        exit(1)
    }

    switch config.mode {
    case .generate:
        try result.writeInventories()
        print("✅ Generated inventories:")
        print("- \(result.buttonInventoryPath.path)")
        print("- \(result.feedbackInventoryPath.path)")
    case .check:
        let mismatches = try result.inventoryMismatches()
        if !mismatches.isEmpty {
            print("❌ Inventory mismatch found:")
            for mismatch in mismatches {
                print("- \(mismatch)")
            }
            print("Run: swift docs/03_Governance/tools/governance_audit.swift --mode generate")
            exit(1)
        }
        print("✅ Governance check passed")
    }
} catch {
    print("❌ \(error)")
    exit(1)
}
