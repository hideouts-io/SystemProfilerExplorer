import Foundation

let reportExportFormatIdentifier: String = "com.netctl.system-profiler-explorer.report"
let reportExportFormatVersion: Int = 1
let redactedProfileValue: String = "[REDACTED]"

enum ReportExportPrivacy: String, CaseIterable, Identifiable, Sendable, Codable {
    case redacted
    case full

    var id: String { rawValue }
}

struct StoredSystemProfilerReport: Sendable, Equatable, Codable {
    let sections: [SystemProfilerSection]
    let commandArguments: [String]
    let standardError: String?
    let startedAt: Date?
    let completedAt: Date?
}

struct ReportExportEnvelope: Sendable, Equatable, Codable {
    let formatIdentifier: String
    let formatVersion: Int
    let privacy: ReportExportPrivacy
    let summary: ReportSummary
    let redactedValueCount: Int
    let report: StoredSystemProfilerReport
}

enum ReportExportError: LocalizedError, Equatable {
    case invalidFormat(identifier: String)
    case unsupportedVersion(version: Int)
    case importNotSupported

    var errorDescription: String? {
        switch self {
        case let .invalidFormat(identifier):
            "The selected file uses the unexpected report format identifier \(identifier)."
        case let .unsupportedVersion(version):
            "Report format version \(version) is not supported by this build."
        case .importNotSupported:
            "Opening report files is not available yet. Use Export Report to create a new file."
        }
    }
}

func makeFullReportExport(_ report: SystemProfilerReport) -> ReportExportEnvelope {
    ReportExportEnvelope(
        formatIdentifier: reportExportFormatIdentifier,
        formatVersion: reportExportFormatVersion,
        privacy: .full,
        summary: reportSummary(report),
        redactedValueCount: 0,
        report: StoredSystemProfilerReport(
            sections: report.sections,
            commandArguments: report.commandArguments,
            standardError: report.standardError,
            startedAt: report.startedAt,
            completedAt: report.completedAt
        )
    )
}

func makeRedactedReportExport(_ report: SystemProfilerReport) -> ReportExportEnvelope {
    ReportExportEnvelope(
        formatIdentifier: reportExportFormatIdentifier,
        formatVersion: reportExportFormatVersion,
        privacy: .redacted,
        summary: reportSummary(report),
        redactedValueCount: reportScalarCount(report),
        report: StoredSystemProfilerReport(
            sections: report.sections.map { section in
                SystemProfilerSection(
                    dataType: section.dataType,
                    items: section.items.map(redactProfileValue)
                )
            },
            commandArguments: report.commandArguments,
            standardError: nil,
            startedAt: nil,
            completedAt: nil
        )
    )
}

func reportScalarCount(_ report: SystemProfilerReport) -> Int {
    report.sections.reduce(0) { result, section in
        result + section.items.reduce(0) { $0 + profileScalarCount($1) }
    }
}

func encodeReportExport(_ export: ReportExportEnvelope) throws -> Data {
    let encoder: JSONEncoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(export)
}

func decodeReportExport(_ data: Data) throws -> ReportExportEnvelope {
    let decoder: JSONDecoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let export: ReportExportEnvelope = try decoder.decode(ReportExportEnvelope.self, from: data)

    guard export.formatIdentifier == reportExportFormatIdentifier else {
        throw ReportExportError.invalidFormat(identifier: export.formatIdentifier)
    }

    guard export.formatVersion == reportExportFormatVersion else {
        throw ReportExportError.unsupportedVersion(version: export.formatVersion)
    }

    return export
}

func fullReportExportFilename(completedAt: Date) -> String {
    "System-Profiler-Full-\(exportDateDescription(completedAt)).json"
}

func redactedReportExportFilename(completedAt: Date) -> String {
    "System-Profiler-Redacted-\(exportDateDescription(completedAt)).json"
}

private func redactProfileValue(_ value: ProfileValue) -> ProfileValue {
    redactProfileValue(value, keysAreNames: false)
}

/// Some system_profiler dictionaries use names as keys: Bluetooth devices are keyed by
/// device name and firewall rules by app identifier. Those keys are redacted too.
private func redactProfileValue(_ value: ProfileValue, keysAreNames: Bool) -> ProfileValue {
    switch value {
    case let .object(object):
        return .object(redactedObject(object, keysAreNames: keysAreNames))
    case let .array(values):
        return .array(values.map { item in
            redactProfileValue(item, keysAreNames: isSingleNamedEntry(item))
        })
    case .string, .integer, .decimal, .boolean, .null:
        return .string(redactedProfileValue)
    }
}

private func redactedObject(
    _ object: [String: ProfileValue],
    keysAreNames: Bool
) -> [String: ProfileValue] {
    var redacted: [String: ProfileValue] = [:]
    redacted.reserveCapacity(object.count)

    for (position, key) in object.keys.sorted().enumerated() {
        guard let value = object[key] else {
            preconditionFailure("The redacted profiler object changed during traversal.")
        }

        let redactedKey: String = keysAreNames || keyLooksLikeIdentifier(key)
            ? "\(redactedProfileValue) \(position + 1)"
            : key
        redacted[redactedKey] = redactProfileValue(value, keysAreNames: nameKeyedContainers.contains(key))
    }

    return redacted
}

private let nameKeyedContainers: Set<String> = ["spfirewall_applications"]

/// Matches array items shaped like `{ "Device Name": { ...fields } }`.
private func isSingleNamedEntry(_ value: ProfileValue) -> Bool {
    guard case let .object(object) = value,
          object.count == 1,
          case .object? = object.values.first else {
        return false
    }

    return true
}

/// Bundle identifiers, Team ID prefixes, and addresses are never schema keys.
private func keyLooksLikeIdentifier(_ key: String) -> Bool {
    key.contains(".") || key.contains("@")
}

private func profileScalarCount(_ value: ProfileValue) -> Int {
    switch value {
    case let .object(object):
        object.values.reduce(0) { $0 + profileScalarCount($1) }
    case let .array(values):
        values.reduce(0) { $0 + profileScalarCount($1) }
    case .string, .integer, .decimal, .boolean, .null:
        1
    }
}

private func exportDateDescription(_ date: Date) -> String {
    let formatter: DateFormatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd-HHmmss'Z'"
    return formatter.string(from: date)
}
