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

    /// Text that search matches for the value: what's shown, the raw value, and for
    /// tokens the full readable form ("Spairport Status Connected"), which the shortened
    /// display leaves out.
    var searchableValueTexts: [String] {
        var texts: [String] = [displayedValue, rawValue]

        if isEnumeratedToken(rawValue) {
            texts.append(displayName(for: rawValue))
        }

        return texts
    }

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
    // Group keys system_profiler names with internal prefixes.
    case "spfirewall_applications": return "App Firewall Rules"
    case "spairport_airport_interfaces": return "Wi-Fi Interfaces"
    case "spairport_current_network_information": return "Current Network"
    case "spairport_airport_other_local_wireless_networks": return "Other Nearby Networks"
    case "sppower_battery_charge_info": return "Charge"
    case "sppower_battery_health_info": return "Health"
    case "sppower_battery_model_info": return "Battery Model"
    case "controller_properties": return "Bluetooth Controller"
    case "device_connected": return "Connected Devices"
    case "device_not_connected": return "Paired Devices, Not Connected"
    case "spnetworklocation_services": return "Services"
    case "spdevtools_sdks": return "SDKs"
    case "spdisplays_ndrvs": return "Displays"
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

    // system_log_description → System Log
    case let .string(value) where value.hasSuffix("_log_description") && isEnumeratedToken(value):
        return friendlyReportGroupName(value)

    case let .string(value) where isEnumeratedToken(value):
        return readableToken(value, field: key)

    case .string, .integer, .decimal, .boolean, .null:
        return scalar.rawDescription
    }
}

/// Matches system_profiler enumeration tokens such as `spairport_status_connected`.
/// Paths, volume names, and identifiers keep their reported spelling.
func isEnumeratedToken(_ value: String) -> Bool {
    value.contains("_") && value.unicodeScalars.allSatisfy { scalar in
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "_"
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
    case "usb": "USB"
    case "gpu": "GPU"
    case "vm": "VM"
    case "wep": "WEP"
    case "wpa": "WPA"
    case "wpa2": "WPA2"
    case "wpa3": "WPA3"
    case "ltr": "LTR"
    case "rtl": "RTL"
    default: word.prefix(1).uppercased() + word.dropFirst()
    }
}

/// Shortens an enumeration token for display. On/off states show their state word
/// (`integrity_enabled` → "Enabled"), and words the value repeats from its field are
/// dropped (`spfirewall_globalstate_limit_connections` → "Limit Connections"). The raw
/// token stays available as the finding's raw value.
func readableToken(_ value: String, field: String) -> String {
    let words: [Substring] = value.split(separator: "_")

    if decodeBooleanLike(value) != nil, let state = words.last {
        return value.lowercased().hasSuffix("not_supported") ? "Not Supported" : displayWord(String(state))
    }

    let fieldWords: [Substring] = field.split(separator: "_")
    var dropped: Int = 0

    while dropped < min(words.count - 1, fieldWords.count), words[dropped] == fieldWords[dropped] {
        dropped += 1
    }

    // The value may repeat the field with a different prefix, as in
    // pairport_security_mode_wpa3_transition under spairport_security_mode.
    if dropped == 0, let lastFieldWord = fieldWords.last,
       let index = words.lastIndex(of: lastFieldWord), index < words.count - 1 {
        dropped = index + 1
    }

    // A leading system_profiler namespace such as "spfirewall" isn't meaningful on its own.
    if dropped == 0, let first = words.first, first.hasPrefix("sp"), first.count > 2, words.count > 1 {
        dropped = 1
    }

    return displayName(for: words.dropFirst(dropped).joined(separator: "_"))
}
