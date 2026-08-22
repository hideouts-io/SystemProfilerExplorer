import Foundation

enum FindingFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case explained
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .explained: "Explained"
        case .privacy: "Privacy"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
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
    visibleLimit: Int
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
            query: query
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
    query: FindingQuery
) -> Bool {
    matchingFindingCount(
        value,
        label: label,
        dataType: dataType,
        path: path,
        query: query
    ) > 0
}

func matchingFindingCount(
    _ value: ProfileValue,
    label: String,
    dataType: SystemProfilerDataType,
    path: [String],
    query: FindingQuery
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
                    query: descendantQuery
                )
            }

    case let .array(values):
        return values.enumerated().reduce(0) { result, item in
            result + matchingFindingCount(
                item.element,
                label: item.element.preferredName ?? "Item \(item.offset + 1)",
                dataType: dataType,
                path: path + ["[]"],
                query: descendantQuery
            )
        }

    case let .string(value):
        return findingMatches(
            fieldPresentation(dataType: dataType, path: path, scalar: .string(value)),
            query: query
        ) ? 1 : 0

    case let .integer(value):
        return findingMatches(
            fieldPresentation(dataType: dataType, path: path, scalar: .integer(value)),
            query: query
        ) ? 1 : 0

    case let .decimal(value):
        return findingMatches(
            fieldPresentation(dataType: dataType, path: path, scalar: .decimal(value)),
            query: query
        ) ? 1 : 0

    case let .boolean(value):
        return findingMatches(
            fieldPresentation(dataType: dataType, path: path, scalar: .boolean(value)),
            query: query
        ) ? 1 : 0

    case .null:
        return findingMatches(
            fieldPresentation(dataType: dataType, path: path, scalar: .null),
            query: query
        ) ? 1 : 0
    }
}

func queryForDescendants(parentLabel: String, query: FindingQuery) -> FindingQuery {
    guard query.filter == .all,
          !query.normalizedText.isEmpty,
          parentLabel.localizedCaseInsensitiveContains(query.normalizedText) else {
        return query
    }

    return FindingQuery(text: "", filter: .all)
}

private func findingMatches(_ presentation: FieldPresentation, query: FindingQuery) -> Bool {
    guard findingMatchesFilter(presentation, filter: query.filter) else {
        return false
    }

    let searchText: String = query.normalizedText

    guard !searchText.isEmpty else {
        return true
    }

    return findingSearchCorpus(presentation).contains {
        $0.localizedCaseInsensitiveContains(searchText)
    }
}

private func findingMatchesFilter(_ presentation: FieldPresentation, filter: FindingFilter) -> Bool {
    switch filter {
    case .all:
        true
    case .explained:
        presentation.explanation != nil
    case .privacy:
        presentation.explanation?.privacy != nil
    }
}

private func findingSearchCorpus(_ presentation: FieldPresentation) -> [String] {
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

    return values
}
