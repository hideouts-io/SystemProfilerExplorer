import Foundation

// MARK: - Legacy software

// Sources: reason_x86_only and reason_x86_forced_environmental appear in
// docs/value-inventory.md. Apple's Rosetta plans are in Apple Developer News
// (https://developer.apple.com/news/?id=w5ngl9k2).
let legacySoftwareValueRules: [ValueRule] = [
    ValueRule(.legacySoftware, field: "reason") { context in
        let rosettaNote: String = "Translated apps use more power and can be slower. Apple has said Rosetta 2 remains fully available through macOS 27, and after that only for some older games, so Intel-only apps may stop working in later releases."

        switch tokenSuffix(context.reportedValue, after: "reason_") {
        case "x86_only":
            return .info(
                "Built for Intel Macs only, so it runs through Rosetta 2 translation.",
                detail: "The app contains Intel code only, so on this Mac Rosetta 2 translates it to run on Apple silicon.",
                why: rosettaNote,
                action: "Check whether the developer offers a version for Apple silicon.",
                confidence: .documented
            )
        case "x86_forced_environmental":
            return .info(
                "Set to run as Intel code through Rosetta 2, even if it may also support Apple silicon.",
                detail: "This happens when “Open using Rosetta” is selected for the app, or when it's started from a process that runs under Rosetta.",
                why: rosettaNote,
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

// Sources: spnvme_trim_support and spsata_trim_support are keys in Apple's SPNVMeReporter
// and SPSerialATAReporter strings; Yes is seen in docs/value-inventory.md. The iocontent
// values Apple_APFS, Apple_APFS_ISC, and Apple_APFS_Recovery are seen in the inventory;
// the other partition types are the names `diskutil list` shows, and are unconfirmed in
// system_profiler output. The Apple silicon containers are described in Apple Platform
// Security ("Boot process for a Mac with Apple silicon").

let nvmeValueRules: [ValueRule] = [
    ValueRule(.nvme, field: "spnvme_trim_support", unrecognizedValues: .ignore) { context in
        trimExplanation(context.reportedValue)
    },

    ValueRule(.serialATA, field: "spsata_trim_support", unrecognizedValues: .ignore) { context in
        trimExplanation(context.reportedValue)
    },

    ValueRule(.nvme, field: "iocontent") { context in
        partitionContentExplanation(context.reportedValue)
    }
]

private func trimExplanation(_ value: String) -> ValueExplanation? {
    switch decodeBooleanLike(value) {
    case true?:
        .normal(
            "TRIM is on, which helps the SSD stay fast over time.",
            detail: "macOS tells the SSD which blocks are no longer in use, so it can clear them ahead of time.",
            why: "Without TRIM, an SSD slows down as it fills and empties.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case false?:
        .info(
            "TRIM is off, so the SSD can slow down as it fills and empties over time.",
            detail: "macOS turns TRIM on for Apple SSDs automatically. Third-party SSDs need it turned on with the trimforce command.",
            why: "Writing to the SSD can get slower as it fills up. It doesn't matter for hard drives.",
            action: "If this is a third-party SSD, check its maker's advice about TRIM on a Mac.",
            confidence: .documented
        )
    case nil:
        nil
    }
}

private func partitionContentExplanation(_ value: String) -> ValueExplanation? {
    switch value {
    case "Apple_APFS":
        .info(
            "An APFS container that holds macOS and your data.",
            detail: "The container holds the system, data, and other APFS volumes, which share its space.",
            why: "It's the main part of the startup disk.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "Apple_APFS_ISC":
        .info(
            "The iBoot System Container, which Apple silicon Macs use while starting up.",
            detail: "It holds startup files and security policies used before macOS loads.",
            why: "The Mac needs it to start up. macOS manages it; don't change or erase it.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "Apple_APFS_Recovery":
        .info(
            "The container that holds macOS Recovery.",
            detail: "On Apple silicon Macs, this separate container holds the recovery system.",
            why: "You need it to reinstall macOS or repair the disk when macOS won't start.",
            action: "Nothing to do. Don't erase it.",
            confidence: .documented
        )
    case "EFI":
        .info(
            "The EFI system partition, used by the Mac's firmware.",
            detail: "It's a small partition on GUID-formatted disks that firmware uses while starting up.",
            why: "macOS manages it, and it's usually hidden.",
            action: "Nothing to do.",
            confidence: .observed
        )
    case "Apple_HFS":
        .info(
            "A Mac OS Extended (HFS+) partition.",
            detail: "The partition holds a volume in Mac OS Extended format.",
            why: "It's common on older or backup drives. A Mac with Apple silicon can't start up from it.",
            action: "Nothing to do.",
            confidence: .observed
        )
    case "Apple_Boot":
        .info(
            "A small helper partition used to start up Intel Macs.",
            detail: "Intel Macs use it for recovery or to start up from encrypted or Fusion drives.",
            why: "macOS manages it, and it's usually hidden.",
            action: "Nothing to do.",
            confidence: .observed
        )
    case "Apple_CoreStorage":
        .info(
            "A Core Storage partition, used by older Fusion Drives and FileVault setups.",
            detail: "Core Storage was the volume manager before APFS.",
            why: "It usually means the disk was set up by an older version of macOS.",
            action: "Nothing to do.",
            confidence: .observed
        )
    case "Microsoft Basic Data":
        .info(
            "A partition formatted for Windows or for sharing, such as exFAT, FAT32, or NTFS.",
            detail: "This partition type is used for Windows volumes and for exFAT and FAT32 drives.",
            why: "It can be shared with Windows PCs. macOS can't write to NTFS volumes.",
            action: "Nothing to do.",
            confidence: .observed
        )
    default:
        nil
    }
}

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
