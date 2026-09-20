import Foundation

enum ProfileScalar: Sendable, Equatable {
    case string(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case null

    var rawDescription: String {
        switch self {
        case let .string(value): value
        case let .integer(value): String(value)
        case let .decimal(value): String(value)
        case let .boolean(value): value ? "true" : "false"
        case .null: "null"
        }
    }
}

struct FieldPresentation: Sendable, Equatable {
    let dataType: SystemProfilerDataType
    let title: String
    let displayedValue: String
    let rawValue: String
    let sourcePath: String
    let explanation: FieldExplanation?

    var isLogContent: Bool {
        (dataType == .logs || dataType == .syncServices) && sourcePath.hasSuffix(".contents")
    }
}

enum ExplanationCoverage: String, Sendable, Equatable {
    case curatedField
    case generalDataTypeContext
    case unrecognizedField

    var title: String {
        switch self {
        case .curatedField: "Curated explanation"
        case .generalDataTypeContext: "General data-type context"
        case .unrecognizedField: "Unrecognized field"
        }
    }

    var detail: String {
        switch self {
        case .curatedField:
            "This field matches a maintained explanation in the app's catalog. This describes explanation coverage, not a safety verdict."
        case .generalDataTypeContext:
            "This explanation is general context for the reported data type; Apple can add or change individual fields."
        case .unrecognizedField:
            "The value is shown exactly as reported because this field is not recognized by the app's explanation catalog."
        }
    }

    var symbolName: String {
        switch self {
        case .curatedField: "text.book.closed"
        case .generalDataTypeContext: "text.book.closed"
        case .unrecognizedField: "questionmark.circle"
        }
    }
}

func fieldPresentation(
    dataType: SystemProfilerDataType,
    path: [String],
    scalar: ProfileScalar
) -> FieldPresentation {
    let rawValue: String = scalar.rawDescription
    let fieldExplanation: FieldExplanation? = explanation(
        for: dataType,
        path: path,
        reportedValue: rawValue
    )
    let finalKey: String = path.last(where: { $0 != "[]" }) ?? dataType.rawValue

    return FieldPresentation(
        dataType: dataType,
        title: fieldExplanation?.title ?? displayName(for: finalKey),
        displayedValue: (dataType == .logs || dataType == .syncServices) && finalKey == "contents"
            ? rawValue : formattedValue(scalar, path: path),
        rawValue: rawValue,
        sourcePath: ([dataType.rawValue] + path).joined(separator: "."),
        explanation: fieldExplanation
    )
}

func explanationCoverage(for presentation: FieldPresentation) -> ExplanationCoverage {
    guard presentation.explanation != nil else {
        return .unrecognizedField
    }

    switch presentation.dataType {
    case .hardware, .storage, .power, .network, .ethernet, .wifi, .bluetooth,
         .networkLocation, .networkVolumes, .software, .applications, .developerTools,
         .extensions, .frameworks, .fonts, .installHistory, .international,
         .preferencePanes, .printerSoftware, .legacySoftware, .startupItems,
         .syncServices, .firewall, .secureElement, .smartCards,
         .configurationProfiles, .managedClient, .universalAccess:
        return .curatedField
    default:
        return .generalDataTypeContext
    }
}

func displayName(for key: String) -> String {
    switch key {
    case "log_tree_name": return "Diagnostic Logs"
    case "summary_tree_name": return "Overview"
    default: break
    }

    return key
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        .replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .map { displayWord(String($0)) }
        .joined(separator: " ")
}

private func formattedValue(_ scalar: ProfileScalar, path: [String]) -> String {
    let key: String = path.last ?? ""

    switch scalar {
    case let .integer(value) where key.hasSuffix("_in_bytes"):
        let formattedBytes: String = ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
        return "\(formattedBytes) (\(value.formatted()) bytes)"

    case let .string(value) where value == "yes":
        return "Yes"

    case let .string(value) where value == "no":
        return "No"

    case let .string(value) where value.caseInsensitiveCompare("true") == .orderedSame:
        return "Yes"

    case let .string(value) where value.caseInsensitiveCompare("false") == .orderedSame:
        return "No"

    case let .string(value) where key == "medium_type":
        return value.uppercased()

    case let .string(value) where value.contains("_"):
        return displayName(for: value)

    case .string, .integer, .decimal, .boolean, .null:
        return scalar.rawDescription
    }
}

private func displayWord(_ word: String) -> String {
    switch word.lowercased() {
    case "apfs": "APFS"
    case "bsd": "BSD"
    case "os": "OS"
    case "rom": "ROM"
    case "smart": "SMART"
    case "ssd": "SSD"
    case "udid": "UDID"
    case "uuid": "UUID"
    default: word.prefix(1).uppercased() + word.dropFirst()
    }
}
