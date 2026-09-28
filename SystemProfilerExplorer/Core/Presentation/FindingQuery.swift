import Foundation

enum FindingFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case worthALook
    case explained
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .worthALook: "Worth a Look"
        case .explained: "Explained"
        case .privacy: "Privacy"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .worthALook: ValueStatus.worthReviewing.symbolName
        case .explained: "text.book.closed"
        case .privacy: "eye.slash"
        }
    }
}

struct FindingQuery: Sendable, Equatable {
    let text: String
    let filter: FindingFilter

    var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isActive: Bool {
        !normalizedText.isEmpty || filter != .all
    }
}

struct MatchingRecordSelection: Sendable, Equatable {
    let visibleIndices: [Int]
    let matchingCount: Int
}

func matchingRecordSelection(
    items: [ProfileValue],
    dataType: SystemProfilerDataType,
    query: FindingQuery,
    visibleLimit: Int,
    report: ValueReportContext = .empty
) -> MatchingRecordSelection {
    precondition(visibleLimit > 0, "The visible record limit must be greater than zero.")

    guard query.isActive else {
        return MatchingRecordSelection(
            visibleIndices: Array(items.indices.prefix(visibleLimit)),
            matchingCount: items.count
        )
    }

    var visibleIndices: [Int] = []
    var matchingCount: Int = 0

    for (index, value) in items.enumerated() {
        let label: String = value.preferredName ?? "Record \(index + 1)"

        guard profileValueMatches(
            value,
            label: label,
            dataType: dataType,
            path: [],
            query: query,
            report: report
        ) else {
            continue
        }

        matchingCount += 1

        if visibleIndices.count < visibleLimit {
            visibleIndices.append(index)
        }
    }

    return MatchingRecordSelection(
        visibleIndices: visibleIndices,
        matchingCount: matchingCount
    )
}

func profileValueMatches(
    _ value: ProfileValue,
    label: String,
    dataType: SystemProfilerDataType,
    path: [String],
    query: FindingQuery,
    siblings: [String: ProfileValue] = [:],
    report: ValueReportContext = .empty
) -> Bool {
    matchingFindingCount(
        value,
        label: label,
        dataType: dataType,
        path: path,
        query: query,
        siblings: siblings,
        report: report
    ) > 0
}

func matchingFindingCount(
    _ value: ProfileValue,
    label: String,
    dataType: SystemProfilerDataType,
    path: [String],
    query: FindingQuery,
    siblings: [String: ProfileValue] = [:],
    report: ValueReportContext = .empty
) -> Int {
    let descendantQuery: FindingQuery = queryForDescendants(parentLabel: label, query: query)

    switch value {
    case let .object(object):
        return object
            .filter { $0.key != "_name" }
            .reduce(0) { result, field in
                result + matchingFindingCount(
                    field.value,
                    label: displayName(for: field.key),
                    dataType: dataType,
                    path: path + [field.key],
                    query: descendantQuery,
                    siblings: object,
                    report: report
                )
            }

    case let .array(values):
        return values.enumerated().reduce(0) { result, item in
            result + matchingFindingCount(
                item.element,
                label: item.element.preferredName ?? "Item \(item.offset + 1)",
                dataType: dataType,
                path: path + ["[]"],
                query: descendantQuery,
                report: report
            )
        }

    case let .string(value):
        return scalarMatchCount(.string(value), dataType: dataType, path: path, query: query, siblings: siblings, report: report)
    case let .integer(value):
        return scalarMatchCount(.integer(value), dataType: dataType, path: path, query: query, siblings: siblings, report: report)
    case let .decimal(value):
        return scalarMatchCount(.decimal(value), dataType: dataType, path: path, query: query, siblings: siblings, report: report)
    case let .boolean(value):
        return scalarMatchCount(.boolean(value), dataType: dataType, path: path, query: query, siblings: siblings, report: report)
    case .null:
        return scalarMatchCount(.null, dataType: dataType, path: path, query: query, siblings: siblings, report: report)
    }
}

private func scalarMatchCount(
    _ scalar: ProfileScalar,
    dataType: SystemProfilerDataType,
    path: [String],
    query: FindingQuery,
    siblings: [String: ProfileValue],
    report: ValueReportContext
) -> Int {
    let presentation: FieldPresentation = fieldPresentation(dataType: dataType, path: path, scalar: scalar)
    let needsValueExplanation: Bool = query.filter == .worthALook || !query.normalizedText.isEmpty
    let explanation: ValueExplanation? = needsValueExplanation
        ? valueExplanation(dataType: dataType, path: path, scalar: scalar, siblings: siblings, report: report)
        : nil

    return findingMatches(presentation, valueExplanation: explanation, query: query) ? 1 : 0
}

func queryForDescendants(parentLabel: String, query: FindingQuery) -> FindingQuery {
    guard query.filter == .all,
          !query.normalizedText.isEmpty,
          parentLabel.localizedCaseInsensitiveContains(query.normalizedText) else {
        return query
    }

    return FindingQuery(text: "", filter: .all)
}

private func findingMatches(
    _ presentation: FieldPresentation,
    valueExplanation: ValueExplanation?,
    query: FindingQuery
) -> Bool {
    guard findingMatchesFilter(presentation, valueExplanation: valueExplanation, filter: query.filter) else {
        return false
    }

    let searchText: String = query.normalizedText

    guard !searchText.isEmpty else {
        return true
    }

    return findingSearchCorpus(presentation, valueExplanation: valueExplanation).contains {
        $0.localizedCaseInsensitiveContains(searchText)
    }
}

private func findingMatchesFilter(
    _ presentation: FieldPresentation,
    valueExplanation: ValueExplanation?,
    filter: FindingFilter
) -> Bool {
    switch filter {
    case .all:
        true
    case .worthALook:
        valueExplanation?.status == .worthReviewing
    case .explained:
        presentation.explanation != nil
    case .privacy:
        presentation.explanation?.privacy != nil
    }
}

private func findingSearchCorpus(
    _ presentation: FieldPresentation,
    valueExplanation: ValueExplanation?
) -> [String] {
    var values: [String] = [
        presentation.title,
        presentation.displayedValue,
        presentation.rawValue,
        presentation.sourcePath
    ]

    if let explanation = presentation.explanation {
        values.append(explanation.meaning)
        values.append(explanation.significance)
        values.append(explanation.interpretation)

        if let privacy = explanation.privacy {
            values.append(privacy)
        }
    }

    if let valueExplanation {
        values.append(valueExplanation.summary)
    }

    return values
}
