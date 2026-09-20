import Foundation

struct ReportPresentationIndex: Sendable, Equatable {
    let summary: ReportSummary
    fileprivate let sections: [IndexedReportSection]
    fileprivate let explanationSearchCorpora: [String]

    func queryResult(for query: FindingQuery) throws -> ReportQueryResult {
        guard query.isActive else {
            return ReportQueryResult(
                query: query,
                findingCount: summary.findingCount,
                findingCountsByDataType: Dictionary(
                    uniqueKeysWithValues: sections.map { section in
                        (section.dataType, section.findingCount)
                    }
                ),
                matchingRecordIndices: Dictionary(
                    uniqueKeysWithValues: sections.map { section in
                        (section.dataType, section.records.map(\.index))
                    }
                )
            )
        }

        var findingCount: Int = 0
        var matchingRecordIndices: [SystemProfilerDataType: [Int]] = [:]
        var findingCountsByDataType: [SystemProfilerDataType: Int] = [:]
        var inspectedFindingCount: Int = 0

        for section in sections {
            var recordIndices: [Int] = []
            var sectionFindingCount: Int = 0

            for record in section.records {
                var recordFindingCount: Int = 0

                for finding in record.findings {
                    inspectedFindingCount += 1

                    if inspectedFindingCount.isMultiple(of: 256) {
                        try Task.checkCancellation()
                    }

                    guard findingMatches(
                        finding,
                        query: query,
                        explanationSearchCorpora: explanationSearchCorpora
                    ) else {
                        continue
                    }

                    recordFindingCount += 1
                }

                guard recordFindingCount > 0 else {
                    continue
                }

                recordIndices.append(record.index)
                findingCount += recordFindingCount
                sectionFindingCount += recordFindingCount
            }

            matchingRecordIndices[section.dataType] = recordIndices
            findingCountsByDataType[section.dataType] = sectionFindingCount
        }

        return ReportQueryResult(
            query: query,
            findingCount: findingCount,
            findingCountsByDataType: findingCountsByDataType,
            matchingRecordIndices: matchingRecordIndices
        )
    }
}

struct ReportQueryResult: Sendable, Equatable {
    let query: FindingQuery
    let findingCount: Int
    fileprivate let findingCountsByDataType: [SystemProfilerDataType: Int]
    fileprivate let matchingRecordIndices: [SystemProfilerDataType: [Int]]

    func recordSelection(
        for dataType: SystemProfilerDataType,
        visibleLimit: Int
    ) -> MatchingRecordSelection {
        precondition(visibleLimit > 0, "The visible record limit must be greater than zero.")

        let indices: [Int] = matchingRecordIndices[dataType] ?? []

        return MatchingRecordSelection(
            visibleIndices: Array(indices.prefix(visibleLimit)),
            matchingCount: indices.count
        )
    }

    func findingCount(for dataType: SystemProfilerDataType) -> Int {
        findingCountsByDataType[dataType] ?? 0
    }
}

func makeReportPresentationIndex(_ report: SystemProfilerReport) throws -> ReportPresentationIndex {
    var explanationInterner = ExplanationSearchCorpusInterner()
    var indexedSections: [IndexedReportSection] = []
    var recordCount: Int = 0
    var findingCount: Int = 0
    var explainedFindingCount: Int = 0
    var privacyFindingCount: Int = 0
    var indexedValueCount: Int = 0

    for section in report.sections {
        var indexedRecords: [IndexedReportRecord] = []
        recordCount += section.items.count

        for (recordIndex, value) in section.items.enumerated() {
            let recordLabel: String = value.preferredName ?? "Record \(recordIndex + 1)"
            var findings: [IndexedFinding] = []

            try appendIndexedFindings(
                value,
                label: recordLabel,
                dataType: section.dataType,
                path: [],
                ancestorLabels: [],
                indexedValueCount: &indexedValueCount,
                explanationInterner: &explanationInterner,
                findings: &findings
            )

            findingCount += findings.count
            explainedFindingCount += findings.lazy.filter(\.hasExplanation).count
            privacyFindingCount += findings.lazy.filter(\.hasPrivacyGuidance).count
            indexedRecords.append(IndexedReportRecord(index: recordIndex, findings: findings))
        }

        indexedSections.append(
            IndexedReportSection(
                dataType: section.dataType,
                records: indexedRecords,
                findingCount: indexedRecords.reduce(0) { $0 + $1.findings.count }
            )
        )
    }

    return ReportPresentationIndex(
        summary: ReportSummary(
            recordCount: recordCount,
            findingCount: findingCount,
            explainedFindingCount: explainedFindingCount,
            privacyFindingCount: privacyFindingCount
        ),
        sections: indexedSections,
        explanationSearchCorpora: explanationInterner.values
    )
}

fileprivate struct IndexedReportSection: Sendable, Equatable {
    let dataType: SystemProfilerDataType
    let records: [IndexedReportRecord]
    let findingCount: Int
}

fileprivate struct IndexedReportRecord: Sendable, Equatable {
    let index: Int
    let findings: [IndexedFinding]
}

private struct IndexedFinding: Sendable, Equatable {
    let directSearchCorpus: String
    let ancestorLabelSearchCorpus: String
    let explanationSearchCorpusIndex: Int?
    let hasExplanation: Bool
    let hasPrivacyGuidance: Bool
}

private struct ExplanationSearchCorpusInterner {
    private(set) var values: [String] = []
    private var indices: [String: Int] = [:]

    mutating func index(for explanation: FieldExplanation) -> Int {
        let corpus: String = [
            explanation.meaning,
            explanation.significance,
            explanation.interpretation,
            explanation.privacy ?? ""
        ].joined(separator: "\n")

        if let existingIndex = indices[corpus] {
            return existingIndex
        }

        let index: Int = values.count
        values.append(corpus)
        indices[corpus] = index
        return index
    }
}

private func appendIndexedFindings(
    _ value: ProfileValue,
    label: String,
    dataType: SystemProfilerDataType,
    path: [String],
    ancestorLabels: [String],
    indexedValueCount: inout Int,
    explanationInterner: inout ExplanationSearchCorpusInterner,
    findings: inout [IndexedFinding]
) throws {
    indexedValueCount += 1

    if indexedValueCount.isMultiple(of: 256) {
        try Task.checkCancellation()
    }

    let descendantLabels: [String] = ancestorLabels + [label]

    switch value {
    case let .object(object):
        for key in object.keys.sorted() where key != "_name" {
            guard let fieldValue = object[key] else {
                preconditionFailure("The indexed profiler object changed during traversal.")
            }

            try appendIndexedFindings(
                fieldValue,
                label: displayName(for: key),
                dataType: dataType,
                path: path + [key],
                ancestorLabels: descendantLabels,
                indexedValueCount: &indexedValueCount,
                explanationInterner: &explanationInterner,
                findings: &findings
            )
        }

    case let .array(values):
        for (index, item) in values.enumerated() {
            try appendIndexedFindings(
                item,
                label: item.preferredName ?? "Item \(index + 1)",
                dataType: dataType,
                path: path + ["[]"],
                ancestorLabels: descendantLabels,
                indexedValueCount: &indexedValueCount,
                explanationInterner: &explanationInterner,
                findings: &findings
            )
        }

    case let .string(value):
        appendIndexedFinding(
            scalar: .string(value),
            dataType: dataType,
            path: path,
            ancestorLabels: descendantLabels,
            explanationInterner: &explanationInterner,
            findings: &findings
        )

    case let .integer(value):
        appendIndexedFinding(
            scalar: .integer(value),
            dataType: dataType,
            path: path,
            ancestorLabels: descendantLabels,
            explanationInterner: &explanationInterner,
            findings: &findings
        )

    case let .decimal(value):
        appendIndexedFinding(
            scalar: .decimal(value),
            dataType: dataType,
            path: path,
            ancestorLabels: descendantLabels,
            explanationInterner: &explanationInterner,
            findings: &findings
        )

    case let .boolean(value):
        appendIndexedFinding(
            scalar: .boolean(value),
            dataType: dataType,
            path: path,
            ancestorLabels: descendantLabels,
            explanationInterner: &explanationInterner,
            findings: &findings
        )

    case .null:
        appendIndexedFinding(
            scalar: .null,
            dataType: dataType,
            path: path,
            ancestorLabels: descendantLabels,
            explanationInterner: &explanationInterner,
            findings: &findings
        )
    }
}

private func appendIndexedFinding(
    scalar: ProfileScalar,
    dataType: SystemProfilerDataType,
    path: [String],
    ancestorLabels: [String],
    explanationInterner: inout ExplanationSearchCorpusInterner,
    findings: inout [IndexedFinding]
) {
    let presentation: FieldPresentation = fieldPresentation(
        dataType: dataType,
        path: path,
        scalar: scalar
    )
    let explanationIndex: Int? = presentation.explanation.map {
        explanationInterner.index(for: $0)
    }
    let directSearchCorpus: String = [
        presentation.title,
        presentation.displayedValue,
        presentation.rawValue,
        presentation.sourcePath
    ].joined(separator: "\n")
    let ancestorLabelSearchCorpus: String = ancestorLabels
        .dropLast()
        .joined(separator: "\n")

    findings.append(
        IndexedFinding(
            directSearchCorpus: directSearchCorpus,
            ancestorLabelSearchCorpus: ancestorLabelSearchCorpus,
            explanationSearchCorpusIndex: explanationIndex,
            hasExplanation: presentation.explanation != nil,
            hasPrivacyGuidance: presentation.explanation?.privacy != nil
        )
    )
}

private func findingMatches(
    _ finding: IndexedFinding,
    query: FindingQuery,
    explanationSearchCorpora: [String]
) -> Bool {
    switch query.filter {
    case .all:
        break
    case .explained:
        guard finding.hasExplanation else {
            return false
        }
    case .privacy:
        guard finding.hasPrivacyGuidance else {
            return false
        }
    }

    let searchText: String = query.normalizedText

    guard !searchText.isEmpty else {
        return true
    }

    if finding.directSearchCorpus.localizedCaseInsensitiveContains(searchText) {
        return true
    }

    if query.filter == .all,
       finding.ancestorLabelSearchCorpus.localizedCaseInsensitiveContains(searchText) {
        return true
    }

    guard let explanationIndex = finding.explanationSearchCorpusIndex else {
        return false
    }

    return explanationSearchCorpora[explanationIndex]
        .localizedCaseInsensitiveContains(searchText)
}
