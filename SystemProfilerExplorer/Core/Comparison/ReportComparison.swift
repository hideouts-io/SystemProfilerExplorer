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
    /// Evidence uses each report's actual indices, not the sibling matching identity.
    /// An absent side has no source location; the existing sourcePath remains current
    /// for added/changed findings and baseline for removals.
    let baselineAddress: ProfileValueAddress?
    let currentAddress: ProfileValueAddress?
    let previousValue: ProfileScalar?
    let currentValue: ProfileScalar?

    var baselineSourcePath: String? { baselineAddress?.sourcePath }
    var currentSourcePath: String? { currentAddress?.sourcePath }

    var id: String {
        [kind.rawValue, baselineAddress?.identity ?? "absent-baseline", currentAddress?.identity ?? "absent-current"].joined(separator: "|")
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
    /// These are the exact sources that generated the comparison, retained in memory
    /// so evidence lookup never reopens a file or uses a later scan's report.
    let baselineReport: SystemProfilerReport
    let currentReport: SystemProfilerReport
    let summary: ReportComparisonSummary
    let changes: [ReportChange]

    var baselineCompletedAt: Date { baselineReport.completedAt }
    var currentCompletedAt: Date { currentReport.completedAt }

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
    case repeatedSections(dataTypes: [SystemProfilerDataType])
    case incompleteCollection(baseline: [CollectionCoverageEntry], current: [CollectionCoverageEntry])
    case ambiguousRecords(
        dataType: SystemProfilerDataType,
        recordName: String?,
        baselineCount: Int,
        currentCount: Int
    )
    case ambiguousNestedRecords(
        dataType: SystemProfilerDataType,
        recordName: String?,
        baselinePath: String,
        currentPath: String,
        baselineCount: Int,
        currentCount: Int
    )

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
        case let .repeatedSections(dataTypes):
            "The reports contain repeated profiler sections for \(dataTypes.map(\.title).joined(separator: ", ")). Each data type must appear only once. Re-export the reports before comparing; no comparison was produced."
        case let .incompleteCollection(baseline, current):
            incompleteComparisonDescription(baseline: baseline, current: current)
        case let .ambiguousRecords(dataType, recordName, baselineCount, currentCount):
            ambiguousRecordDescription(
                dataType: dataType,
                recordName: recordName,
                baselineCount: baselineCount,
                currentCount: currentCount
            )
        case let .ambiguousNestedRecords(dataType, recordName, baselinePath, currentPath, baselineCount, currentCount):
            ambiguousRecordDescription(
                dataType: dataType,
                recordName: recordName,
                baselineCount: baselineCount,
                currentCount: currentCount
            ) + " The affected array is at \(baselinePath) in the baseline and \(currentPath) in the current report."
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
    try Task.checkCancellation()
    let baselineCoverage: [SystemProfilerDataType] = reportCoverage(baseline)
    let currentCoverage: [SystemProfilerDataType] = reportCoverage(current)

    let repeatedDataTypes: [SystemProfilerDataType] = Set(
        [baselineCoverage, currentCoverage].flatMap { coverage in
            Dictionary(grouping: coverage) { $0 }
                .filter { $0.value.count > 1 }.keys
        }
    ).sorted { $0.rawValue < $1.rawValue }
    guard repeatedDataTypes.isEmpty else {
        throw ReportComparisonError.repeatedSections(dataTypes: repeatedDataTypes)
    }

    // Returned sections can match while a known requested section is missing from
    // either scan. Check after uniqueness validation: collection coverage requires
    // unique sections. Raw imports have no command scope, so none is invented here.
    let baselineIncomplete: [CollectionCoverageEntry] = collectionCoverage(for: baseline).incompleteEntries
    let currentIncomplete: [CollectionCoverageEntry] = collectionCoverage(for: current).incompleteEntries
    guard baselineIncomplete.isEmpty, currentIncomplete.isEmpty else {
        throw ReportComparisonError.incompleteCollection(
            baseline: baselineIncomplete, current: currentIncomplete
        )
    }

    guard baselineCoverage == currentCoverage else {
        throw ReportComparisonError.coverageMismatch(
            baseline: baselineCoverage.map(\.title),
            current: currentCoverage.map(\.title)
        )
    }

    let records: ComparedReportRecords = try comparisonRecords(baseline: baseline, current: current)
    let nestedPaths: ComparedNestedRecordPaths = try comparisonNestedRecordPaths(records)
    let baselineFindings: [ComparisonFindingKey: ComparableFinding] = comparableFindings(
        records.baseline,
        nestedPaths: nestedPaths.baseline
    )
    let currentFindings: [ComparisonFindingKey: ComparableFinding] = comparableFindings(
        records.current,
        nestedPaths: nestedPaths.current
    )
    var changes: [ReportChange] = []
    var unchangedCount: Int = 0

    for (key, currentFinding) in currentFindings {
        try Task.checkCancellation()
        guard let baselineFinding = baselineFindings[key] else {
            changes.append(reportChange(
                kind: .added,
                finding: currentFinding,
                baselineAddress: nil,
                currentAddress: currentFinding.address,
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
                baselineAddress: baselineFinding.address,
                currentAddress: currentFinding.address,
                previousValue: baselineFinding.value,
                currentValue: currentFinding.value
            ))
        }
    }

    for (key, baselineFinding) in baselineFindings where currentFindings[key] == nil {
        try Task.checkCancellation()
        changes.append(reportChange(
            kind: .removed,
            finding: baselineFinding,
            baselineAddress: baselineFinding.address,
            currentAddress: nil,
            previousValue: baselineFinding.value,
            currentValue: nil
        ))
    }

    let sortedChanges: [ReportChange] = changes.sorted(by: reportChangePrecedes)
    let addedCount: Int = sortedChanges.count { $0.kind == .added }
    let removedCount: Int = sortedChanges.count { $0.kind == .removed }
    let changedCount: Int = sortedChanges.count { $0.kind == .changed }

    return ReportComparison(
        baselineReport: baseline,
        currentReport: current,
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
    case record(String)
}

private enum ComparisonRecordLocation {
    case section
    case nested(baselinePath: String, currentPath: String)
}

private struct NestedRecordPath: Sendable, Hashable {
    let dataType: SystemProfilerDataType
    let recordIdentifier: String
    let sourcePath: [ProfileValuePathComponent]
}

private struct ComparedNestedRecordPaths: Sendable {
    let baseline: [NestedRecordPath: String]
    let current: [NestedRecordPath: String]
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
    let address: ProfileValueAddress
    let value: ProfileScalar

    var sourcePath: String { address.sourcePath }
}

private struct IdentifiedComparisonRecord: Sendable {
    let dataType: SystemProfilerDataType
    let value: ProfileValue
    let identifier: String
    let recordIndex: Int
}

private struct ComparedReportRecords: Sendable {
    let baseline: [IdentifiedComparisonRecord]
    let current: [IdentifiedComparisonRecord]
}

/// Both reports have already passed the identical, unique data-type coverage checks.
private func comparisonRecords(
    baseline: SystemProfilerReport,
    current: SystemProfilerReport
) throws -> ComparedReportRecords {
    let baselineSections: [SystemProfilerSection] = baseline.sections.sorted {
        $0.dataType.rawValue < $1.dataType.rawValue
    }
    let currentSections: [SystemProfilerSection] = current.sections.sorted {
        $0.dataType.rawValue < $1.dataType.rawValue
    }
    var baselineRecords: [IdentifiedComparisonRecord] = []
    var currentRecords: [IdentifiedComparisonRecord] = []

    for (baselineSection, currentSection) in zip(baselineSections, currentSections) {
        try Task.checkCancellation()
        let currentIdentifiers: [String]
        if baselineSection.items.count == 1 && currentSection.items.count == 1
            && baselineSection.items[0].preferredName == nil && currentSection.items[0].preferredName == nil {
            currentIdentifiers = ["record:0"]
        } else {
            currentIdentifiers = try currentComparisonRecordIdentifiers(
                baseline: baselineSection.items,
                current: currentSection.items,
                dataType: baselineSection.dataType,
                location: .section
            )
        }
        baselineRecords += baselineSection.items.enumerated().map { index, value in
            IdentifiedComparisonRecord(
                dataType: baselineSection.dataType,
                value: value,
                identifier: "record:\(index)",
                recordIndex: index
            )
        }
        currentRecords += currentSection.items.enumerated().map { index, value in
            IdentifiedComparisonRecord(
                dataType: currentSection.dataType,
                value: value,
                identifier: currentIdentifiers[index],
                recordIndex: index
            )
        }
    }

    return ComparedReportRecords(baseline: baselineRecords, current: currentRecords)
}

/// Match sibling records without inferring identity from encounter order. Names must be
/// unique in the original sibling collections; exact matches consume one occurrence each.
/// Unresolved records on both sides of an ambiguous group fail explicitly. The sole
/// unnamed top-level section-container exception is handled by comparisonRecords.
private func currentComparisonRecordIdentifiers(
    baseline: [ProfileValue],
    current: [ProfileValue],
    dataType: SystemProfilerDataType,
    location: ComparisonRecordLocation
) throws -> [String] {
    let baselineGroups: [String?: [Int]] = Dictionary(grouping: baseline.indices) {
        baseline[$0].preferredName
    }
    let currentGroups: [String?: [Int]] = Dictionary(grouping: current.indices) {
        current[$0].preferredName
    }
    let namedGroups: [String] = Set(baselineGroups.keys.compactMap { $0 })
        .union(currentGroups.keys.compactMap { $0 })
        .sorted()
    let groupNames: [String?] = namedGroups.map { Optional.some($0) } + [nil]
    var identifiers: [String] = current.indices.map { "current:\($0)" }

    for recordName in groupNames {
        try Task.checkCancellation()
        let baselineIndices: [Int] = baselineGroups[recordName] ?? []
        let currentIndices: [Int] = currentGroups[recordName] ?? []

        if recordName != nil && baselineIndices.count <= 1 && currentIndices.count <= 1 {
            if let baselineIndex = baselineIndices.first, let currentIndex = currentIndices.first {
                identifiers[currentIndex] = "record:\(baselineIndex)"
            }
            continue
        }

        // Complete values are Dictionary keys, so hash collisions still require
        // equality. Buckets retain occurrence order; cursors avoid repeated scans
        // and removals while preserving the existing exact-match policy.
        var currentOccurrences: [ProfileValue: [Int]] = [:]
        for currentIndex in currentIndices {
            try Task.checkCancellation()
            currentOccurrences[current[currentIndex], default: []].append(currentIndex)
        }
        var consumedOccurrences: [ProfileValue: Int] = [:]
        var unmatchedCurrentCount: Int = currentIndices.count
        var unmatchedBaselineCount: Int = 0
        for baselineIndex in baselineIndices {
            try Task.checkCancellation()
            let value: ProfileValue = baseline[baselineIndex]
            let consumed: Int = consumedOccurrences[value, default: 0]
            if let occurrences = currentOccurrences[value], consumed < occurrences.count {
                let currentIndex: Int = occurrences[consumed]
                identifiers[currentIndex] = "record:\(baselineIndex)"
                consumedOccurrences[value] = consumed + 1
                unmatchedCurrentCount -= 1
            } else {
                unmatchedBaselineCount += 1
            }
        }

        guard unmatchedBaselineCount == 0 || unmatchedCurrentCount == 0 else {
            switch location {
            case .section:
                throw ReportComparisonError.ambiguousRecords(
                    dataType: dataType,
                    recordName: recordName,
                    baselineCount: baselineIndices.count,
                    currentCount: currentIndices.count
                )
            case let .nested(baselinePath, currentPath):
                throw ReportComparisonError.ambiguousNestedRecords(
                    dataType: dataType,
                    recordName: recordName,
                    baselinePath: baselinePath,
                    currentPath: currentPath,
                    baselineCount: baselineIndices.count,
                    currentCount: currentIndices.count
                )
            }
        }
    }

    return identifiers
}

/// Actual source indices locate evidence; sibling-scoped identities locate matching
/// records. Keeping these maps separate prevents a moved record from acquiring a fake
/// source index, and parent field/record components keep sibling arrays disjoint.
private func comparisonNestedRecordPaths(
    _ records: ComparedReportRecords
) throws -> ComparedNestedRecordPaths {
    let currentRecords: [ComparisonFindingKey: IdentifiedComparisonRecord] = records.current.reduce(into: [:]) {
        result, record in
        result[ComparisonFindingKey(dataType: record.dataType, recordIdentifier: record.identifier, path: [])] = record
    }
    var baselinePaths: [NestedRecordPath: String] = [:]
    var currentPaths: [NestedRecordPath: String] = [:]

    for baselineRecord in records.baseline {
        let key = ComparisonFindingKey(
            dataType: baselineRecord.dataType,
            recordIdentifier: baselineRecord.identifier,
            path: []
        )
        guard let currentRecord = currentRecords[key] else { continue }
        let paths: ComparedNestedRecordPaths = try nestedRecordPaths(
            baseline: baselineRecord.value,
            current: currentRecord.value,
            dataType: baselineRecord.dataType,
            recordIdentifier: baselineRecord.identifier,
            baselinePath: [.index(baselineRecord.recordIndex)],
            currentPath: [.index(currentRecord.recordIndex)]
        )
        for (path, identifier) in paths.baseline { baselinePaths[path] = identifier }
        for (path, identifier) in paths.current { currentPaths[path] = identifier }
    }

    return ComparedNestedRecordPaths(baseline: baselinePaths, current: currentPaths)
}

private func nestedRecordPaths(
    baseline: ProfileValue,
    current: ProfileValue,
    dataType: SystemProfilerDataType,
    recordIdentifier: String,
    baselinePath: [ProfileValuePathComponent],
    currentPath: [ProfileValuePathComponent]
) throws -> ComparedNestedRecordPaths {
    try Task.checkCancellation()
    var baselinePaths: [NestedRecordPath: String] = [:]
    var currentPaths: [NestedRecordPath: String] = [:]

    switch (baseline, current) {
    case let (.object(baselineObject), .object(currentObject)):
        let sharedFields: [String] = Set(baselineObject.keys).intersection(currentObject.keys)
            .filter { $0 != "_name" }.sorted()
        for field in sharedFields {
            guard let baselineValue = baselineObject[field], let currentValue = currentObject[field] else { continue }
            let paths: ComparedNestedRecordPaths = try nestedRecordPaths(
                baseline: baselineValue,
                current: currentValue,
                dataType: dataType,
                recordIdentifier: recordIdentifier,
                baselinePath: baselinePath + [.field(field)],
                currentPath: currentPath + [.field(field)]
            )
            for (path, identifier) in paths.baseline { baselinePaths[path] = identifier }
            for (path, identifier) in paths.current { currentPaths[path] = identifier }
        }
    case let (.array(baselineValues), .array(currentValues)):
        if baselineValues.allSatisfy(isObjectRecord) && currentValues.allSatisfy(isObjectRecord) {
            let identifiers: [String] = try currentComparisonRecordIdentifiers(
                baseline: baselineValues,
                current: currentValues,
                dataType: dataType,
                location: .nested(
                    baselinePath: indexedSourcePath(dataType: dataType, path: baselinePath),
                    currentPath: indexedSourcePath(dataType: dataType, path: currentPath)
                )
            )
            let baselineIndices: [String: Int] = Dictionary(uniqueKeysWithValues: baselineValues.indices.map {
                ("record:\($0)", $0)
            })
            for baselineIndex in baselineValues.indices {
                baselinePaths[NestedRecordPath(
                    dataType: dataType,
                    recordIdentifier: recordIdentifier,
                    sourcePath: baselinePath + [.index(baselineIndex)]
                )] = "record:\(baselineIndex)"
            }
            for currentIndex in currentValues.indices {
                let identifier: String = identifiers[currentIndex]
                let childCurrentPath: [ProfileValuePathComponent] = currentPath + [.index(currentIndex)]
                currentPaths[NestedRecordPath(
                    dataType: dataType,
                    recordIdentifier: recordIdentifier,
                    sourcePath: childCurrentPath
                )] = identifier
                guard let baselineIndex = baselineIndices[identifier] else { continue }
                let paths: ComparedNestedRecordPaths = try nestedRecordPaths(
                    baseline: baselineValues[baselineIndex],
                    current: currentValues[currentIndex],
                    dataType: dataType,
                    recordIdentifier: recordIdentifier,
                    baselinePath: baselinePath + [.index(baselineIndex)],
                    currentPath: childCurrentPath
                )
                for (path, childIdentifier) in paths.baseline { baselinePaths[path] = childIdentifier }
                for (path, childIdentifier) in paths.current { currentPaths[path] = childIdentifier }
            }
        } else {
            for (index, pair) in zip(baselineValues, currentValues).enumerated() {
                let paths: ComparedNestedRecordPaths = try nestedRecordPaths(
                    baseline: pair.0,
                    current: pair.1,
                    dataType: dataType,
                    recordIdentifier: recordIdentifier,
                    baselinePath: baselinePath + [.index(index)],
                    currentPath: currentPath + [.index(index)]
                )
                for (path, identifier) in paths.baseline { baselinePaths[path] = identifier }
                for (path, identifier) in paths.current { currentPaths[path] = identifier }
            }
        }
    default:
        break
    }

    return ComparedNestedRecordPaths(baseline: baselinePaths, current: currentPaths)
}

private func isObjectRecord(_ value: ProfileValue) -> Bool {
    if case .object = value { true } else { false }
}

private func ambiguousRecordDescription(
    dataType: SystemProfilerDataType,
    recordName: String?,
    baselineCount: Int,
    currentCount: Int
) -> String {
    let groupLabel: String = recordName.map { "records named ‘\($0)’" } ?? "unnamed records"
    return "Cannot reliably match \(groupLabel) in \(dataType.title) (\(baselineCount) baseline, \(currentCount) current). Matching by order could report false changes. Review these records directly; no comparison was produced."
}

private func comparableFindings(
    _ records: [IdentifiedComparisonRecord],
    nestedPaths: [NestedRecordPath: String]
) -> [ComparisonFindingKey: ComparableFinding] {
    records.reduce(into: [:]) { reportResult, record in
        let findings: [ComparableFinding] = flattenProfileValue(
            record.value,
            dataType: record.dataType,
            recordIdentifier: record.identifier,
            recordLabel: recordDisplayLabel(record.value, fallback: "Record \(record.recordIndex + 1)"),
            path: [],
            sourcePath: [.index(record.recordIndex)],
            catalogPath: [],
            nestedPaths: nestedPaths
        )

        for finding in findings {
            reportResult[finding.key] = finding
        }
    }
}

private func flattenProfileValue(
    _ value: ProfileValue,
    dataType: SystemProfilerDataType,
    recordIdentifier: String,
    recordLabel: String,
    path: [ComparisonPathComponent],
    sourcePath: [ProfileValuePathComponent],
    catalogPath: [String],
    nestedPaths: [NestedRecordPath: String]
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
                    sourcePath: sourcePath + [.field(field.key)],
                    catalogPath: catalogPath + [field.key],
                    nestedPaths: nestedPaths
                )
            }

    case let .array(values):
        values.enumerated().flatMap { index, child in
            let childSourcePath: [ProfileValuePathComponent] = sourcePath + [.index(index)]
            let childIdentifier: String? = nestedPaths[NestedRecordPath(
                dataType: dataType,
                recordIdentifier: recordIdentifier,
                sourcePath: childSourcePath
            )]
            return flattenProfileValue(
                child,
                dataType: dataType,
                recordIdentifier: recordIdentifier,
                recordLabel: recordLabel,
                path: path + [childIdentifier.map(ComparisonPathComponent.record) ?? .index(index)],
                sourcePath: childSourcePath,
                catalogPath: catalogPath + ["[]"],
                nestedPaths: nestedPaths
            )
        }

    case let .string(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            sourcePath: sourcePath,
            catalogPath: catalogPath,
            value: .string(value)
        )]

    case let .integer(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            sourcePath: sourcePath,
            catalogPath: catalogPath,
            value: .integer(value)
        )]

    case let .decimal(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            sourcePath: sourcePath,
            catalogPath: catalogPath,
            value: .decimal(value)
        )]

    case let .boolean(value):
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            sourcePath: sourcePath,
            catalogPath: catalogPath,
            value: .boolean(value)
        )]

    case .null:
        [comparableFinding(
            dataType: dataType,
            recordIdentifier: recordIdentifier,
            recordLabel: recordLabel,
            path: path,
            sourcePath: sourcePath,
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
    sourcePath: [ProfileValuePathComponent],
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
        address: ProfileValueAddress(dataType: dataType, path: sourcePath),
        value: value
    )
}

private func indexedSourcePath(
    dataType: SystemProfilerDataType,
    path: [ProfileValuePathComponent]
) -> String {
    ProfileValueAddress(dataType: dataType, path: path).sourcePath
}

private func reportChange(
    kind: ReportChangeKind,
    finding: ComparableFinding,
    baselineAddress: ProfileValueAddress?,
    currentAddress: ProfileValueAddress?,
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
        baselineAddress: baselineAddress,
        currentAddress: currentAddress,
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

/// Whether a saved snapshot can be compared with a report: both must cover the same data
/// types, and the snapshot must keep full values.
func snapshotCanBeCompared(_ snapshot: SnapshotSummary, with report: SystemProfilerReport) -> Bool {
    snapshot.privacy == .full
        && snapshot.dataTypes.sorted { $0.rawValue < $1.rawValue } == reportCoverage(report)
}

private func reportCoverage(_ report: SystemProfilerReport) -> [SystemProfilerDataType] {
    report.sections
        .map(\.dataType)
        .sorted { $0.rawValue < $1.rawValue }
}

/// Public comparison errors include only known data-type/status labels, never the
/// diagnostic text or reported values retained in the report itself.
private func incompleteComparisonDescription(
    baseline: [CollectionCoverageEntry],
    current: [CollectionCoverageEntry]
) -> String {
    let reports: [(label: String, entries: [CollectionCoverageEntry])] = [
        ("Baseline", baseline), ("Current", current)
    ]
    let limits: [String] = reports.compactMap { report in
        guard !report.entries.isEmpty else { return nil }
        let entries: String = report.entries.map { entry in
            "\(entry.dataType.title) (\(entry.status.title))"
        }.joined(separator: ", ")
        return "\(report.label): \(entries)."
    }
    return "Comparison stopped because a requested data type was not returned. "
        + limits.joined(separator: " ")
        + " Review Collection coverage and recollect the missing data types, or select complete reports of the same scope. Missing collection is not an added or removed finding; no comparison was produced."
}
