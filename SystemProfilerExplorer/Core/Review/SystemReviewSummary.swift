import Foundation

struct SystemReviewFinding: Identifiable, Sendable, Equatable {
    let dataType: SystemProfilerDataType
    let recordLabel: String
    let presentation: FieldPresentation
    let location: String

    var id: String { location }

    var coverage: ExplanationCoverage {
        explanationCoverage(for: presentation)
    }
}

func systemReviewFindings(_ report: SystemProfilerReport) -> [SystemReviewFinding] {
    report.sections.flatMap { section in
        section.items.enumerated().flatMap { index, value in
            let recordLabel: String = recordDisplayLabel(value, fallback: "Record \(index + 1)")
            return systemReviewFindings(
                value: value,
                dataType: section.dataType,
                path: [],
                recordIndex: index,
                arrayIndices: [],
                recordLabel: recordLabel
            )
        }
    }
}

func selectedSystemReviewFindings(
    report: SystemProfilerReport,
    selectedSourcePaths: Set<String>
) -> [SystemReviewFinding] {
    systemReviewFindings(report).filter {
        bookmarkMatches(selectedSourcePaths, location: $0.location, sourcePath: $0.presentation.sourcePath)
    }
}

func makeSystemReviewMarkdown(
    report: SystemProfilerReport,
    selectedFindings: [SystemReviewFinding],
    glance: [String] = [],
    worthReviewingItems: [WorthReviewingItem] = []
) -> String {
    let coverage: CollectionCoverage = collectionCoverage(for: report)
    var lines: [String] = [
        "# System Review Summary",
        "",
        "Generated: \(report.completedAt.formatted(date: .long, time: .standard))",
        "",
        "> **Privacy warning:** This document may contain device names, network details, serial identifiers, installed-software information, and other sensitive system data. Review it before sharing.",
        ""
    ]

    if !glance.isEmpty {
        lines += ["## At a Glance", ""] + glance.map { "- \(markdownEscaped($0))" } + [""]
    }

    lines += ["## Worth a Look", ""]

    if worthReviewingItems.isEmpty {
        lines += ["Nothing in this scan needs a look.", ""]
    } else {
        lines += worthReviewingItems.map { item in
            "- **\(markdownEscaped(item.summary))** (\(item.dataType.title) › \(markdownEscaped(item.recordLabel)) › \(markdownEscaped(item.fieldTitle)))"
        }
        lines.append("")
    }

    if !selectedFindings.isEmpty {
        lines += ["## Bookmarked Findings", "", "Bookmarked findings: \(selectedFindings.count)", ""]

        for finding in selectedFindings {
            appendMarkdownFinding(finding, lines: &lines)
        }
    }

    lines += [
        "## Collection Coverage",
        "",
        "- Source: \(coverage.source.title)",
        "- Collected sections: \(coverage.collectedCount)",
        "- Empty sections: \(coverage.emptyCount)",
        "- Skipped sections: \(coverage.skippedCount)",
        ""
    ]

    if !coverage.skippedEntries.isEmpty {
        lines.append("### Skipped Data Types")
        lines.append("")
        lines += coverage.skippedEntries.map { entry in
            "- \(entry.dataType.title) (`\(entry.dataType.rawValue)`)"
        }
        lines.append("")
    }

    lines += [
        "## Collection Limits",
        "",
        collectionLimitText(coverage: coverage),
        "",
        "- A missing, empty, or skipped section does not prove hardware, a service, or a setting is absent.",
        "- Explanations are offline app context. They do not change, verify, or replace the raw `system_profiler` evidence.",
        "- Explanation labels distinguish a curated field explanation, general data-type context, and an unrecognized field.",
        "",
        "## Raw Data",
        "",
        "Raw JSON is deliberately exported separately so this focused review can be shared only after the privacy warning above has been considered.",
        ""
    ]

    return lines.joined(separator: "\n")
}

func systemReviewMarkdownFilename(createdAt: Date) -> String {
    "System-Review-\(systemReviewDateDescription(createdAt)).md"
}

func systemReviewPDFFilename(createdAt: Date) -> String {
    "System-Review-\(systemReviewDateDescription(createdAt)).pdf"
}

private func systemReviewFindings(
    value: ProfileValue,
    dataType: SystemProfilerDataType,
    path: [String],
    recordIndex: Int,
    arrayIndices: [Int],
    recordLabel: String
) -> [SystemReviewFinding] {
    let scalar: ProfileScalar

    switch value {
    case let .object(object):
        return object
            .filter { $0.key != "_name" }
            .sorted { $0.key < $1.key }
            .flatMap { field in
                systemReviewFindings(
                    value: field.value,
                    dataType: dataType,
                    path: path + [field.key],
                    recordIndex: recordIndex,
                    arrayIndices: arrayIndices,
                    recordLabel: recordLabel
                )
            }
    case let .array(values):
        return values.enumerated().flatMap { index, item in
            systemReviewFindings(
                value: item,
                dataType: dataType,
                path: path + ["[]"],
                recordIndex: recordIndex,
                arrayIndices: arrayIndices + [index],
                recordLabel: recordLabel
            )
        }
    case let .string(value): scalar = .string(value)
    case let .integer(value): scalar = .integer(value)
    case let .decimal(value): scalar = .decimal(value)
    case let .boolean(value): scalar = .boolean(value)
    case .null: scalar = .null
    }

    return [
        SystemReviewFinding(
            dataType: dataType,
            recordLabel: recordLabel,
            presentation: fieldPresentation(dataType: dataType, path: path, scalar: scalar),
            location: findingLocation(dataType: dataType, recordIndex: recordIndex, path: path, arrayIndices: arrayIndices)
        )
    ]
}

private func appendMarkdownFinding(
    _ finding: SystemReviewFinding,
    lines: inout [String]
) {
    let presentation: FieldPresentation = finding.presentation
    lines += [
        "### \(markdownEscaped(presentation.title))",
        "",
        "- **Section:** \(markdownEscaped(finding.dataType.title))",
        "- **Record:** \(markdownEscaped(finding.recordLabel))",
        "- **Explanation coverage:** \(finding.coverage.title)",
        "- **Reported value:** \(markdownEscaped(presentation.displayedValue))",
        "- **Raw source location:** `\(presentation.sourcePath)`",
        ""
    ]

    guard let explanation = presentation.explanation else {
        lines += [finding.coverage.detail, ""]
        return
    }

    lines += [
        "**What it means:** \(markdownEscaped(explanation.meaning))",
        "",
        "**Why it matters:** \(markdownEscaped(explanation.significance))",
        "",
        "**Interpret carefully:** \(markdownEscaped(explanation.interpretation))",
        ""
    ]

    if let privacy = explanation.privacy {
        lines += ["**Privacy:** \(markdownEscaped(privacy))", ""]
    }
}

private func collectionLimitText(coverage: CollectionCoverage) -> String {
    switch coverage.source {
    case .liveScan:
        "Live collection status reflects the `system_profiler` command requested for this scan. A skipped data type was requested but did not return a JSON section."
    case .importedReport:
        "The imported JSON does not preserve its original collection command, so coverage can only describe the sections included in the file."
    }
}

private func markdownEscaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\n", with: " ")
}

private func systemReviewDateDescription(_ date: Date) -> String {
    let formatter: DateFormatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd-HHmmss'Z'"
    return formatter.string(from: date)
}
