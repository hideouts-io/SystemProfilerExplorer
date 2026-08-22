import Foundation

enum ReportChangeKind: String, CaseIterable, Identifiable, Sendable {
    case added
    case removed
    case changed

    var id: String { rawValue }
}

struct ReportChange: Identifiable, Sendable, Equatable {
    let kind: ReportChangeKind
    let dataType: SystemProfilerDataType
    let recordIdentifier: String
    let recordLabel: String
    let catalogPath: [String]
    let sourcePath: String
    let previousValue: ProfileScalar?
    let currentValue: ProfileScalar?

    var id: String {
        [kind.rawValue, dataType.rawValue, recordIdentifier, sourcePath].joined(separator: "|")
    }
}

struct ReportComparisonSummary: Sendable, Equatable {
    let baselineFindingCount: Int
    let currentFindingCount: Int
    let addedCount: Int
    let removedCount: Int
    let changedCount: Int
    let unchangedCount: Int

    var changeCount: Int {
        addedCount + removedCount + changedCount
    }
}

struct ReportComparison: Identifiable, Sendable, Equatable {
    let baselineCompletedAt: Date
    let currentCompletedAt: Date
    let summary: ReportComparisonSummary
    let changes: [ReportChange]

    var id: String {
        "\(baselineCompletedAt.timeIntervalSince1970)-\(currentCompletedAt.timeIntervalSince1970)"
    }
}

enum ReportComparisonError: LocalizedError, Equatable {
    case redactedBaseline
    case missingFullReportMetadata(field: String)
    case emptyBaseline
    case expectedSingleFile(count: Int)
    case coverageMismatch(baseline: [String], current: [String])

    var errorDescription: String? {
        switch self {
        case .redactedBaseline:
            "The selected report is redacted, so its original values cannot be compared. Select a full private report instead."
        case let .missingFullReportMetadata(field):
            "The selected full report is missing the required \(field) metadata. Export it again from System Profiler Explorer."
        case .emptyBaseline:
            "The selected report does not contain any profiler sections to compare."
        case let .expectedSingleFile(count):
            "Select exactly one saved report. The importer returned \(count) files."
        case let .coverageMismatch(baseline, current):
            "The saved report covers \(baseline.joined(separator: ", ")), while the current scan covers \(current.joined(separator: ", ")). Compare reports created from the same subject or full-report scope."
        }
    }
}

func comparisonBaselineReport(from export: ReportExportEnvelope) throws -> SystemProfilerReport {
    guard export.privacy == .full else {
        throw ReportComparisonError.redactedBaseline
    }

    guard !export.report.sections.isEmpty else {
        throw ReportComparisonError.emptyBaseline
    }

    guard let standardError = export.report.standardError else {
        throw ReportComparisonError.missingFullReportMetadata(field: "standard error")
    }

    guard let startedAt = export.report.startedAt else {
        throw ReportComparisonError.missingFullReportMetadata(field: "start time")
    }

    guard let completedAt = export.report.completedAt else {
        throw ReportComparisonError.missingFullReportMetadata(field: "completion time")
    }

    return SystemProfilerReport(
        sections: export.report.sections,
        commandArguments: export.report.commandArguments,
        standardError: standardError,
        startedAt: startedAt,
        completedAt: completedAt
    )
}

func compareReports(
    baseline: SystemProfilerReport,
    current: SystemProfilerReport
) throws -> ReportComparison {
    let baselineCoverage: [SystemProfilerDataType] = reportCoverage(baseline)
    let currentCoverage: [SystemProfilerDataType] = reportCoverage(current)

    guard baselineCoverage == currentCoverage else {
        throw ReportComparisonError.coverageMismatch(
            baseline: baselineCoverage.map(\.title),
            current: currentCoverage.map(\.title)
        )
    }

    let baselineFindings: [ComparisonFindingKey: ComparableFinding] = comparableFindings(baseline)
    let currentFindings: [ComparisonFindingKey: ComparableFinding] = comparableFindings(current)
    var changes: [ReportChange] = []
    var unchangedCount: Int = 0

    for (key, currentFinding) in currentFindings {
        guard let baselineFinding = baselineFindings[key] else {
            changes.append(reportChange(
                kind: .added,
                finding: currentFinding,
                previousValue: nil,
                currentValue: currentFinding.value
            ))
            continue
        }

        if baselineFinding.value == currentFinding.value {
            unchangedCount += 1
        } else {
            changes.append(reportChange(
                kind: .changed,
                finding: currentFinding,
                previousValue: baselineFinding.value,
                currentValue: currentFinding.value
            ))
        }
    }

    for (key, baselineFinding) in baselineFindings where currentFindings[key] == nil {
        changes.append(reportChange(
            kind: .removed,
            finding: baselineFinding,
            previousValue: baselineFinding.value,
            currentValue: nil
        ))
    }

    let sortedChanges: [ReportChange] = changes.sorted(by: reportChangePrecedes)
    let addedCount: Int = sortedChanges.count { $0.kind == .added }
    let removedCount: Int = sortedChanges.count { $0.kind == .removed }
    let changedCount: Int = sortedChanges.count { $0.kind == .changed }

    return ReportComparison(
        baselineCompletedAt: baseline.completedAt,
        currentCompletedAt: current.completedAt,
        summary: ReportComparisonSummary(
            baselineFindingCount: baselineFindings.count,
            currentFindingCount: currentFindings.count,
            addedCount: addedCount,
            removedCount: removedCount,
            changedCount: changedCount,
            unchangedCount: unchangedCount
        ),
        changes: sortedChanges
    )
}

private enum ComparisonPathComponent: Sendable, Hashable {
    case field(String)
    case index(Int)
}

private struct ComparisonFindingKey: Sendable, Hashable {
    let dataType: SystemProfilerDataType
    let recordIdentifier: String
    let path: [ComparisonPathComponent]
}

private struct ComparableFinding: Sendable {
    let key: ComparisonFindingKey
    let dataType: SystemProfilerDataType
    let recordLabel: String
    let catalogPath: [String]
    let sourcePath: String
    let value: ProfileScalar
}

private func comparableFindings(
    _ report: SystemProfilerReport
) -> [ComparisonFindingKey: ComparableFinding] {
    report.sections.reduce(into: [:]) { reportResult, section in
        var nameOccurrences: [String: Int] = [:]

        for (recordIndex, item) in section.items.enumerated() {
            let recordLabel: String = item.preferredName ?? "Record \(recordIndex + 1)"
            let recordIdentifier: String

            if let preferredName = item.preferredName {
                let occurrence: Int = nameOccurrences[preferredName, default: 0]
                nameOccurrences[preferredName] = occurrence + 1
                recordIdentifier = "name:\(preferredName)#\(occurrence)"
            } else {
                recordIdentifier = "index:\(recordIndex)"
            }

            let findings: [ComparableFinding] = flattenProfileValue(
                item,
                dataType: section.dataType,
                recordIdentifier: recordIdentifier,
                recordLabel: recordLabel,
                path: [],
                catalogPath: []
            )

            for finding in findings {
                reportResult[finding.key] = finding
            }
        }
    }
}

private func flattenProfileValue(
    _ value: ProfileValue,
    dataType: SystemProfilerDataType,
    recordIdentifier: String,
    recordLabel: String,
    path: [ComparisonPathComponent],
    catalogPath: [String]
) -> [ComparableFinding] {
    switch value {
    case let .object(object):
        object
            .filter { $0.key != "_name" }
            .flatMap { field in
                flattenProfileValue(
                    field.value,
                    dataType: dataType,
                    recordIdentifier: recordIdentifier,
                    recordLabel: recordLabel,
                    path: path + [.field(field.key)],
                    catalogPath: catalogPath + [field.key]
                )
            }

    case let .array(values):
        values.enumerated().flatMap { index, child in
            flattenProfileValue(
                child,
                dataType: dataType,
                recordIdentifier: recordIdentifier,
                recordLabel: recordLabel,
                path: path + [.index(index)],
                catalogPath: catalogPath + ["[]"]
            )
        }

    case let .string(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            catalogPath: catalogPath,
            value: .string(value)
        )]

    case let .integer(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            catalogPath: catalogPath,
            value: .integer(value)
        )]

    case let .decimal(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            catalogPath: catalogPath,
            value: .decimal(value)
        )]

    case let .boolean(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            catalogPath: catalogPath,
            value: .boolean(value)
        )]

    case .null:
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            catalogPath: catalogPath,
            value: .null
        )]
    }
}

private func comparableFinding(
    dataType: SystemProfilerDataType,
    recordIdentifier: String,
    recordLabel: String,
    path: [ComparisonPathComponent],
    catalogPath: [String],
    value: ProfileScalar
) -> ComparableFinding {
    ComparableFinding(
        key: ComparisonFindingKey(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            path: path
        ),
        dataType: dataType,
        recordLabel: recordLabel,
        catalogPath: catalogPath,
        sourcePath: indexedSourcePath(dataType: dataType, path: path),
        value: value
    )
}

private func indexedSourcePath(
    dataType: SystemProfilerDataType,
    path: [ComparisonPathComponent]
) -> String {
    path.reduce(dataType.rawValue) { result, component in
        switch component {
        case let .field(key): "\(result).\(key)"
        case let .index(index): "\(result)[\(index)]"
        }
    }
}

private func reportChange(
    kind: ReportChangeKind,
    finding: ComparableFinding,
    previousValue: ProfileScalar?,
    currentValue: ProfileScalar?
) -> ReportChange {
    ReportChange(
        kind: kind,
        dataType: finding.dataType,
        recordIdentifier: finding.key.recordIdentifier,
        recordLabel: finding.recordLabel,
        catalogPath: finding.catalogPath,
        sourcePath: finding.sourcePath,
        previousValue: previousValue,
        currentValue: currentValue
    )
}

private func reportChangePrecedes(_ lhs: ReportChange, _ rhs: ReportChange) -> Bool {
    let lhsKey: String = [
        lhs.dataType.title,
        lhs.recordLabel,
        lhs.recordIdentifier,
        lhs.sourcePath
    ].joined(separator: "|")
    let rhsKey: String = [
        rhs.dataType.title,
        rhs.recordLabel,
        rhs.recordIdentifier,
        rhs.sourcePath
    ].joined(separator: "|")
    return lhsKey.localizedStandardCompare(rhsKey) == .orderedAscending
}

private func reportCoverage(_ report: SystemProfilerReport) -> [SystemProfilerDataType] {
    report.sections
        .map(\.dataType)
        .sorted { $0.rawValue < $1.rawValue }
}
