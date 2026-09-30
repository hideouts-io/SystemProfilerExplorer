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
        let why: String = "It can help diagnose problems with syncing contacts, calendars, and other data."
        let action: String = "Nothing to do unless something isn't syncing. Then the log can help Apple Support or your IT team."

        if value == "system_log_description" {
            return .info(
                "This entry is the macOS system log (system.log), included because synchronization problems can leave messages there.",
                detail: "Since macOS Sierra, most messages go to the unified log instead, so this file is often short. It's a retained excerpt, not a complete record of sync activity.",
                why: why,
                action: action,
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
            why: why,
            action: action,
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

// Sources: text_direction_ltr, value_no, and US are seen in docs/value-inventory.md. The
// keys text_direction_ltr and _rtl, value_yes and _no, voice_gender_female and _male,
// Celsius and Fahrenheit, and the calendar identifiers (gregorian, buddhist, chinese,
// coptic, ethiopic, ethiopic-amete-alem, hebrew, indian, islamic, islamic-civil,
// islamic-tbla, islamic-umalqura, iso8601, japanese, persian, roc) are in Apple's
// SPInternationalReporter strings. The inventory withheld this Mac's user_calendar,
// user_temperature_unit, and voice gender values.

let internationalValueRules: [ValueRule] = [
    ValueRule(.international, field: "system_text_direction") { context in
        textDirectionExplanation(context.reportedValue)
    },

    ValueRule(.international, field: "user_text_direction") { context in
        textDirectionExplanation(context.reportedValue)
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

        return .info(
            "Region: \(region).",
            detail: "This is the region macOS uses for formats and region-specific features.",
            why: "It sets the default date, time, and number formats and which services are offered.",
            action: "Nothing to do. You can change it in System Settings › General › Language & Region.",
            confidence: .documented
        )
    },

    ValueRule(.international, field: "user_assistant_voice_gender") { context in
        tokenSuffix(context.reportedValue, after: "voice_gender_").map { gender in
            .info(
                "The assistant's voice is set to a \(gender.replacingOccurrences(of: "_", with: " ")) voice.",
                detail: "This is the voice Siri speaks with.",
                why: "It only changes how Siri sounds.",
                action: "Nothing to do. You can change it in System Settings › Siri.",
                confidence: .documented
            )
        }
    },

    ValueRule(.international, field: "user_temperature_unit") { context in
        switch context.reportedValue.lowercased() {
        case "celsius", "fahrenheit":
            .info(
                "Temperatures are shown in \(context.reportedValue.prefix(1).uppercased() + context.reportedValue.dropFirst().lowercased()).",
                detail: "Weather and other apps show temperatures in this unit.",
                why: "It only changes how temperatures are displayed.",
                action: "Nothing to do. You can change it in System Settings › General › Language & Region.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.international, field: "user_calendar") { context in
        calendarExplanation(context.reportedValue)
    }
]

private func textDirectionExplanation(_ value: String) -> ValueExplanation? {
    switch tokenSuffix(value, after: "text_direction_") {
    case "ltr":
        .info(
            "Text reads left to right.",
            detail: "The language in use is written from left to right, as English is.",
            why: "It sets the direction of text and the layout of windows and menus.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "rtl":
        .info(
            "Text reads right to left.",
            detail: "The language in use is written from right to left, as Arabic and Hebrew are.",
            why: "Windows and menus are laid out mirrored to match.",
            action: "Nothing to do.",
            confidence: .documented
        )
    default:
        nil
    }
}

private func metricSystemExplanation(_ value: String) -> ValueExplanation? {
    switch decodeBooleanLike(value) {
    case true?:
        .info(
            "Measurements use the metric system.",
            detail: "Apps show lengths, weights, and volumes in metric units such as centimeters and kilograms.",
            why: "It only changes how measurements are displayed.",
            action: "Nothing to do. You can change it in System Settings › General › Language & Region.",
            confidence: .documented
        )
    case false?:
        .info(
            "Measurements don't use the metric system (for example, inches and pounds).",
            detail: "Apps show lengths, weights, and volumes in US or imperial units.",
            why: "It only changes how measurements are displayed.",
            action: "Nothing to do. You can change it in System Settings › General › Language & Region.",
            confidence: .documented
        )
    case nil:
        nil
    }
}

private func calendarExplanation(_ value: String) -> ValueExplanation? {
    let names: [String: String] = [
        "gregorian": "Gregorian",
        "buddhist": "Buddhist",
        "chinese": "Chinese",
        "coptic": "Coptic",
        "ethiopic": "Ethiopic",
        "ethiopic-amete-alem": "Ethiopic (Amete Alem)",
        "hebrew": "Hebrew",
        "indian": "Indian National",
        "islamic": "Islamic (Astronomical)",
        "islamic-civil": "Islamic (Tabular, Friday origin)",
        "islamic-tbla": "Islamic (Tabular, Thursday origin)",
        "islamic-umalqura": "Islamic (Umm al-Qura)",
        "iso8601": "ISO 8601",
        "japanese": "Japanese",
        "persian": "Persian",
        "roc": "Minguo (Republic of China)"
    ]

    guard let name = names[value.lowercased()] else {
        return nil
    }

    return .info(
        "Dates use the \(name) calendar.",
        detail: value.lowercased() == "gregorian"
            ? "The Gregorian calendar is the one most countries use."
            : "Dates across macOS are shown in this calendar system instead of the Gregorian calendar.",
        why: "It changes how dates and years are shown in apps, not the dates themselves.",
        action: "Nothing to do. You can change it in System Settings › General › Language & Region.",
        confidence: .documented
    )
}

// MARK: - Accessibility

// Sources: black_on_white, zoom_full_screen, and off are seen in
// docs/value-inventory.md. black_on_white, white_on_black, zoom_full_screen,
// zoom_split_screen, zoom_in_window, on, and off are keys in Apple's
// SPUniversalAccessReporter strings. zoom_picture_in_picture and zoom_pip are
// unconfirmed. The inventory withheld this Mac's contrast value.

let accessibilityValueRules: [ValueRule] = [
    ValueRule(.universalAccess, field: "display") { context in
        switch context.reportedValue {
        case "black_on_white":
            .info(
                "Normal colors: dark text on a light background.",
                detail: "Invert Colors is off.",
                why: "The screen shows colors as apps intend.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "white_on_black":
            .info(
                "Colors are inverted: light text on a dark background.",
                detail: "Invert Colors is on in Accessibility › Display.",
                why: "It can make text easier to read, but photos and videos look inverted too.",
                action: "Nothing to do if you use it. You can turn it off in System Settings › Accessibility › Display.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.universalAccess, field: "zoomMode") { context in
        let action: String = "Nothing to do. You can change the zoom style in System Settings › Accessibility › Zoom."
        let why: String = "It only matters when Zoom is on."

        return switch tokenSuffix(context.reportedValue, after: "zoom_") {
        case "full_screen":
            .info(
                "When Zoom is on, it magnifies the whole screen.",
                detail: "The zoom style is Full Screen.",
                why: why,
                action: action,
                confidence: .documented
            )
        case "in_window", "picture_in_picture", "pip":
            .info(
                "When Zoom is on, it magnifies a separate window that follows the pointer.",
                detail: "The zoom style is Picture-in-Picture (called Window in older macOS).",
                why: why,
                action: action,
                confidence: .documented
            )
        case "split_screen":
            .info(
                "When Zoom is on, it magnifies part of the screen in a separate area.",
                detail: "The zoom style is Split Screen.",
                why: why,
                action: action,
                confidence: .documented
            )
        default:
            nil
        }
    }
] + accessibilityFeatureRules([
    ("voiceover", "VoiceOver, the built-in screen reader, is on.", "VoiceOver is off."),
    ("sticky_keys", "Sticky Keys is on: modifier keys stay active after you press them.", "Sticky Keys is off."),
    ("slow_keys", "Slow Keys is on: a key must be held briefly before it registers.", "Slow Keys is off."),
    ("mouse_keys", "Mouse Keys is on: the keyboard can move the pointer.", "Mouse Keys is off."),
    ("cursor_mag", "The pointer is enlarged.", "The pointer is its normal size."),
    ("flash_screen", "The screen flashes when an alert sound plays.", "The screen doesn't flash for alerts."),
    ("keyboardZoom", "Zoom can be turned on with keyboard shortcuts.", "Zoom's keyboard shortcuts are off."),
    ("scrollZoom", "Zoom can be controlled by scrolling with a modifier key.", "Zooming by scrolling with a modifier key is off.")
])

/// On is Info, because it changes how the Mac behaves; off is the usual state.
private func accessibilityFeatureRules(_ features: [(field: String, whenOn: String, whenOff: String)]) -> [ValueRule] {
    features.map { feature in
        ValueRule(.universalAccess, field: feature.field) { context in
            switch decodeBooleanLike(context.reportedValue) {
            case true?:
                .info(
                    feature.whenOn,
                    detail: "This accessibility feature was on when the scan ran.",
                    why: "It changes how the Mac looks, sounds, or responds to input for everyone who uses it.",
                    action: "Nothing to do if someone relies on it. You can change it in System Settings › Accessibility.",
                    confidence: .documented
                )
            case false?:
                .normal(
                    feature.whenOff,
                    detail: "This accessibility feature was off when the scan ran, which is the default.",
                    why: "The Mac behaves as usual.",
                    action: "Nothing to do. You can turn it on in System Settings › Accessibility if it would help.",
                    confidence: .documented
                )
            case nil:
                nil
            }
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

// Sources: unsigned, Manual, and no are seen in docs/value-inventory.md. Apple's
// glossaries have no strings for this section, so verified, invalid, unverified, and
// the MDM install sources are unconfirmed. Profiles are described in
// https://support.apple.com/guide/mac-help/mh35561.

private let reviewProfiles: String = "Keep only profiles you recognize. You can review them in System Settings › General › Device Management."

let configurationProfileValueRules: [ValueRule] = [
    ValueRule(.configurationProfiles, field: "spconfigprofile_verification_state") { context in
        let why: String = "A profile can change security, network, and privacy settings, so it matters who published it."

        return switch context.reportedValue.lowercased() {
        case "verified":
            .normal(
                "The profile's signature is verified, so its publisher can be confirmed.",
                detail: "The profile was signed, and macOS checked the signature against a trusted certificate.",
                why: why,
                action: "Nothing to do if you recognize the publisher.",
                confidence: .documented
            )
        case "unsigned":
            .info(
                "The profile isn't signed, so its publisher can't be confirmed.",
                detail: "Unsigned profiles are common for ones you create or install yourself. A profile can change security and privacy settings, so it matters that you know where it came from.",
                why: why,
                action: "Keep only profiles you recognize. You can review them by searching for Profiles in System Settings.",
                confidence: .documented
            )
        case "invalid", "unverified":
            .review(
                "The profile's signature couldn't be verified.",
                detail: "The profile is signed, but macOS couldn't confirm the signature, for example because the certificate expired or isn't trusted.",
                why: why,
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
            return .info(
                "Installed by hand, not by an organization's device management.",
                detail: "Someone opened the profile file and approved it in System Settings.",
                why: "Profiles installed by hand are easy to forget, but they keep changing settings until removed.",
                action: reviewProfiles,
                confidence: .documented
            )
        }

        if value.contains("mdm") || value.contains("management") {
            return .info(
                "Installed by an organization's device management (MDM).",
                detail: "A management server sent this profile to the Mac.",
                why: "The organization that manages this Mac controls these settings.",
                action: "Nothing to do on a work or school Mac. Otherwise, check System Settings › General › Device Management.",
                confidence: .documented
            )
        }

        return nil
    },

    ValueRule(.configurationProfiles, field: "spconfigprofile_RemovalDisallowed", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "This profile can't be removed without the organization that installed it.",
                detail: "The profile is locked, usually by device management.",
                why: "Its settings stay in place until the organization removes it.",
                action: "Nothing to do on a managed Mac. If you don't know the organization, contact whoever set up the Mac.",
                confidence: .documented
            )
        case false?:
            .info(
                "This profile can be removed.",
                detail: "Anyone with an administrator account can remove it.",
                why: "You stay in control of the settings it changes.",
                action: reviewProfiles,
                confidence: .documented
            )
        case nil:
            nil
        }
    }
]

// MARK: - Printers

// Sources: the printer state names follow the CUPS printer states (idle, processing,
// stopped). The inventory withheld this Mac's printer values, so every spelling here
// is unconfirmed.

let printerValueRules: [ValueRule] = [
    ValueRule(.printers, field: "status") { context in
        switch context.reportedValue.lowercased() {
        case "idle":
            .info(
                "The printer was idle when the scan ran.",
                detail: "The printer queue was ready and had nothing to print.",
                why: "It's ready for new jobs.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case "printing", "processing":
            .info(
                "The printer was printing when the scan ran.",
                detail: "A job was being sent to the printer.",
                why: "It's a snapshot of that moment.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case "stopped":
            .info(
                "The printer queue is paused.",
                detail: "macOS isn't sending jobs to this printer, often after an error or because someone paused it.",
                why: "New print jobs wait in the queue until it's resumed.",
                action: "Resume it from the printer's queue window if you want to print.",
                confidence: .observed
            )
        default:
            nil
        }
    },

    ValueRule(.printers, field: "shared", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "This printer is shared with other devices on the network.",
                detail: "Printer Sharing makes it available to other computers.",
                why: "Others on the network can print to it, and this Mac must be awake for them to do so.",
                action: "Nothing to do if you meant to share it. You can change it in System Settings › General › Sharing.",
                confidence: .documented
            )
        case false?:
            .info(
                "This printer isn't shared.",
                detail: "Only this Mac prints to it through this queue.",
                why: "Other computers can't print through this Mac.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.printers, field: "default", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "The default printer.",
                detail: "Apps choose this printer first in the Print dialog.",
                why: "Print jobs go here unless you pick another printer.",
                action: "Nothing to do. You can change it in System Settings › Printers & Scanners.",
                confidence: .documented
            )
        case false?:
            .info(
                "Not the default printer.",
                detail: "You have to choose this printer in the Print dialog.",
                why: "Print jobs go to another printer by default.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.printers, field: "printersharing", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Printer Sharing is on.",
                detail: "This Mac can share its printers with other computers on the network.",
                why: "Other computers can print through this Mac.",
                action: "Nothing to do if you meant to share. You can change it in System Settings › General › Sharing.",
                confidence: .documented
            )
        case false?:
            .normal(
                "Printer Sharing is off.",
                detail: "This Mac doesn't share its printers.",
                why: "Other computers can't print through this Mac. This is the default.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.printers, field: "scanner", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "This printer can also scan.",
                detail: "macOS found a scanner in this device.",
                why: "You can scan from Printers & Scanners or Image Capture.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case false?:
            .info(
                "This printer doesn't scan, or macOS didn't find a scanner in it.",
                detail: "No scanner was reported for this device.",
                why: "Scanning isn't available through this printer.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case nil:
            nil
        }
    }
]
