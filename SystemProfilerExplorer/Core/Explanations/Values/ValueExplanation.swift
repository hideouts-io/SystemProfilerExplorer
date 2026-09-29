import Foundation

/// How a reported value should be read. Status describes the value, never the whole Mac.
enum ValueStatus: String, CaseIterable, Identifiable, Sendable {
    case normal
    case informational
    case worthReviewing
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .informational: "Info"
        case .worthReviewing: "Worth a look"
        case .unknown: "Not yet explained"
        }
    }

    var symbolName: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .informational: "info.circle.fill"
        case .worthReviewing: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Where a value explanation comes from, so heuristics are never presented as facts.
enum ValueConfidence: Sendable, Equatable {
    /// Apple documentation describes this value.
    case documented
    /// Standard macOS behavior, or a widely used convention the explanation names.
    case observed
    /// An inference from names or patterns. The reasons are shown to the reader.
    case likely(reasons: [String])

    var title: String {
        switch self {
        case .documented: "Documented by Apple"
        case .observed: "Standard behavior"
        case .likely: "Likely"
        }
    }

    var reasons: [String] {
        guard case let .likely(reasons) = self else {
            return []
        }

        return reasons
    }
}

struct ValueExplanation: Sendable, Equatable {
    let summary: String
    let detail: String?
    let status: ValueStatus
    let confidence: ValueConfidence?
    let suggestedAction: String?

    static func normal(
        _ summary: String,
        detail: String? = nil,
        action: String? = nil,
        confidence: ValueConfidence = .observed
    ) -> ValueExplanation {
        ValueExplanation(summary: summary, detail: detail, status: .normal, confidence: confidence, suggestedAction: action)
    }

    static func info(
        _ summary: String,
        detail: String? = nil,
        action: String? = nil,
        confidence: ValueConfidence = .observed
    ) -> ValueExplanation {
        ValueExplanation(summary: summary, detail: detail, status: .informational, confidence: confidence, suggestedAction: action)
    }

    static func review(
        _ summary: String,
        detail: String? = nil,
        action: String? = nil,
        confidence: ValueConfidence = .observed
    ) -> ValueExplanation {
        ValueExplanation(summary: summary, detail: detail, status: .worthReviewing, confidence: confidence, suggestedAction: action)
    }

    static func unexplained(_ reportedValue: String) -> ValueExplanation {
        ValueExplanation(
            summary: "The app doesn't have a specific explanation for the value “\(reportedValue)” yet.",
            detail: "The field explanation below still applies. The value is shown exactly as macOS reported it.",
            status: .unknown,
            confidence: nil,
            suggestedAction: nil
        )
    }
}

/// Facts from other sections of the same report that some rules use for context.
struct ValueReportContext: Sendable, Equatable {
    /// Names of connected USB devices, or nil when the report has no USB section.
    let usbDeviceNames: [String]?
    /// Mount points of the storage volumes in the report.
    var storageMountPoints: [String] = []

    static let empty: ValueReportContext = ValueReportContext(usbDeviceNames: nil)
}

func valueReportContext(for report: SystemProfilerReport) -> ValueReportContext {
    var usbDeviceNames: [String]?

    if let usbSection = report.sections.first(where: { $0.dataType == .usb }) {
        var names: [String] = []
        usbSection.items.forEach { collectDeviceNames($0, into: &names) }
        usbDeviceNames = names
    }

    let mountPoints: [String] = report.sections
        .filter { $0.dataType == .storage }
        .flatMap(\.items)
        .compactMap { item in
            guard case let .object(volume) = item, case let .string(mountPoint)? = volume["mount_point"] else {
                return nil
            }

            return mountPoint
        }

    return ValueReportContext(usbDeviceNames: usbDeviceNames, storageMountPoints: mountPoints)
}

private func collectDeviceNames(_ value: ProfileValue, into names: inout [String]) {
    switch value {
    case let .object(object):
        if case let .string(name)? = object["_name"] {
            names.append(name)
        }

        object.values.forEach { collectDeviceNames($0, into: &names) }
    case let .array(values):
        values.forEach { collectDeviceNames($0, into: &names) }
    case .string, .integer, .decimal, .boolean, .null:
        break
    }
}

struct ValueContext: Sendable {
    let dataType: SystemProfilerDataType
    let path: [String]
    let scalar: ProfileScalar
    /// The other fields of the object that directly contains this value.
    let siblings: [String: ProfileValue]
    let report: ValueReportContext

    var reportedValue: String { scalar.rawDescription }

    /// The field name rules are keyed by. Dictionaries keyed by app identifiers
    /// resolve to their container, so one rule covers every entry.
    var field: String {
        let keys: [String] = path.filter { $0 != "[]" }

        if keys.count >= 2, nameKeyedValueContainers.contains(keys[keys.count - 2]) {
            return keys[keys.count - 2]
        }

        return keys.last ?? ""
    }

    /// The key of the object that contains this field, such as `IPv4` or `AC Power`.
    var parentKey: String? {
        let keys: [String] = path.filter { $0 != "[]" }
        return keys.count >= 2 ? keys[keys.count - 2] : nil
    }

    func sibling(_ key: String) -> String? {
        switch siblings[key] {
        case let .string(value)?: value
        case let .integer(value)?: String(value)
        case let .decimal(value)?: String(value)
        case let .boolean(value)?: value ? "true" : "false"
        case .null?, .object?, .array?, nil: nil
        }
    }

    func nestedSibling(_ key: String, _ nestedKey: String) -> String? {
        guard case let .object(object)? = siblings[key],
              case let .string(value)? = object[nestedKey] else {
            return nil
        }

        return value
    }

    func pathContains(_ key: String) -> Bool {
        path.contains(key)
    }
}

private let nameKeyedValueContainers: Set<String> = ["spfirewall_applications"]

/// What happens when a rule doesn't recognize a value.
enum UnrecognizedValuePolicy: Sendable {
    /// The field has a known set of values, so an unrecognized one is reported as not yet explained.
    case reportAsUnexplained
    /// The rule only applies in some contexts (a numeric reading, a specific kind of volume),
    /// so declining is expected and nothing is shown.
    case ignore
}

struct ValueRule: Sendable {
    let dataTypes: [SystemProfilerDataType]
    let field: String
    let unrecognizedValues: UnrecognizedValuePolicy
    let explain: @Sendable (ValueContext) -> ValueExplanation?

    init(
        _ dataTypes: SystemProfilerDataType...,
        field: String,
        unrecognizedValues: UnrecognizedValuePolicy = .reportAsUnexplained,
        explain: @escaping @Sendable (ValueContext) -> ValueExplanation?
    ) {
        self.dataTypes = dataTypes
        self.field = field
        self.unrecognizedValues = unrecognizedValues
        self.explain = explain
    }
}

private struct ValueRuleKey: Hashable {
    let dataType: SystemProfilerDataType
    let field: String
}

private let valueRuleIndex: [ValueRuleKey: [ValueRule]] = {
    let rules: [ValueRule] = hardwareValueRules + softwareValueRules + softwareArtifactValueRules + firewallValueRules
        + powerValueRules + storageValueRules
        + networkValueRules + ethernetValueRules + wifiValueRules + bluetoothValueRules
        + displayValueRules + audioValueRules + thunderboltValueRules
        + legacySoftwareValueRules + syncServicesValueRules + internationalValueRules + accessibilityValueRules
        + nvmeValueRules + configurationProfileValueRules + printerValueRules
        + vendorIdentifierValueRules + iBridgeValueRules + proxyValueRules
    var index: [ValueRuleKey: [ValueRule]] = [:]

    for rule in rules {
        for dataType in rule.dataTypes {
            index[ValueRuleKey(dataType: dataType, field: rule.field), default: []].append(rule)
        }
    }

    return index
}()

/// Whether any value rule covers this field. Anonymized samples keep these fields'
/// values, since the rules are what the samples exercise.
func hasValueRule(dataType: SystemProfilerDataType, path: [String]) -> Bool {
    let context: ValueContext = ValueContext(dataType: dataType, path: path, scalar: .null, siblings: [:], report: .empty)
    return valueRuleIndex[ValueRuleKey(dataType: dataType, field: context.field)] != nil
}

/// Explains what this reported value means. Returns nil for free text and identifiers,
/// where the field explanation is the whole story, and an honest fallback for
/// enumeration values the catalog doesn't cover yet.
func valueExplanation(for context: ValueContext) -> ValueExplanation? {
    if context.reportedValue == redactedProfileValue {
        return nil
    }

    let rules: [ValueRule] = valueRuleIndex[ValueRuleKey(dataType: context.dataType, field: context.field)] ?? []

    for rule in rules {
        if let explanation = rule.explain(context) {
            return explanation
        }
    }

    let fieldHasKnownValues: Bool = rules.contains { $0.unrecognizedValues == .reportAsUnexplained }

    if fieldHasKnownValues {
        return .unexplained(context.reportedValue)
    }

    if rules.isEmpty,
       case .string = context.scalar,
       isEnumeratedToken(context.reportedValue),
       decodeBooleanLike(context.reportedValue) == nil {
        return .unexplained(context.reportedValue)
    }

    return nil
}

func valueExplanation(
    dataType: SystemProfilerDataType,
    path: [String],
    scalar: ProfileScalar,
    siblings: [String: ProfileValue] = [:],
    report: ValueReportContext = .empty
) -> ValueExplanation? {
    valueExplanation(
        for: ValueContext(
            dataType: dataType,
            path: path,
            scalar: scalar,
            siblings: siblings,
            report: report
        )
    )
}

// MARK: - Shared decoders

/// Decodes the many on/off spellings system_profiler uses: `yes`, `TRUE`, `attrib_on`,
/// `spaudio_yes`, `value_no`, `integrity_enabled`, and so on.
func decodeBooleanLike(_ value: String) -> Bool? {
    let lowercased: String = value.lowercased().replacingOccurrences(of: " ", with: "_")

    if lowercased.hasSuffix("not_supported") || lowercased.hasSuffix("unsupported") {
        return false
    }

    let lastComponent: String = lowercased.split(separator: "_").last.map(String.init) ?? lowercased

    switch lastComponent {
    case "yes", "true", "on", "enabled", "supported", "satisfied":
        return true
    case "no", "false", "off", "disabled":
        return false
    default:
        return nil
    }
}

/// Returns the part of a token after `marker`, so `spairport_security_mode_wpa3_personal`
/// and a misspelled `pairport_security_mode_wpa3_personal` both give `wpa3_personal`.
func tokenSuffix(_ value: String, after marker: String) -> String? {
    guard let range = value.range(of: marker, options: .backwards) else {
        return nil
    }

    let suffix: String = String(value[range.upperBound...])
    return suffix.isEmpty ? nil : suffix
}

func leadingInteger(_ value: String) -> Int? {
    let digits: String = String(value.trimmingCharacters(in: .whitespaces).prefix { $0 == "-" || $0.isNumber })
    return Int(digits)
}

func formattedByteCount(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
