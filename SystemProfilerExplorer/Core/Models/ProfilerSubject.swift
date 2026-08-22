import Foundation

enum ProfilerSubject: String, CaseIterable, Identifiable, Sendable {
    case overview
    case hardware
    case storage
    case network
    case software
    case security
    case power
    case reports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .hardware: "Hardware"
        case .storage: "Storage"
        case .network: "Network"
        case .software: "Software"
        case .security: "Security"
        case .power: "Power"
        case .reports: "Reports"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .hardware: "cpu"
        case .storage: "internaldrive"
        case .network: "network"
        case .software: "shippingbox"
        case .security: "checkmark.shield"
        case .power: "bolt"
        case .reports: "doc.text.magnifyingglass"
        }
    }

    var summary: String {
        switch self {
        case .overview:
            "A concise picture of this Mac and the most useful findings from every subject."
        case .hardware:
            "Processors, memory, displays, controllers, connected devices, and other physical components."
        case .storage:
            "Physical disks, solid-state media, volumes, file systems, capacity, and storage interfaces."
        case .network:
            "Network interfaces, Wi-Fi, Ethernet, Bluetooth, addresses, and active configurations."
        case .software:
            "macOS details, installed applications, frameworks, extensions, and development tools."
        case .security:
            "Security-related configuration reported by macOS, presented with careful scope limitations."
        case .power:
            "Battery condition, charging state, cycle information, power sources, and energy settings."
        case .reports:
            "A complete scan across every supported system_profiler data type, with collection coverage and source details."
        }
    }
}
