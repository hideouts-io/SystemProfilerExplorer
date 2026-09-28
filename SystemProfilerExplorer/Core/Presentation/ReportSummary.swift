import Foundation

struct ReportSummary: Sendable, Equatable, Codable {
    let recordCount: Int
    let findingCount: Int
    let explainedFindingCount: Int
    let privacyFindingCount: Int
}

func reportSummary(_ report: SystemProfilerReport) -> ReportSummary {
    let recordCount: Int = report.sections.reduce(0) { $0 + $1.items.count }
    let counts: FindingCounts = report.sections.reduce(FindingCounts.zero) { sectionResult, section in
        section.items.reduce(sectionResult) { itemResult, value in
            itemResult + findingCounts(value, dataType: section.dataType, path: [])
        }
    }

    return ReportSummary(
        recordCount: recordCount,
        findingCount: counts.total,
        explainedFindingCount: counts.explained,
        privacyFindingCount: counts.privacy
    )
}

func matchingFindingCount(_ report: SystemProfilerReport, query: FindingQuery) -> Int {
    let context: ValueReportContext = valueReportContext(for: report)

    return report.sections.reduce(0) { sectionResult, section in
        section.items.enumerated().reduce(sectionResult) { itemResult, item in
            itemResult + matchingFindingCount(
                item.element,
                label: recordDisplayLabel(item.element, fallback: "Record \(item.offset + 1)"),
                dataType: section.dataType,
                path: [],
                query: query,
                report: context
            )
        }
    }
}

/// The number of findings whose value is worth a look, shown on each subject tab.
func worthReviewingFindingCount(_ report: SystemProfilerReport) -> Int {
    matchingFindingCount(report, query: FindingQuery(text: "", filter: .worthALook))
}

private struct FindingCounts {
    let total: Int
    let explained: Int
    let privacy: Int

    static let zero = FindingCounts(total: 0, explained: 0, privacy: 0)

    static func + (lhs: FindingCounts, rhs: FindingCounts) -> FindingCounts {
        FindingCounts(
            total: lhs.total + rhs.total,
            explained: lhs.explained + rhs.explained,
            privacy: lhs.privacy + rhs.privacy
        )
    }
}

private func findingCounts(
    _ value: ProfileValue,
    dataType: SystemProfilerDataType,
    path: [String]
) -> FindingCounts {
    switch value {
    case let .object(object):
        object
            .filter { $0.key != "_name" }
            .reduce(FindingCounts.zero) { result, field in
                result + findingCounts(field.value, dataType: dataType, path: path + [field.key])
            }

    case let .array(values):
        values.reduce(FindingCounts.zero) { result, child in
            result + findingCounts(child, dataType: dataType, path: path + ["[]"])
        }

    case let .string(value):
        countsForScalar(.string(value), dataType: dataType, path: path)

    case let .integer(value):
        countsForScalar(.integer(value), dataType: dataType, path: path)

    case let .decimal(value):
        countsForScalar(.decimal(value), dataType: dataType, path: path)

    case let .boolean(value):
        countsForScalar(.boolean(value), dataType: dataType, path: path)

    case .null:
        countsForScalar(.null, dataType: dataType, path: path)
    }
}

private func countsForScalar(
    _ scalar: ProfileScalar,
    dataType: SystemProfilerDataType,
    path: [String]
) -> FindingCounts {
    let presentation: FieldPresentation = fieldPresentation(
        dataType: dataType,
        path: path,
        scalar: scalar
    )

    return FindingCounts(
        total: 1,
        explained: presentation.explanation == nil ? 0 : 1,
        privacy: presentation.explanation?.privacy == nil ? 0 : 1
    )
}
