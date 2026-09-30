import Foundation

/// Plain-language sentences that summarize a report, built only from collected values.
/// Each sentence covers one data type and is omitted when that data wasn't collected.
func reportGlance(_ report: SystemProfilerReport) -> [String] {
    let builders: [(SystemProfilerReport) -> String?] = [
        hardwareGlance,
        softwareGlance,
        storageGlance,
        powerGlance,
        wifiGlance,
        networkServicesGlance,
        bluetoothGlance,
        firewallGlance
    ]

    return builders.compactMap { $0(report) }
}

// MARK: - Sentences

private func hardwareGlance(_ report: SystemProfilerReport) -> String? {
    guard let hardware = records(report, .hardware).first else {
        return nil
    }

    let model: String = text(hardware, "machine_name") ?? "Mac"
    let memory: String? = text(hardware, "physical_memory")
    var chipPhrase: String?

    if let chip = text(hardware, "chip_type") {
        chipPhrase = "has \(indefiniteArticle(for: chip)) \(chip) chip"
    } else if let processor = text(hardware, "cpu_type") {
        chipPhrase = "has \(indefiniteArticle(for: processor)) \(processor) processor"
    }

    if var chipPhrase {
        if let cores = text(hardware, "number_processors").flatMap(processorCoreCounts) {
            chipPhrase += " with \(cores.total) CPU cores (\(cores.performance) performance and \(cores.efficiency) efficiency)"
        }

        return "This \(model) \(chipPhrase)\(memory.map { " and \($0) of memory" } ?? "")."
    }

    return memory.map { "This \(model) has \($0) of memory." }
}

private func softwareGlance(_ report: SystemProfilerReport) -> String? {
    guard let software = records(report, .software).first,
          let version = text(software, "os_version") else {
        return nil
    }

    var sentence: String = "This Mac runs \(version)"

    switch text(software, "system_integrity").flatMap(decodeBooleanLike) {
    case true?: sentence += " with System Integrity Protection on"
    case false?: sentence += " with System Integrity Protection off"
    case nil: break
    }

    if let uptime = text(software, "uptime").flatMap(uptimeReading) {
        sentence += ", and has been running for \(uptime.duration) since the last restart"
    }

    return sentence + "."
}

private func storageGlance(_ report: SystemProfilerReport) -> String? {
    let volumes: [[String: ProfileValue]] = records(report, .storage)

    guard let startup = volumes.first(where: { text($0, "mount_point") == "/System/Volumes/Data" })
            ?? volumes.first(where: { text($0, "mount_point") == "/" }),
          let free = integer(startup, "free_space_in_bytes"),
          let size = integer(startup, "size_in_bytes"),
          size > 0 else {
        return nil
    }

    let fraction: Double = Double(free) / Double(size)
    var sentence: String = "The startup disk has \(formattedByteCount(free)) free of \(formattedByteCount(size)) (\(fraction.formatted(.percent.precision(.fractionLength(0)))))"

    if fraction < lowFreeSpaceFraction {
        sentence += ", which is low"
    }

    switch object(startup, "physical_drive").flatMap({ text($0, "smart_status") })?.lowercased() {
    case "verified"?: sentence += ", and its drive reports no problems"
    case "failing"?: sentence += ", and its drive reports that it is failing"
    default: break
    }

    return sentence + "."
}

private func powerGlance(_ report: SystemProfilerReport) -> String? {
    let items: [[String: ProfileValue]] = records(report, .power)
    let charge: [String: ProfileValue]? = items.lazy.compactMap { object($0, "sppower_battery_charge_info") }.first
    let health: [String: ProfileValue]? = items.lazy.compactMap { object($0, "sppower_battery_health_info") }.first

    guard charge != nil || health != nil else {
        return nil
    }

    var sentences: [String] = []

    if let charge, let percent = text(charge, "sppower_battery_state_of_charge").flatMap(leadingInteger) {
        let charging: Bool? = text(charge, "sppower_battery_is_charging").flatMap(decodeBooleanLike)
        let chargingPhrase: String = charging.map { $0 ? " and charging" : " and not charging" } ?? ""
        sentences.append("The battery was at \(percent)%\(chargingPhrase) when scanned.")
    }

    if let health {
        var details: [String] = []

        if let cycles = text(health, "sppower_battery_cycle_count").flatMap(leadingInteger) {
            details.append("after \(cycles.formatted()) charge \(cycles == 1 ? "cycle" : "cycles")")
        }

        if let capacity = text(health, "sppower_battery_health_maximum_capacity") {
            details.append("with \(capacity) of its original capacity")
        }

        if let condition = text(health, "sppower_battery_health") {
            sentences.append("Its condition is \(condition)\(details.isEmpty ? "" : " " + details.joined(separator: ", ")).")
        }
    }

    return sentences.isEmpty ? nil : sentences.joined(separator: " ")
}

private func wifiGlance(_ report: SystemProfilerReport) -> String? {
    let interfaces: [[String: ProfileValue]] = records(report, .wifi)
        .flatMap { objects($0, "spairport_airport_interfaces") }

    guard let interface = interfaces.first(where: { $0["spairport_status_information"] != nil }),
          let status = text(interface, "spairport_status_information").flatMap({ tokenSuffix($0, after: "status_") }) else {
        return nil
    }

    switch status {
    case "connected":
        var sentence: String = "Wi-Fi is connected"

        if let current = object(interface, "spairport_current_network_information") {
            if let generation = text(current, "spairport_network_phymode").flatMap(wifiGeneration) {
                sentence += " using \(generation)"
            }

            if let band = text(current, "spairport_network_channel").flatMap(wifiBand) {
                sentence += " on the \(band) band"
            }

            if let signal = text(current, "spairport_signal_noise").flatMap(leadingInteger) {
                let quality: String = wifiSignalQuality(signal).quality.lowercased()
                sentence += ", with \(indefiniteArticle(for: quality)) \(quality) signal"
            }
        }

        return sentence + "."
    case "off":
        return "Wi-Fi is turned off."
    default:
        return "Wi-Fi is on but not connected."
    }
}

private func networkServicesGlance(_ report: SystemProfilerReport) -> String? {
    let services: [[String: ProfileValue]] = records(report, .network)

    guard !services.isEmpty else {
        return nil
    }

    let vpnCount: Int = services.filter { text($0, "type")?.hasPrefix("VPN") == true }.count
    let noun: String = services.count == 1 ? "network service is" : "network services are"
    let vpnPhrase: String = vpnCount > 0 ? ", including \(vpnCount) VPN\(vpnCount == 1 ? "" : "s")" : ""

    return "\(services.count) \(noun) set up\(vpnPhrase)."
}

private func bluetoothGlance(_ report: SystemProfilerReport) -> String? {
    guard let bluetooth = records(report, .bluetooth).first else {
        return nil
    }

    let isOn: Bool? = object(bluetooth, "controller_properties")
        .flatMap { text($0, "controller_state") }
        .flatMap(decodeBooleanLike)

    if isOn == false {
        return "Bluetooth is off."
    }

    let connected: Int = objects(bluetooth, "device_connected").count
    let notConnected: Int = objects(bluetooth, "device_not_connected").count

    guard isOn == true || connected + notConnected > 0 else {
        return nil
    }

    var devicePhrases: [String] = []

    if connected > 0 {
        devicePhrases.append("\(connected) \(connected == 1 ? "device" : "devices") connected")
    }

    if notConnected > 0 {
        devicePhrases.append(
            connected > 0
                ? "\(notConnected) more paired but not connected"
                : "\(notConnected) paired \(notConnected == 1 ? "device" : "devices") not connected right now"
        )
    }

    return "Bluetooth is on\(devicePhrases.isEmpty ? "" : ", with " + devicePhrases.joined(separator: " and "))."
}

private func firewallGlance(_ report: SystemProfilerReport) -> String? {
    guard let firewall = records(report, .firewall).first,
          let state = text(firewall, "spfirewall_globalstate").flatMap({ tokenSuffix($0, after: "globalstate_") }) else {
        return nil
    }

    let stealth: Bool? = text(firewall, "spfirewall_stealthenabled").flatMap(decodeBooleanLike)

    switch state {
    case "limit_connections", "block_all":
        return "The firewall is on\(stealth == true ? ", with stealth mode on" : "")."
    case "off", "allow_all":
        return "The firewall is off."
    default:
        return nil
    }
}

// MARK: - Reading report values

private func records(_ report: SystemProfilerReport, _ dataType: SystemProfilerDataType) -> [[String: ProfileValue]] {
    report.sections
        .filter { $0.dataType == dataType }
        .flatMap(\.items)
        .compactMap { item in
            guard case let .object(object) = item else {
                return nil
            }

            return object
        }
}

private func text(_ object: [String: ProfileValue], _ key: String) -> String? {
    switch object[key] {
    case let .string(value)?: value
    case let .integer(value)?: String(value)
    case let .decimal(value)?: String(value)
    case .boolean?, .null?, .object?, .array?, nil: nil
    }
}

private func integer(_ object: [String: ProfileValue], _ key: String) -> Int64? {
    switch object[key] {
    case let .integer(value)?: value
    case let .string(value)?: Int64(value)
    default: nil
    }
}

private func object(_ object: [String: ProfileValue], _ key: String) -> [String: ProfileValue]? {
    guard case let .object(value)? = object[key] else {
        return nil
    }

    return value
}

private func objects(_ object: [String: ProfileValue], _ key: String) -> [[String: ProfileValue]] {
    guard case let .array(values)? = object[key] else {
        return []
    }

    return values.compactMap { value in
        guard case let .object(item) = value else {
            return nil
        }

        return item
    }
}

private func indefiniteArticle(for word: String) -> String {
    guard let first = word.lowercased().first else {
        return "a"
    }

    return "aeiou".contains(first) ? "an" : "a"
}
