import Foundation

struct SystemReviewFinding: Identifiable, Sendable, Equatable {
    let dataType: SystemProfilerDataType
    let recordLabel: String
    let presentation: FieldPresentation

    var id: String { presentation.sourcePath }

    var coverage: ExplanationCoverage {
        explanationCoverage(for: presentation)
    }
}

func systemReviewFindings(_ report: SystemProfilerReport) -> [SystemReviewFinding] {
    report.sections.flatMap { section in
        section.items.enumerated().flatMap { index, value in
            let recordLabel: String = value.preferredName ?? "Record \(index + 1)"
            return systemReviewFindings(
                value: value,
                dataType: section.dataType,
                path: [],
                recordLabel: recordLabel
            )
        }
    }
}

func selectedSystemReviewFindings(
    report: SystemProfilerReport,
    selectedSourcePaths: Set<String>
) -> [SystemReviewFinding] {
    systemReviewFindings(report).filter { selectedSourcePaths.contains($0.presentation.sourcePath) }
}

func makeSystemReviewMarkdown(
    report: SystemProfilerReport,
    selectedFindings: [SystemReviewFinding]
) -> String {
    let coverage: CollectionCoverage = collectionCoverage(for: report)
    var lines: [String] = [
        "# System Review Summary",
        "",
        "Generated: \(report.completedAt.formatted(date: .long, time: .standard))",
        "",
        "> **Privacy warning:** This document may contain device names, network details, serial identifiers, installed-software information, and other sensitive system data. Review it before sharing.",
        "",
        "## Selected Findings",
        "",
        "Selected findings: \(selectedFindings.count)",
        ""
    ]

    if selectedFindings.isEmpty {
        lines += [
            "No findings were selected. Bookmark findings in the app before creating a focused review summary.",
            ""
        ]
    } else {
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
    recordLabel: String
) -> [SystemReviewFinding] {
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
                    recordLabel: recordLabel
                )
            }
    case let .array(values):
        return values.flatMap { item in
            systemReviewFindings(
                value: item,
                dataType: dataType,
                path: path + ["[]"],
                recordLabel: recordLabel
            )
        }
    case let .string(value):
        return [systemReviewFinding(dataType: dataType, path: path, scalar: .string(value), recordLabel: recordLabel)]
    case let .integer(value):
        return [systemReviewFinding(dataType: dataType, path: path, scalar: .integer(value), recordLabel: recordLabel)]
    case let .decimal(value):
        return [systemReviewFinding(dataType: dataType, path: path, scalar: .decimal(value), recordLabel: recordLabel)]
    case let .boolean(value):
        return [systemReviewFinding(dataType: dataType, path: path, scalar: .boolean(value), recordLabel: recordLabel)]
    case .null:
        return [systemReviewFinding(dataType: dataType, path: path, scalar: .null, recordLabel: recordLabel)]
    }
}

private func systemReviewFinding(
    dataType: SystemProfilerDataType,
    path: [String],
    scalar: ProfileScalar,
    recordLabel: String
) -> SystemReviewFinding {
    SystemReviewFinding(
        dataType: dataType,
        recordLabel: recordLabel,
        presentation: fieldPresentation(dataType: dataType, path: path, scalar: scalar)
    )
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
