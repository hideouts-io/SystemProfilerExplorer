import Foundation

// MARK: - Hardware

let hardwareValueRules: [ValueRule] = [
    ValueRule(.hardware, field: "number_processors") { context in
        processorCountExplanation(context.reportedValue)
    },

    ValueRule(.hardware, field: "activation_lock_status") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Activation Lock is on, so erasing and reactivating this Mac requires the owner's Apple Account.",
                confidence: .documented
            )
        case false?:
            .info(
                "Activation Lock is off. It turns on with Find My, and is often off on managed, repaired, or resold Macs.",
                action: "To protect this Mac if it's lost, turn on Find My in System Settings.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.hardware, field: "physical_memory", unrecognizedValues: .ignore) { context in
        guard context.sibling("chip_type")?.hasPrefix("Apple") == true else {
            return nil
        }

        return .info(
            "\(context.reportedValue) of unified memory, shared by the CPU and GPU.",
            detail: "On Apple silicon, memory is part of the chip package and can't be upgraded later.",
            confidence: .documented
        )
    }
]

struct ProcessorCoreCounts: Sendable, Equatable {
    let total: Int
    let performance: Int
    let efficiency: Int
    /// The value included a 0 group, such as the 0 in `proc 14:0:10:4`.
    let hasUnusedGroup: Bool
}

/// Decodes values such as `proc 14:10:4` or `proc 14:0:10:4` into performance and
/// efficiency cores. Returns nil unless the groups add up to the total.
func processorCoreCounts(_ value: String) -> ProcessorCoreCounts? {
    let numbers: [Int] = value
        .split(whereSeparator: { !$0.isNumber })
        .compactMap { Int($0) }

    guard let total = numbers.first, numbers.count >= 3 else {
        return nil
    }

    let groups: [Int] = numbers.dropFirst().filter { $0 > 0 }

    guard groups.count == 2, groups.reduce(0, +) == total else {
        return nil
    }

    return ProcessorCoreCounts(
        total: total,
        performance: groups[0],
        efficiency: groups[1],
        hasUnusedGroup: numbers.dropFirst().contains(0)
    )
}

func processorCountExplanation(_ value: String) -> ValueExplanation? {
    guard let cores = processorCoreCounts(value) else {
        return nil
    }

    var reasons: [String] = [
        "The numbers after the total add up to it (\(cores.performance) + \(cores.efficiency) = \(cores.total)).",
        "Apple silicon chips combine performance and efficiency cores, and system_profiler lists performance cores first."
    ]

    if cores.hasUnusedGroup {
        reasons.append("The 0 in the value isn't documented; it appears to be an unused core group.")
    }

    return .info(
        "\(cores.total) CPU cores: \(cores.performance) performance and \(cores.efficiency) efficiency.",
        detail: "Performance cores run demanding work; efficiency cores handle background tasks using less power.",
        confidence: .likely(reasons: reasons)
    )
}

// MARK: - Software

let softwareValueRules: [ValueRule] = [
    ValueRule(.software, field: "system_integrity") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "System Integrity Protection is on, which is the default.",
                detail: "It stops any software, even with administrator rights, from changing protected parts of macOS.",
                why: "Malware that gets administrator rights still can't modify macOS itself or the apps and files it protects.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .review(
                "System Integrity Protection is off.",
                detail: "Software with administrator rights can change protected parts of macOS on this Mac. It is normally turned off only on purpose, for example for kernel or driver development.",
                why: "Without it, malware or a faulty installer that gets administrator rights can modify macOS itself.",
                action: "If you didn't turn it off deliberately, start up in macOS Recovery and run csrutil enable in Terminal.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.software, field: "secure_vm") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal("Secure virtual memory is on: data macOS moves from memory to disk is encrypted.")
        case false?:
            .review("Secure virtual memory is off, so data macOS moves from memory to disk isn't encrypted.")
        case nil:
            nil
        }
    },

    ValueRule(.software, field: "boot_mode") { context in
        let value: String = context.reportedValue.lowercased()

        if value == "normal_boot" {
            return .normal("This Mac started up normally.")
        }

        if value.contains("safe") {
            return .info(
                "This Mac started up in Safe Mode, which loads only essential software.",
                action: "Restart normally when you've finished troubleshooting.",
                confidence: .documented
            )
        }

        return nil
    },

    ValueRule(.software, field: "uptime") { context in
        uptimeExplanation(context.reportedValue)
    }
]

struct UptimeReading: Sendable, Equatable {
    let days: Int
    /// A readable duration such as "2 days 3 hours" or "1 hour 17 minutes".
    let duration: String
}

/// Decodes `up days:hours:minutes:seconds`, the format system_profiler uses.
func uptimeReading(_ value: String) -> UptimeReading? {
    guard value.hasPrefix("up ") else {
        return nil
    }

    let parts: [Int] = value.dropFirst(3).split(separator: ":").compactMap { Int($0) }

    guard parts.count == 4 else {
        return nil
    }

    let (days, hours, minutes): (Int, Int, Int) = (parts[0], parts[1], parts[2])
    var components: [String] = []

    if days > 0 { components.append("\(days) \(days == 1 ? "day" : "days")") }
    if hours > 0 { components.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
    if days == 0, minutes > 0 { components.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }

    return UptimeReading(
        days: days,
        duration: components.isEmpty ? "less than a minute" : components.joined(separator: " ")
    )
}

func uptimeExplanation(_ value: String) -> ValueExplanation? {
    guard let uptime = uptimeReading(value) else {
        return nil
    }

    let summary: String = "Running for \(uptime.duration) since the last restart."

    if uptime.days >= 30 {
        return .info(
            summary,
            action: "Restarting now and then installs pending updates and clears temporary problems."
        )
    }

    return .normal(summary)
}

// MARK: - Firewall

// Sources: global states and per-app states are keys in Apple's SPFirewallReporter
// strings (spfirewall_globalstate_limit_connections, _block_all, _allow_all;
// spfirewall_allow_all, spfirewall_block_all, spfirewall_allow_local). Apple's
// firewall settings are described in https://support.apple.com/guide/mac-help/mh34041.
// spfirewall_globalstate_off is unconfirmed; older macOS reported the firewall being
// off as allow_all ("Allow all incoming connections").

let firewallValueRules: [ValueRule] = [
    ValueRule(.firewall, field: "spfirewall_globalstate") { context in
        switch tokenSuffix(context.reportedValue, after: "globalstate_") {
        case "limit_connections":
            .normal(
                "The firewall is on and lets only allowed apps and services accept incoming connections.",
                detail: "Incoming connections are blocked unless the app or service receiving them is allowed, by you or automatically because it's signed.",
                why: "Other devices on the network can't reach services on this Mac unless they're allowed.",
                action: "Nothing to do. Review the allowed apps in System Settings › Network › Firewall › Options.",
                confidence: .documented
            )
        case "block_all":
            .normal(
                "The firewall is on and blocks all incoming connections except those basic internet services need.",
                detail: "Only basic services, such as getting a network address, can receive incoming connections. Sharing services can't.",
                why: "It's the strictest setting. It also stops features like screen sharing, file sharing, and AirPlay to this Mac.",
                action: "Nothing to do, unless a sharing feature you use stops working.",
                confidence: .documented
            )
        case "off", "allow_all":
            .review(
                "The firewall is off, which is the macOS default.",
                detail: "Other devices on the same network can reach services this Mac offers, such as file or screen sharing.",
                why: "Any sharing service that's turned on can be reached by every device on the same network, including public Wi-Fi.",
                action: "Turn it on in System Settings › Network › Firewall, especially if you use public Wi-Fi.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.firewall, field: "spfirewall_applications") { context in
        switch tokenSuffix(context.reportedValue, after: "spfirewall_") {
        case "allow_all":
            .info(
                "This app may accept incoming connections from other devices.",
                detail: "When the firewall is on, it lets other devices connect to this app.",
                why: "An app that accepts connections can be reached from the network, so it should be one you trust.",
                action: "If you don't recognize the app, set it to block incoming connections in Firewall Options.",
                confidence: .documented
            )
        case "block_all":
            .normal(
                "Incoming connections to this app are blocked.",
                detail: "The firewall stops other devices from connecting to this app.",
                why: "The app can still connect out, but features that need incoming connections, such as sharing, won't work.",
                action: "Nothing to do unless one of this app's features needs incoming connections.",
                confidence: .documented
            )
        case "allow_local":
            .info(
                "Only devices on the local network may connect to this app.",
                detail: "Connections from the same local network are allowed, and others are blocked.",
                why: "Devices on your network can reach it, but devices elsewhere on the internet can't.",
                action: "Nothing to do if you trust the networks you use.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.firewall, field: "spfirewall_stealthenabled") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Stealth mode is on: this Mac doesn't answer probing requests such as ping.",
                detail: "The Mac ignores ping and doesn't reply to connection attempts on closed ports.",
                why: "It makes the Mac harder to find with network scans, especially on public networks.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Stealth mode is off: this Mac answers some probing requests, such as ping. That's the default.",
                detail: "The Mac answers ping and reports closed ports, as most computers do.",
                why: "Other devices on the network can discover the Mac more easily.",
                action: "On public networks, you can turn on stealth mode in System Settings › Network › Firewall › Options.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.firewall, field: "spfirewall_loggingenabled") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Firewall logging is on, so blocked connections are recorded in the system log.",
                detail: "Each connection the firewall blocks is written to the log.",
                why: "The log helps find out why a connection to this Mac didn't work.",
                action: "Nothing to do."
            )
        case false?:
            .info(
                "Firewall logging is off.",
                detail: "Connections the firewall blocks aren't recorded.",
                why: "There's no record to check if a connection is blocked unexpectedly.",
                action: "Nothing to do."
            )
        case nil:
            nil
        }
    }
]
