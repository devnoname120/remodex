// FILE: CodexPerformanceDiagnostics.swift
// Purpose: Centralizes low-noise performance diagnostics for Instruments-driven profiling.
// Layer: Service Support
// Exports: CodexPerformanceDiagnostics
// Depends on: Foundation, OSLog

import Foundation
import OSLog

enum CodexPerformanceDiagnostics {
    enum Category: Hashable {
        case timeline
        case sidebar
        case root
        case service
    }

    struct Interval {
        fileprivate let name: StaticString
        fileprivate let signposter: OSSignposter
        fileprivate let state: OSSignpostIntervalState
    }

    static let verboseLoggingEnabled = makeVerboseLoggingEnabled(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )

    static func makeVerboseLoggingEnabled(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if arguments.contains("-CodexPerfVerboseLogs") {
            return true
        }

        guard let rawValue = environment["CODEX_PERF_VERBOSE_LOGS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty else {
            return false
        }

        switch rawValue.lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    static func beginInterval(_ name: StaticString, category: Category) -> Interval {
        let signposter = signposter(for: category)
        return Interval(
            name: name,
            signposter: signposter,
            state: signposter.beginInterval(name)
        )
    }

    static func endInterval(_ interval: Interval) {
        interval.signposter.endInterval(interval.name, interval.state)
    }

    static func measure<T>(
        _ name: StaticString,
        category: Category,
        _ block: () throws -> T
    ) rethrows -> T {
        let interval = beginInterval(name, category: category)
        defer { endInterval(interval) }
        return try block()
    }

    static func nextDebugSequence(for category: Category) -> Int {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }
        let nextValue = (debugSequenceByCategory[category] ?? 0) + 1
        debugSequenceByCategory[category] = nextValue
        return nextValue
    }

    private static func signposter(for category: Category) -> OSSignposter {
        switch category {
        case .timeline:
            return timelineSignposter
        case .sidebar:
            return sidebarSignposter
        case .root:
            return rootSignposter
        case .service:
            return serviceSignposter
        }
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "CodexMobile"
    private static let timelineSignposter = OSSignposter(
        logger: Logger(subsystem: subsystem, category: "Performance.Timeline")
    )
    private static let sidebarSignposter = OSSignposter(
        logger: Logger(subsystem: subsystem, category: "Performance.Sidebar")
    )
    private static let rootSignposter = OSSignposter(
        logger: Logger(subsystem: subsystem, category: "Performance.Root")
    )
    private static let serviceSignposter = OSSignposter(
        logger: Logger(subsystem: subsystem, category: "Performance.Service")
    )
    private static let sequenceLock = NSLock()
    private static var debugSequenceByCategory: [Category: Int] = [:]
}
