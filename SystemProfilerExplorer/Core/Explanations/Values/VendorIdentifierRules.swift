import Foundation

// A short list of well-known vendor identifiers, so common hardware can be named
// without bundling a full ID database. IDs not listed here are left unexplained.

private let usbVendors: [Int: String] = [
    0x05AC: "Apple",
    0x045E: "Microsoft",
    0x046D: "Logitech",
    0x04E8: "Samsung",
    0x0781: "SanDisk",
    0x0951: "Kingston",
    0x0B95: "ASIX",
    0x0BDA: "Realtek",
    0x0403: "FTDI",
    0x10C4: "Silicon Labs",
    0x1532: "Razer",
    0x18D1: "Google",
    0x1915: "Nordic Semiconductor",
    0x1A86: "QinHeng Electronics (WCH)",
    0x2341: "Arduino",
    0x2E8A: "Raspberry Pi",
    0x303A: "Espressif",
    0x8087: "Intel"
]

private let pciVendors: [Int: String] = [
    0x106B: "Apple",
    0x1002: "AMD",
    0x10DE: "NVIDIA",
    0x10EC: "Realtek",
    0x144D: "Samsung",
    0x14E4: "Broadcom",
    0x8086: "Intel"
]

/// Bluetooth SIG company identifiers.
private let bluetoothCompanies: [Int: String] = [
    0x0002: "Intel",
    0x0006: "Microsoft",
    0x000F: "Broadcom",
    0x004C: "Apple",
    0x0059: "Nordic Semiconductor",
    0x0075: "Samsung",
    0x00E0: "Google"
]

enum VendorIdentifierKind: Sendable {
    case usb
    case pci
    case bluetooth

    var label: String {
        switch self {
        case .usb: "USB vendor ID"
        case .pci: "PCI vendor ID"
        case .bluetooth: "Bluetooth company ID"
        }
    }

    fileprivate var names: [Int: String] {
        switch self {
        case .usb: usbVendors
        case .pci: pciVendors
        case .bluetooth: bluetoothCompanies
        }
    }
}

/// Parses identifiers such as `0x05ac`, `0x004C (Apple)`, or `05AC`.
func hexIdentifier(_ value: String) -> Int? {
    let token: Substring = value
        .trimmingCharacters(in: .whitespaces)
        .split(separator: " ")
        .first ?? ""
    let digits: Substring = token.lowercased().hasPrefix("0x") ? token.dropFirst(2) : token
    return Int(digits, radix: 16)
}

func vendorName(_ value: String, kind: VendorIdentifierKind) -> String? {
    hexIdentifier(value).flatMap { kind.names[$0] }
}

/// Names the vendor behind an ID, preferring a name reported next to it.
func vendorExplanation(_ value: String, kind: VendorIdentifierKind, reportedName: String? = nil) -> ValueExplanation? {
    guard let identifier = hexIdentifier(value) else {
        return nil
    }

    let formattedID: String = "0x" + String(format: "%04X", identifier)

    if let reportedName, !reportedName.isEmpty {
        return .info("Made by \(reportedName) (\(kind.label) \(formattedID)).")
    }

    return kind.names[identifier].map {
        .info("Made by \($0) (\(kind.label) \(formattedID)).", confidence: .documented)
    }
}

let vendorIdentifierValueRules: [ValueRule] = [
    ValueRule(.ethernet, field: "spethernet_vendor-id", unrecognizedValues: .ignore) { context in
        let kind: VendorIdentifierKind = context.sibling("spethernet_bus")?.contains("usb") == true ? .usb : .pci
        return vendorExplanation(context.reportedValue, kind: kind, reportedName: context.sibling("spethernet_vendor_name"))
    },

    ValueRule(.cardReader, field: "spcardreader_vendor-id", unrecognizedValues: .ignore) { context in
        vendorExplanation(context.reportedValue, kind: .pci)
    },

    ValueRule(.cardReader, field: "spcardreader_subsystem_vendor-id", unrecognizedValues: .ignore) { context in
        vendorExplanation(context.reportedValue, kind: .pci)
    }
]
