import Foundation

enum CollectionAttemptHealth: Sendable, Equatable {
    case notCollected
    case running
    case completed
    case imported
    case timedOut
    case permissionLimited
    case unavailable
    case failed

    var title: String {
        switch self {
        case .notCollected: "Not collected"
        case .running: "Collecting"
        case .completed: "Collection complete"
        case .imported: "Imported report"
        case .timedOut: "Timed out"
        case .permissionLimited: "Permission-limited"
        case .unavailable: "Unavailable"
        case .failed: "Collection failed"
        }
    }

    var symbolName: String {
        switch self {
        case .notCollected: "circle.dashed"
        case .running: "progress.indicator"
        case .completed: "checkmark.circle.fill"
        case .imported: "square.and.arrow.down"
        case .timedOut: "clock.badge.exclamationmark"
        case .permissionLimited: "lock.trianglebadge.exclamationmark"
        case .unavailable: "exclamationmark.triangle"
        case .failed: "xmark.circle.fill"
        }
    }
}

func collectionAttemptHealth(for error: SystemProfilerCollectorError) -> CollectionAttemptHealth {
    switch error {
    case .timedOut:
        return .timedOut
    case .emptyOutput:
        return .unavailable
    case let .unsuccessfulExit(_, standardError):
        let normalizedError: String = standardError.lowercased()
        if normalizedError.contains("operation not permitted")
            || normalizedError.contains("permission denied")
            || normalizedError.contains("not authorized") {
            return .permissionLimited
        }

        if normalizedError.contains("unavailable")
            || normalizedError.contains("not supported")
            || normalizedError.contains("unsupported") {
            return .unavailable
        }

        return .failed
    case .alreadyRunning, .launchFailed:
        return .failed
    }
}
