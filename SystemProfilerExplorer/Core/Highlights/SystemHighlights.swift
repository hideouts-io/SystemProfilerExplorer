import Foundation

struct SystemHighlightEvidence: Identifiable, Sendable, Equatable {
    let dataType: SystemProfilerDataType
    let presentation: FieldPresentation

    var id: String { presentation.sourcePath }
}

struct SystemHighlight: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let symbolName: String
    let summary: String
    let interpretationLimit: String
    let evidence: [SystemHighlightEvidence]
}

func systemHighlights(_ report: SystemProfilerReport) -> [SystemHighlight] {
    let evidence: [SystemHighlightEvidence] = flattenedHighlightEvidence(report)
    return [
        startupDiskSecurityHighlight(evidence),
        networkConfigurationHighlight(evidence),
        managementProfileHighlight(evidence),
        batteryPowerHighlight(evidence)
    ].compactMap { $0 }
}

private func startupDiskSecurityHighlight(
    _ evidence: [SystemHighlightEvidence]
) -> SystemHighlight? {
    let startupDiskEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.storage, .hardware],
        terms: ["startup", "boot", "system volume"]
    )
    let securityEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.software, .storage, .firewall, .configurationProfiles],
        terms: ["filevault", "encryption", "encrypted"]
    )

    guard !startupDiskEvidence.isEmpty, !securityEvidence.isEmpty else {
        return nil
    }

    return SystemHighlight(
        id: "startup-disk-security",
        title: "Startup Disk and Encryption Context",
        symbolName: "internaldrive.fill.badge.checkmark",
        summary: "The report includes startup-disk information alongside encryption or FileVault-related fields, so storage and security context can be reviewed together.",
        interpretationLimit: "This connects reported inventory fields only. It does not establish that encryption is currently enforcing protection for every volume or user.",
        evidence: uniqueEvidence(startupDiskEvidence + securityEvidence)
    )
}

private func networkConfigurationHighlight(
    _ evidence: [SystemHighlightEvidence]
) -> SystemHighlight? {
    let interfaceEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.network, .wifi, .ethernet],
        terms: ["interface", "bsd", "device", "hardware address", "ipv4", "ipv6"]
    )
    let configurationEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.network, .wifi, .ethernet, .networkLocation],
        terms: ["vpn", "proxy", "dns", "domain", "router", "service"]
    )

    guard !interfaceEvidence.isEmpty, !configurationEvidence.isEmpty else {
        return nil
    }

    return SystemHighlight(
        id: "network-configuration",
        title: "Interfaces and Network Configuration",
        symbolName: "network",
        summary: "Interface inventory and VPN, proxy, DNS, or network-service fields were collected together. Review their source fields as one connectivity configuration picture.",
        interpretationLimit: "A configured interface, proxy, VPN, or DNS value does not establish an active connection, traffic flow, or remote access session.",
        evidence: uniqueEvidence(interfaceEvidence + configurationEvidence)
    )
}

private func managementProfileHighlight(
    _ evidence: [SystemHighlightEvidence]
) -> SystemHighlight? {
    let profileEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.configurationProfiles],
        terms: ["profile", "payload", "identifier", "organization"]
    )
    let managementEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.managedClient, .configurationProfiles],
        terms: ["managed", "mdm", "enrollment", "supervised"]
    )

    guard !profileEvidence.isEmpty, !managementEvidence.isEmpty else {
        return nil
    }

    return SystemHighlight(
        id: "profiles-management",
        title: "Profiles and Device Management Context",
        symbolName: "checkmark.shield",
        summary: "Configuration-profile fields and device-management indicators are both present, allowing their reported scope and identifiers to be reviewed together.",
        interpretationLimit: "A profile or management-related field can establish configuration or historical inventory, not current administrator activity, control, or compromise.",
        evidence: uniqueEvidence(profileEvidence + managementEvidence)
    )
}

private func batteryPowerHighlight(
    _ evidence: [SystemHighlightEvidence]
) -> SystemHighlight? {
    let batteryHealthEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.power],
        terms: ["cycle", "condition", "health", "maximum capacity", "full charge"]
    )
    let powerSettingEvidence: [SystemHighlightEvidence] = matchingEvidence(
        evidence,
        dataTypes: [.power],
        terms: ["charger", "charging", "sleep", "power", "low power"]
    )

    guard !batteryHealthEvidence.isEmpty, !powerSettingEvidence.isEmpty else {
        return nil
    }

    return SystemHighlight(
        id: "battery-power",
        title: "Battery Health and Power Settings",
        symbolName: "battery.100percent.bolt",
        summary: "Battery-health fields and current power or charging settings are available in one report, which helps distinguish a reported condition from the surrounding power context.",
        interpretationLimit: "This is not a battery diagnosis or a forecast. Reported cycle counts and settings do not independently establish battery performance or failure.",
        evidence: uniqueEvidence(batteryHealthEvidence + powerSettingEvidence)
    )
}

private func flattenedHighlightEvidence(
    _ report: SystemProfilerReport
) -> [SystemHighlightEvidence] {
    report.sections.flatMap { section in
        section.items.flatMap { item in
            flattenedHighlightEvidence(value: item, dataType: section.dataType, path: [])
        }
    }
}

private func flattenedHighlightEvidence(
    value: ProfileValue,
    dataType: SystemProfilerDataType,
    path: [String]
) -> [SystemHighlightEvidence] {
    switch value {
    case let .object(object):
        return object
            .filter { $0.key != "_name" }
            .flatMap { field in
                flattenedHighlightEvidence(
                    value: field.value,
                    dataType: dataType,
                    path: path + [field.key]
                )
            }
    case let .array(values):
        return values.flatMap { item in
            flattenedHighlightEvidence(value: item, dataType: dataType, path: path + ["[]"])
        }
    case let .string(value):
        return [highlightEvidence(dataType: dataType, path: path, scalar: .string(value))]
    case let .integer(value):
        return [highlightEvidence(dataType: dataType, path: path, scalar: .integer(value))]
    case let .decimal(value):
        return [highlightEvidence(dataType: dataType, path: path, scalar: .decimal(value))]
    case let .boolean(value):
        return [highlightEvidence(dataType: dataType, path: path, scalar: .boolean(value))]
    case .null:
        return [highlightEvidence(dataType: dataType, path: path, scalar: .null)]
    }
}

private func highlightEvidence(
    dataType: SystemProfilerDataType,
    path: [String],
    scalar: ProfileScalar
) -> SystemHighlightEvidence {
    SystemHighlightEvidence(
        dataType: dataType,
        presentation: fieldPresentation(dataType: dataType, path: path, scalar: scalar)
    )
}

private func matchingEvidence(
    _ evidence: [SystemHighlightEvidence],
    dataTypes: Set<SystemProfilerDataType>,
    terms: [String]
) -> [SystemHighlightEvidence] {
    evidence.filter { item in
        guard dataTypes.contains(item.dataType) else {
            return false
        }

        let searchCorpus: String = [
            item.presentation.title,
            item.presentation.sourcePath,
            item.presentation.rawValue
        ].joined(separator: "\n").lowercased()
        return terms.contains { searchCorpus.contains($0) }
    }
}

private func uniqueEvidence(
    _ evidence: [SystemHighlightEvidence]
) -> [SystemHighlightEvidence] {
    var seenSourcePaths: Set<String> = []
    return evidence.filter { seenSourcePaths.insert($0.presentation.sourcePath).inserted }
}
