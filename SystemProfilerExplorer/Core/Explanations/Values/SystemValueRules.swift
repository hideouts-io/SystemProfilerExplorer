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
                confidence: .documented
            )
        case false?:
            .review(
                "System Integrity Protection is off.",
                detail: "It is normally turned off only on purpose, for example for kernel or driver development.",
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

let firewallValueRules: [ValueRule] = [
    ValueRule(.firewall, field: "spfirewall_globalstate") { context in
        switch tokenSuffix(context.reportedValue, after: "globalstate_") {
        case "limit_connections":
            .normal(
                "The firewall is on and lets only allowed apps and services accept incoming connections.",
                confidence: .documented
            )
        case "block_all":
            .normal(
                "The firewall is on and blocks all incoming connections except those basic internet services need.",
                confidence: .documented
            )
        case "off":
            .review(
                "The firewall is off, which is the macOS default.",
                detail: "Other devices on the same network can reach services this Mac offers, such as file or screen sharing.",
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
            .info("This app may accept incoming connections from other devices.", confidence: .documented)
        case "block_all":
            .normal("Incoming connections to this app are blocked.", confidence: .documented)
        default:
            nil
        }
    },

    ValueRule(.firewall, field: "spfirewall_stealthenabled") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Stealth mode is on: this Mac doesn't answer probing requests such as ping.",
                confidence: .documented
            )
        case false?:
            .info(
                "Stealth mode is off: this Mac answers some probing requests, such as ping. That's the default.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.firewall, field: "spfirewall_loggingenabled") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info("Firewall logging is on, so blocked connections are recorded in the system log.")
        case false?:
            .info("Firewall logging is off.")
        case nil:
            nil
        }
    }
]
