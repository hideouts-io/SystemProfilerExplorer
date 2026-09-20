import Foundation

enum CollectionCoverageSource: Sendable, Equatable {
    case liveScan
    case importedReport

    var title: String {
        switch self {
        case .liveScan: "Live scan"
        case .importedReport: "Imported report"
        }
    }
}

enum CollectionDataTypeStatus: Sendable, Equatable {
    case collected
    case empty
    case skipped
    case unavailable
    case timedOut
    case permissionLimited

    var title: String {
        switch self {
        case .collected: "Collected"
        case .empty: "No records"
        case .skipped: "Skipped"
        case .unavailable: "Unavailable"
        case .timedOut: "Timed out"
        case .permissionLimited: "Permission-limited"
        }
    }

    var symbolName: String {
        switch self {
        case .collected: "checkmark.circle.fill"
        case .empty: "tray"
        case .skipped: "minus.circle"
        case .unavailable: "exclamationmark.triangle"
        case .timedOut: "clock.badge.exclamationmark"
        case .permissionLimited: "lock.trianglebadge.exclamationmark"
        }
    }
}

struct CollectionCoverageEntry: Identifiable, Sendable, Equatable {
    let dataType: SystemProfilerDataType
    let status: CollectionDataTypeStatus

    var id: String { dataType.rawValue }
}

struct CollectionCoverage: Sendable, Equatable {
    let source: CollectionCoverageSource
    let entries: [CollectionCoverageEntry]

    var collectedCount: Int {
        entries.count { $0.status == .collected }
    }

    var emptyCount: Int {
        entries.count { $0.status == .empty }
    }

    var skippedEntries: [CollectionCoverageEntry] {
        entries.filter { $0.status == .skipped }
    }

    var skippedCount: Int {
        skippedEntries.count
    }

    var unavailableCount: Int {
        entries.count { $0.status == .unavailable }
    }

    var timedOutCount: Int {
        entries.count { $0.status == .timedOut }
    }

    var permissionLimitedCount: Int {
        entries.count { $0.status == .permissionLimited }
    }

    var incompleteEntries: [CollectionCoverageEntry] {
        entries.filter { entry in
            switch entry.status {
            case .collected, .empty: false
            case .skipped, .unavailable, .timedOut, .permissionLimited: true
            }
        }
    }
}

func collectionCoverage(for report: SystemProfilerReport) -> CollectionCoverage {
    let requestedDataTypes: [SystemProfilerDataType] = requestedDataTypes(
        from: report.commandArguments
    )

    if requestedDataTypes.isEmpty {
        return CollectionCoverage(
            source: .importedReport,
            entries: report.sections.map { section in
                CollectionCoverageEntry(
                    dataType: section.dataType,
                    status: section.items.isEmpty ? .empty : .collected
                )
            }
        )
    }

    let sectionsByDataType: [SystemProfilerDataType: SystemProfilerSection] = Dictionary(
        uniqueKeysWithValues: report.sections.map { section in
            (section.dataType, section)
        }
    )

    return CollectionCoverage(
        source: .liveScan,
        entries: requestedDataTypes.map { dataType in
            guard let section: SystemProfilerSection = sectionsByDataType[dataType] else {
                return CollectionCoverageEntry(
                    dataType: dataType,
                    status: missingCollectionStatus(standardError: report.standardError)
                )
            }

            return CollectionCoverageEntry(
                dataType: dataType,
                status: section.items.isEmpty ? .empty : .collected
            )
        }
    )
}

private func missingCollectionStatus(standardError: String) -> CollectionDataTypeStatus {
    let normalizedError: String = standardError.lowercased()

    if normalizedError.contains("timed out") || normalizedError.contains("timeout") {
        return .timedOut
    }

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

    return .skipped
}

private func requestedDataTypes(from arguments: [String]) -> [SystemProfilerDataType] {
    var seenDataTypes: Set<SystemProfilerDataType> = []

    return arguments.compactMap(SystemProfilerDataType.init(rawValue:)).filter { dataType in
        seenDataTypes.insert(dataType).inserted
    }
}
