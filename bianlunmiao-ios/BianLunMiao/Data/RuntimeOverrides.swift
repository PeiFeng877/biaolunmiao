//
//  RuntimeOverrides.swift
//  BianLunMiao
//
//  Updated by Codex on 2026/3/20.
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 进程环境变量与启动参数。
//  OUTPUT: 自动化/调试场景统一运行时开关解析。
//  POS: 数据层-运行时配置入口。
//

import Foundation

enum RuntimeOverrides {
    enum UITestColorScheme: String {
        case light
        case dark
    }

    private static let environment = ProcessInfo.processInfo.environment
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let testBundleSuffix = ".xctest"

    static func string(named key: String) -> String? {
        if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        let keyVariants = [key, "-\(key)"]
        for variant in keyVariants {
            if let index = arguments.firstIndex(of: variant),
               arguments.indices.contains(index + 1) {
                let value = arguments[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }

            let equalsPrefix = "\(variant)="
            if let argument = arguments.first(where: { $0.hasPrefix(equalsPrefix) }) {
                let value = String(argument.dropFirst(equalsPrefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }

        return nil
    }

    static func url(named key: String) -> URL? {
        guard let rawValue = string(named: key) else { return nil }
        return URL(string: rawValue)
    }

    static func bool(named key: String) -> Bool? {
        guard let value = string(named: key)?.lowercased() else { return nil }
        switch value {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    static func isEnabled(_ key: String) -> Bool {
        bool(named: key) == true
    }

    static var uiTestColorScheme: UITestColorScheme? {
        guard isEnabled("BLM_UI_TEST_MODE"),
              let rawValue = string(named: "BLM_UI_TEST_COLOR_SCHEME")?.lowercased() else {
            return nil
        }
        return UITestColorScheme(rawValue: rawValue)
    }

    static var isRunningUnitTests: Bool {
        if string(named: "XCTestConfigurationFilePath") != nil {
            return true
        }
        if string(named: "XCTestBundlePath") != nil {
            return true
        }
        return Bundle.allBundles.contains { bundle in
            bundle.bundlePath.hasSuffix(testBundleSuffix)
        }
    }
}
