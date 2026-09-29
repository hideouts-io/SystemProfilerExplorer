import Foundation

// MARK: - Legacy software

let legacySoftwareValueRules: [ValueRule] = [
    ValueRule(.legacySoftware, field: "reason") { context in
        let rosettaNote: String = "Apple has said Rosetta 2 remains fully available through macOS 27, and after that only for some older games, so Intel-only apps may stop working in later releases."

        switch tokenSuffix(context.reportedValue, after: "reason_") {
        case "x86_only":
            return .info(
                "Built for Intel Macs only, so it runs through Rosetta 2 translation.",
                detail: rosettaNote,
                action: "Check whether the developer offers a version for Apple silicon.",
                confidence: .documented
            )
        case "x86_forced_environmental":
            return .info(
                "Set to run as Intel code through Rosetta 2, even if it may also support Apple silicon.",
                detail: "This happens when “Open using Rosetta” is selected for the app, or when it's started from a process that runs under Rosetta. \(rosettaNote)",
                action: "If the app supports Apple silicon, turn off “Open using Rosetta” in its Get Info window.",
                confidence: .likely(reasons: [
                    "The value names an Intel (x86) requirement that comes from the environment rather than the app itself."
                ])
            )
        default:
            return nil
        }
    }
]

// MARK: - Sync Services

let syncServicesValueRules: [ValueRule] = [
    // The description names which log the entry holds, such as system_log_description.
    ValueRule(.syncServices, field: "description") { context in
        let value: String = context.reportedValue

        if value == "system_log_description" {
            return .info(
                "This entry is the macOS system log (system.log), included because synchronization problems can leave messages there.",
                detail: "Since macOS Sierra, most messages go to the unified log instead, so this file is often short. It's a retained excerpt, not a complete record of sync activity.",
                confidence: .likely(reasons: [
                    "The value's name says it describes the system log.",
                    "The entry's contents field holds system.log text."
                ])
            )
        }

        guard value.hasSuffix("_log_description"), isEnumeratedToken(value) else {
            return nil
        }

        return .info(
            "This entry holds the \(friendlyReportGroupName(value)).",
            detail: "It's a retained excerpt, not a complete record of sync activity.",
            confidence: .likely(reasons: [
                "The value's name ends in “log description”, the pattern System Information uses to name the log an entry holds."
            ])
        )
    }
]

// MARK: - Sync Services summary

let syncServicesSummaryValueRules: [ValueRule] = [
    // A summary with text is a log excerpt; only the empty summary needs explaining.
    ValueRule(.syncServices, field: "summary_of_sync_log", unrecognizedValues: .ignore) { context in
        guard context.reportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return .normal(
            "No sync log summary was recorded.",
            detail: "That's expected on current macOS, which no longer uses Sync Services to sync contacts, calendars, and bookmarks; iCloud does that instead."
        )
    },

    ValueRule(.syncServices, field: "summary_os_version", unrecognizedValues: .ignore) { context in
        guard let major = leadingInteger(context.reportedValue), major < 11 else {
            return nil
        }

        return .info(
            "This is the Mac OS X version Sync Services was built for, not the macOS on this Mac.",
            detail: "Apple introduced Sync Services in Mac OS X 10.4 and deprecated it in 10.7, so its reporter can show an old version even on current macOS.",
            confidence: .likely(reasons: [
                "Mac OS X \(context.reportedValue) is older than any macOS this app runs on.",
                "The value names a Mac OS X release from the period when Sync Services was current."
            ])
        )
    }
]

// MARK: - Language and region

let internationalValueRules: [ValueRule] = [
    ValueRule(.international, field: "system_text_direction") { context in
        switch tokenSuffix(context.reportedValue, after: "text_direction_") {
        case "ltr": .info("Text reads left to right.")
        case "rtl": .info("Text reads right to left.")
        default: nil
        }
    },

    ValueRule(.international, field: "system_uses_metric_system") { context in
        metricSystemExplanation(context.reportedValue)
    },

    ValueRule(.international, field: "user_uses_metric_system") { context in
        metricSystemExplanation(context.reportedValue)
    },

    ValueRule(.international, field: "system_country", unrecognizedValues: .ignore) { context in
        guard context.reportedValue.count == 2,
              let region = Locale(identifier: "en_US").localizedString(forRegionCode: context.reportedValue) else {
            return nil
        }

        return .info("Region: \(region).")
    },

    ValueRule(.international, field: "user_assistant_voice_gender") { context in
        tokenSuffix(context.reportedValue, after: "voice_gender_").map {
            .info("The assistant's voice is set to a \($0.replacingOccurrences(of: "_", with: " ")) voice.")
        }
    }
]

private func metricSystemExplanation(_ value: String) -> ValueExplanation? {
    switch decodeBooleanLike(value) {
    case true?: .info("Measurements use the metric system.")
    case false?: .info("Measurements don't use the metric system (for example, inches and pounds).")
    case nil: nil
    }
}

// MARK: - Accessibility

let accessibilityValueRules: [ValueRule] = [
    ValueRule(.universalAccess, field: "display") { context in
        switch context.reportedValue {
        case "black_on_white": .info("Normal colors: dark text on a light background.")
        case "white_on_black": .info("Colors are inverted: light text on a dark background.")
        default: nil
        }
    },

    ValueRule(.universalAccess, field: "zoomMode") { context in
        switch tokenSuffix(context.reportedValue, after: "zoom_") {
        case "full_screen": .info("When Zoom is on, it magnifies the whole screen.")
        case "picture_in_picture", "pip": .info("When Zoom is on, it magnifies a separate window that follows the pointer.")
        case "split_screen": .info("When Zoom is on, it magnifies part of the screen in a separate area.")
        default: nil
        }
    }
] + accessibilityFeatureRules([
    ("voiceover", "VoiceOver, the built-in screen reader, is on."),
    ("sticky_keys", "Sticky Keys is on: modifier keys stay active after you press them."),
    ("slow_keys", "Slow Keys is on: a key must be held briefly before it registers."),
    ("mouse_keys", "Mouse Keys is on: the keyboard can move the pointer."),
    ("cursor_mag", "The pointer is enlarged."),
    ("flash_screen", "The screen flashes when an alert sound plays."),
    ("keyboardZoom", "Zoom can be turned on with keyboard shortcuts."),
    ("scrollZoom", "Zoom can be controlled by scrolling with a modifier key.")
])

/// Explains accessibility features only when they're on; "off" is the usual state.
private func accessibilityFeatureRules(_ features: [(field: String, whenOn: String)]) -> [ValueRule] {
    features.map { feature in
        ValueRule(.universalAccess, field: feature.field, unrecognizedValues: .ignore) { context in
            decodeBooleanLike(context.reportedValue) == true ? .info(feature.whenOn, confidence: .documented) : nil
        }
    }
}

// MARK: - NVMe storage

let nvmeValueRules: [ValueRule] = [
    ValueRule(.nvme, field: "spnvme_trim_support", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .normal("TRIM is on, which helps the SSD stay fast over time.", confidence: .documented)
        case false?: .info("TRIM is off, so the SSD can slow down as it fills and empties over time.", confidence: .documented)
        case nil: nil
        }
    },

    ValueRule(.nvme, field: "iocontent") { context in
        switch context.reportedValue {
        case "Apple_APFS":
            .info("An APFS container that holds macOS and your data.", confidence: .documented)
        case "Apple_APFS_ISC":
            .info("The iBoot System Container, which Apple silicon Macs use while starting up.", confidence: .documented)
        case "Apple_APFS_Recovery":
            .info("The container that holds macOS Recovery.", confidence: .documented)
        default:
            nil
        }
    }
]

// MARK: - Configuration profiles

let configurationProfileValueRules: [ValueRule] = [
    ValueRule(.configurationProfiles, field: "spconfigprofile_verification_state") { context in
        switch context.reportedValue.lowercased() {
        case "verified":
            .normal("The profile's signature is verified, so its publisher can be confirmed.", confidence: .documented)
        case "unsigned":
            .info(
                "The profile isn't signed, so its publisher can't be confirmed.",
                detail: "Unsigned profiles are common for ones you create or install yourself. A profile can change security and privacy settings, so it matters that you know where it came from.",
                action: "Keep only profiles you recognize. You can review them by searching for Profiles in System Settings.",
                confidence: .documented
            )
        case "invalid", "unverified":
            .review(
                "The profile's signature couldn't be verified.",
                action: "Remove the profile unless you know where it came from.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.configurationProfiles, field: "spconfigprofile_install_source") { context in
        let value: String = context.reportedValue.lowercased()

        if value == "manual" {
            return .info("Installed by hand, not by an organization's device management.")
        }

        if value.contains("mdm") || value.contains("management") {
            return .info("Installed by an organization's device management (MDM).")
        }

        return nil
    },

    ValueRule(.configurationProfiles, field: "spconfigprofile_RemovalDisallowed", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("This profile can't be removed without the organization that installed it.", confidence: .documented)
        case false?: .info("This profile can be removed.")
        case nil: nil
        }
    }
]

// MARK: - Printers

let printerValueRules: [ValueRule] = [
    ValueRule(.printers, field: "status") { context in
        switch context.reportedValue.lowercased() {
        case "idle": .info("The printer was idle when the scan ran.")
        case "printing", "processing": .info("The printer was printing when the scan ran.")
        case "stopped": .info("The printer queue is paused.", action: "Resume it from the printer's queue window if you want to print.")
        default: nil
        }
    },

    ValueRule(.printers, field: "shared", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true
            ? .info("This printer is shared with other devices on the network.")
            : nil
    },

    ValueRule(.printers, field: "default", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? .info("The default printer.") : nil
    }
]
