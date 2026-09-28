import Foundation

/// The app reads two JSON formats: raw `system_profiler -json` output and its own
/// report exports. These helpers accept either, so every picker works with both.

/// Loads a report for viewing. Redacted exports open with their values redacted.
func loadViewableReport(
    from data: Data,
    importedAt: Date,
    parser: SystemProfilerParser = SystemProfilerParser()
) throws -> SystemProfilerReport {
    guard isReportExport(data) else {
        return try parser.parseImportedReport(data, importedAt: importedAt)
    }

    let export: ReportExportEnvelope = try decodeReportExport(data)

    guard !export.report.sections.isEmpty else {
        throw SystemProfilerParsingError.noSupportedDataTypes
    }

    return SystemProfilerReport(
        sections: export.report.sections,
        commandArguments: export.report.commandArguments,
        standardError: export.report.standardError ?? "",
        startedAt: export.report.startedAt ?? importedAt,
        completedAt: export.report.completedAt ?? importedAt
    )
}

/// Loads a report to compare against. Exports must be full, because redacted values
/// can't be compared; raw system_profiler JSON is used as collected.
func loadComparisonBaseline(
    from data: Data,
    importedAt: Date,
    parser: SystemProfilerParser = SystemProfilerParser()
) throws -> SystemProfilerReport {
    guard isReportExport(data) else {
        return try parser.parseImportedReport(data, importedAt: importedAt)
    }

    return try comparisonBaselineReport(from: decodeReportExport(data))
}

private struct ReportExportProbe: Decodable {
    let formatIdentifier: String
}

private func isReportExport(_ data: Data) -> Bool {
    (try? JSONDecoder().decode(ReportExportProbe.self, from: data)) != nil
}

/// The file's modification date, used as the collection time for raw JSON baselines.
func fileModificationDate(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
}
