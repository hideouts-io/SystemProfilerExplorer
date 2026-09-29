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

// MARK: - Anonymized samples

let anonymizedSampleRemovedValue: String = "<removed>"
let anonymizedSampleRemovedLog: String = "<log text removed>"

/// An anonymized copy of a report, for sharing as a test sample. It keeps what the
/// app's explanations depend on: field names, numbers, on/off values, enumeration
/// tokens, and the values of fields the app explains. Names, serial numbers,
/// addresses, paths, log text, and other free text are removed. The result has the
/// same shape as `system_profiler -json` output, so the app can open it.
func makeAnonymizedSample(_ report: SystemProfilerReport) -> [String: [ProfileValue]] {
    var sample: [String: [ProfileValue]] = [:]

    for section in report.sections {
        sample[section.dataType.rawValue] = section.items.map { item in
            anonymizedValue(item, dataType: section.dataType, path: [], keysAreNames: false)
        }
    }

    return sample
}

func encodeAnonymizedSample(_ sample: [String: [ProfileValue]]) throws -> Data {
    let encoder: JSONEncoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(sample)
}

/// Names the sample after the Mac model and macOS version, such as
/// `Sample-Mac15,3-macOS-26.0.sample.json`, when the report includes them.
func anonymizedSampleFilename(_ report: SystemProfilerReport) -> String {
    let model: String? = firstRecordText(report, .hardware, "machine_model")
    let version: String? = firstRecordText(report, .software, "os_version").flatMap { text in
        text.range(of: #"\d+(\.\d+)*"#, options: .regularExpression).map { String(text[$0]) }
    }
    let parts: [String] = ["Sample", model, version.map { "macOS-\($0)" }]
        .compactMap { $0 }
        .map { part in String(part.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || ",.-".unicodeScalars.contains($0) }) }
        .filter { !$0.isEmpty }

    return parts.joined(separator: "-") + ".sample.json"
}

private func firstRecordText(_ report: SystemProfilerReport, _ dataType: SystemProfilerDataType, _ key: String) -> String? {
    guard let section = report.sections.first(where: { $0.dataType == dataType }),
          case let .object(record)? = section.items.first,
          case let .string(text)? = record[key] else {
        return nil
    }

    return text
}

private func anonymizedValue(
    _ value: ProfileValue,
    dataType: SystemProfilerDataType,
    path: [String],
    keysAreNames: Bool
) -> ProfileValue {
    switch value {
    case let .object(object):
        var anonymized: [String: ProfileValue] = [:]
        anonymized.reserveCapacity(object.count)

        for (position, key) in object.keys.sorted().enumerated() {
            guard let fieldValue = object[key] else {
                preconditionFailure("The anonymized profiler object changed during traversal.")
            }

            // A key that is already a placeholder stays as it is, so anonymizing a sample
            // again doesn't change it.
            let isName: Bool = (keysAreNames || keyLooksLikeIdentifier(key)) && !isSampleNamePlaceholder(key)
            let sampleKey: String = isName ? "<name \(position + 1)>" : key
            anonymized[sampleKey] = anonymizedValue(
                fieldValue,
                dataType: dataType,
                path: path + [key],
                keysAreNames: nameKeyedContainers.contains(key)
            )
        }

        return .object(anonymized)

    case let .array(values):
        return .array(values.map { item in
            anonymizedValue(item, dataType: dataType, path: path + ["[]"], keysAreNames: isSingleNamedEntry(item))
        })

    case .integer, .decimal, .boolean, .null:
        return value

    case let .string(text):
        return .string(anonymizedText(text, dataType: dataType, path: path))
    }
}

private func isSampleNamePlaceholder(_ key: String) -> Bool {
    key.range(of: #"^<name \d+>$"#, options: .regularExpression) != nil
}

/// Fields that describe the kind of Mac rather than the person who owns it.
private let sampleIdentityFields: Set<String> = [
    "machine_model", "machine_name", "chip_type", "cpu_type", "physical_memory",
    "number_processors", "os_version", "kernel_version", "boot_rom_version", "os_loader_version"
]

private func anonymizedText(_ text: String, dataType: SystemProfilerDataType, path: [String]) -> String {
    let field: String = path.last(where: { $0 != "[]" }) ?? ""

    if (dataType == .logs || dataType == .syncServices) && field == "contents" {
        return anonymizedSampleRemovedLog
    }

    // Record names are kept only when they're tokens the app gives a readable name,
    // such as hardware_overview. Device, network, and volume names are removed.
    if field == "_name" {
        return friendlyReportGroupName(text) != text ? text : anonymizedSampleRemovedValue
    }

    if sampleIdentityFields.contains(field) {
        return text
    }

    if fieldHoldsPersonalValues(field) || textLooksPersonal(text) {
        return anonymizedSampleRemovedValue
    }

    if decodeBooleanLike(text) != nil || isEnumeratedToken(text) || hasValueRule(dataType: dataType, path: path) {
        return text
    }

    return anonymizedSampleRemovedValue
}

private func fieldHoldsPersonalValues(_ field: String) -> Bool {
    let lowercased: String = field.lowercased()

    return ["user_name", "local_host_name", "computer_name", "host_name"].contains(lowercased)
        || ["serial", "uuid", "udid", "mac_address", "ssid", "email"].contains { lowercased.contains($0) }
}

/// Paths, email addresses, and hardware, network, and unique identifiers.
private func textLooksPersonal(_ text: String) -> Bool {
    if text.hasPrefix("/") || text.hasPrefix("~") || text.contains("@") || text.contains("::") {
        return true
    }

    let patterns: [String] = [
        #"([0-9a-f]{2}[:-]){5}[0-9a-f]{2}"#,
        #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#,
        #"(^|[^\d.])\d{1,3}(\.\d{1,3}){3}($|[^\d.])"#,
        #"([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}"#
    ]

    return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
}
