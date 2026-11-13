import Foundation

// MARK: - Power

// Sources: the values seen in docs/value-inventory.md (TRUE, FALSE, Good, wake, and the
// withheld 0/1 power settings) and the keys in Apple's SPPowerReporter strings: TRUE and
// FALSE ("Yes"/"No"); battery condition Good ("Normal"), Fair ("Replace Soon"), Poor
// ("Replace Now"), and Check Battery ("Service Battery"); event types wake, poweron,
// wakepoweron, sleep, shutdown, and restart; and the AC Power, Battery Power, and UPS
// Power groups. Current macOS shows the condition as Normal or Service Recommended in
// System Settings, and older menus as Replace Soon, Replace Now, or Service Battery
// (https://support.apple.com/guide/mac-help/mh20865 and
// https://support.apple.com/en-us/108376); those spellings are matched too but are
// unconfirmed in system_profiler output. Hibernate modes come from the pmset man page.
// Battery cycle and capacity limits come from https://support.apple.com/en-us/102888.

/// Apple designs current Mac notebook batteries for 1,000 charge cycles.
let batteryDesignCycleCount: Int = 1_000

/// Apple designs batteries to keep up to 80% of their original capacity through their rated cycles.
let batteryDesignCapacityPercent: Int = 80

let lowBatteryPercent: Int = 10

let powerValueRules: [ValueRule] = [
    ValueRule(.power, field: "sppower_battery_at_warn_level") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true? where decodeBooleanLike(context.sibling("sppower_battery_is_charging") ?? "") == true:
            .info(
                "The battery was low when the scan ran, and it was charging.",
                detail: "The charge was below the level where macOS warns about low battery, but a power adapter was charging it.",
                why: "Charging will bring it back up, so there's no risk of the Mac shutting down.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case true?:
            .review(
                "The battery was low when the scan ran.",
                detail: "The charge was below the level where macOS warns about low battery, and it wasn't charging.",
                why: "If the battery runs out, the Mac goes to sleep and unsaved work can be lost.",
                action: "Connect power soon.",
                confidence: .documented
            )
        case false?:
            .normal(
                "The battery wasn't low when the scan ran.",
                detail: "The charge was above the level where macOS warns about low battery.",
                why: "The Mac had enough charge to keep running on battery for now.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "sppower_battery_state_of_charge", unrecognizedValues: .ignore) { context in
        guard let percent = leadingInteger(context.reportedValue) else {
            return nil
        }

        let charging: Bool = decodeBooleanLike(context.sibling("sppower_battery_is_charging") ?? "") == true

        if percent <= lowBatteryPercent, !charging {
            return .review(
                "The battery was at \(percent)% when the scan ran.",
                detail: "That's \(lowBatteryPercent)% or less, and the battery wasn't charging.",
                why: "The Mac will soon go to sleep to protect the battery, and unsaved work could be lost.",
                action: "Connect power soon.",
                confidence: .documented
            )
        }

        return .normal(
            "The battery was at \(percent)%\(charging ? " and charging" : "") when the scan ran.",
            detail: "This is how full the battery was, as a share of what it can hold now (not when it was new).",
            why: "It's a snapshot; the charge changes all the time.",
            action: "Nothing to do.",
            confidence: .documented
        )
    },

    ValueRule(.power, field: "sppower_battery_is_charging") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            return .normal(
                "The battery was charging.",
                detail: "A power adapter was connected and charging the battery when the scan ran.",
                why: "It's a snapshot of that moment.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false? where decodeBooleanLike(context.sibling("sppower_battery_fully_charged") ?? "") == true:
            return .normal(
                "The battery wasn't charging because it was full.",
                detail: "macOS stops charging once the battery is full, even with the adapter connected.",
                why: "That's how macOS protects the battery.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            return .info(
                "The battery wasn't charging when the scan ran.",
                detail: "That's expected on battery power. On a power adapter, macOS can pause charging to protect the battery, for example with Optimized Battery Charging.",
                why: "If a power adapter was connected and the battery stays low, the adapter or the battery may have a problem.",
                action: "Nothing to do on battery. If it doesn't charge on a power adapter, try another adapter or cable and check the battery condition.",
                confidence: .documented
            )
        case nil:
            return nil
        }
    },

    ValueRule(.power, field: "sppower_battery_fully_charged") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "The battery was fully charged.",
                detail: "The battery had reached its full charge when the scan ran.",
                why: "It's a snapshot of that moment.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "The battery wasn't fully charged.",
                detail: "The battery was below its full charge when the scan ran. Optimized Battery Charging can hold it at 80% for a while.",
                why: "It's a snapshot of that moment, not a problem on its own.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "sppower_battery_health") { context in
        batteryConditionExplanation(context.reportedValue)
    },

    ValueRule(.power, field: "sppower_battery_cycle_count", unrecognizedValues: .ignore) { context in
        guard let cycles = leadingInteger(context.reportedValue) else {
            return nil
        }

        if cycles >= batteryDesignCycleCount {
            return .info(
                "\(cycles.formatted()) charge cycles, at or beyond the \(batteryDesignCycleCount.formatted()) cycles Mac notebook batteries are designed for.",
                detail: "A battery past its rated cycles still works, but usually holds less charge. Check the battery condition and maximum capacity.",
                why: "Batteries wear with use, so an older battery gives shorter battery life.",
                action: "Check the battery condition and maximum capacity. Replace the battery if battery life no longer meets your needs.",
                confidence: .documented
            )
        }

        return .normal(
            "\(cycles.formatted()) charge cycles, within the \(batteryDesignCycleCount.formatted()) cycles Mac notebook batteries are designed for.",
            detail: "One cycle is using 100% of the battery's charge in total, even if that happens across several days.",
            why: "Batteries wear with use, and this one is within its designed life.",
            action: "Nothing to do.",
            confidence: .documented
        )
    },

    ValueRule(.power, field: "sppower_battery_health_maximum_capacity", unrecognizedValues: .ignore) { context in
        guard let percent = leadingInteger(context.reportedValue) else {
            return nil
        }

        if percent < batteryDesignCapacityPercent {
            return .review(
                "The battery holds \(percent)% of its original capacity, below the \(batteryDesignCapacityPercent)% Apple designs batteries to keep.",
                detail: "A full charge now lasts noticeably less than when the battery was new.",
                why: "Battery life is shorter, and macOS may recommend service.",
                action: "Expect shorter battery life. Battery service can restore it.",
                confidence: .documented
            )
        }

        return .normal(
            "The battery holds \(percent)% of its original capacity.",
            detail: "This compares what a full charge holds now with what it held when new.",
            why: "It's at or above the \(batteryDesignCapacityPercent)% Apple designs batteries to keep, so battery life is close to normal.",
            action: "Nothing to do.",
            confidence: .documented
        )
    },

    ValueRule(.power, field: "Current Power Source", unrecognizedValues: .ignore) { context in
        guard decodeBooleanLike(context.reportedValue) == true else {
            return nil
        }

        switch context.parentKey {
        case "Battery Power":
            return .info(
                "This Mac was running on battery when the scan ran.",
                detail: "The settings in this Battery Power group were the ones in use.",
                why: "Battery settings usually save energy, for example by sleeping sooner.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "AC Power":
            return .info(
                "This Mac was running on its power adapter when the scan ran.",
                detail: "The settings in this AC Power group were the ones in use.",
                why: "Power adapter settings usually favor performance and staying awake.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "UPS Power":
            return .info(
                "This Mac was running on a UPS (backup power supply) when the scan ran.",
                detail: "The settings in this UPS Power group were the ones in use, which usually means wall power had failed.",
                why: "A UPS only lasts a short time, and macOS can shut the Mac down when it runs low.",
                action: "Save your work. If wall power is back, check the UPS and its connection.",
                confidence: .documented
            )
        default:
            return nil
        }
    },

    ValueRule(.power, field: "Hibernate Mode") { context in
        hibernateModeExplanation(context.reportedValue)
    },

    ValueRule(.power, field: "Display Sleep Timer", unrecognizedValues: .ignore) { context in
        sleepTimerExplanation(
            context.reportedValue,
            timed: "The display turns off after",
            never: "The display doesn't turn off automatically on this power source.",
            why: "Turning the display off sooner saves energy and, on a notebook, battery."
        )
    },

    ValueRule(.power, field: "System Sleep Timer", unrecognizedValues: .ignore) { context in
        sleepTimerExplanation(
            context.reportedValue,
            timed: "The Mac can go to sleep after about",
            never: "The Mac doesn't go to sleep automatically on this power source.",
            detail: "macOS also waits for the display to turn off, and apps such as media players or downloads can keep it awake longer.",
            why: "Sleeping saves energy, but a sleeping Mac can't run downloads, backups, or shared services."
        )
    },

    ValueRule(.power, field: "Disk Sleep Timer", unrecognizedValues: .ignore) { context in
        sleepTimerExplanation(
            context.reportedValue,
            timed: "Hard disks spin down after",
            never: "Hard disks don't spin down automatically on this power source.",
            detail: "This only affects spinning hard drives; solid-state drives have no disks to spin down.",
            why: "Spinning down saves energy and noise, but the next access waits a few seconds for the disk."
        )
    }
]

private func batteryConditionExplanation(_ value: String) -> ValueExplanation? {
    let serviceAction: String = "Keep backups current and contact Apple or an Apple Authorized Service Provider."

    switch value.lowercased() {
    case "good", "normal":
        return .normal(
            "The battery reports a normal condition.",
            detail: "macOS shows this as Normal: the battery is working as expected.",
            why: "Battery life should be close to what this Mac is designed for.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "fair", "replace soon":
        return .review(
            "The battery reports that it will need replacing soon (“\(value)”).",
            detail: "Apple's System Information shows this as Replace Soon: the battery works but holds less charge than when it was new.",
            why: "Battery life is shorter than new, and it will keep getting shorter.",
            action: "Plan a battery replacement. Keep backups current.",
            confidence: .documented
        )
    case "poor", "replace now":
        return .review(
            "The battery reports that it needs service (“\(value)”).",
            detail: "Apple's System Information shows this as Replace Now: the battery holds much less charge than when it was new.",
            why: "Battery life is much shorter, and the Mac may slow down or shut down unexpectedly on battery.",
            action: serviceAction,
            confidence: .documented
        )
    case "service recommended":
        return .review(
            "The battery reports that it needs service (“\(value)”).",
            detail: "Apple says the battery is working normally, but holds noticeably less charge than when it was new.",
            why: "Battery life is shorter than new. It's safe to keep using the Mac.",
            action: "If battery life no longer meets your needs, contact Apple or an Apple Authorized Service Provider about a battery replacement.",
            confidence: .documented
        )
    case "check battery", "service battery":
        return .review(
            "The battery reports that it needs service (“\(value)”).",
            detail: "Apple's System Information shows this as Service Battery: the battery isn't working as expected, even if it still holds a charge.",
            why: "Battery life may be short, and the battery may behave unexpectedly.",
            action: serviceAction,
            confidence: .documented
        )
    default:
        return nil
    }
}

private func hibernateModeExplanation(_ value: String) -> ValueExplanation? {
    switch leadingInteger(value) {
    case 3:
        .normal(
            "Safe sleep: memory stays powered and is also saved to disk, the default for Mac notebooks.",
            detail: "The Mac wakes quickly from memory, and the copy on disk protects open work if the battery runs out.",
            why: "It's the setting Apple ships on notebooks, balancing fast wake with safety.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case 0:
        .normal(
            "Memory stays powered during sleep and isn't saved to disk, the default for Mac desktops.",
            detail: "The Mac wakes quickly and doesn't write memory to disk when it sleeps.",
            why: "It's the setting Apple ships on desktops. On a notebook it means open work is lost if the battery runs out during sleep.",
            action: "Nothing to do on a desktop. On a notebook, the default is 3; this was likely changed with pmset.",
            confidence: .documented
        )
    case 25:
        .info(
            "Memory is saved to disk and powered off during sleep, which saves battery but wakes more slowly.",
            detail: "This mode can only be set with pmset in Terminal.",
            why: "Sleep uses almost no battery, but waking takes longer and writes more to the disk.",
            action: "Nothing to do if you chose this. Apple recommends against changing hibernation settings otherwise.",
            confidence: .documented
        )
    default:
        nil
    }
}

private func sleepTimerExplanation(
    _ value: String,
    timed: String,
    never: String,
    detail: String? = nil,
    why: String
) -> ValueExplanation? {
    guard let minutes = leadingInteger(value) else {
        return nil
    }

    if minutes == 0 {
        return .info(
            never,
            detail: detail ?? "A value of 0 means never.",
            why: why,
            action: "Nothing to do if you chose this. You can change it in System Settings › Battery or Energy.",
            confidence: .documented
        )
    }

    return .info(
        "\(timed) \(minutes) \(minutes == 1 ? "minute" : "minutes") of inactivity.",
        detail: detail ?? "The timer counts minutes without keyboard, mouse, or trackpad use.",
        why: why,
        action: "Nothing to do. You can change it in System Settings › Battery, Energy, or Lock Screen.",
        confidence: .documented
    )
}

// MARK: - Power settings and events

/// How a power settings group such as `AC Power` or `Battery Power` reads in a sentence.
func powerSourcePhrase(_ key: String?) -> String {
    switch key {
    case "AC Power": "on the power adapter"
    case "Battery Power": "on battery"
    case "UPS Power": "on UPS power"
    default: "for this power source"
    }
}

let powerSettingValueRules: [ValueRule] = [
    ValueRule(.power, field: "LowPowerMode") { context in
        let source: String = powerSourcePhrase(context.parentKey)

        return switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "Low Power Mode is on \(source): macOS uses less energy, which can make the Mac a little slower.",
                detail: "macOS lowers processor speed and screen brightness and cuts background activity to save energy.",
                why: "Battery lasts longer and the Mac runs cooler and quieter, at some cost to speed.",
                action: "Nothing to do if you chose this. You can change it in System Settings › Battery.",
                confidence: .documented
            )
        case false?:
            .normal(
                "Low Power Mode is off \(source).",
                detail: "The Mac runs at normal performance \(source).",
                why: "This is the default.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "HighPowerMode") { context in
        let source: String = powerSourcePhrase(context.parentKey)

        return switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "High Power Mode is on \(source): the Mac can run its fans faster to keep up performance in demanding work.",
                detail: "Only some Mac models offer this mode.",
                why: "Long, heavy tasks such as video exports can finish sooner, but the fans may be louder and the battery drains faster.",
                action: "Nothing to do if you chose this. You can change it in System Settings › Battery.",
                confidence: .documented
            )
        case false?:
            .normal(
                "High Power Mode is off \(source).",
                detail: "The Mac uses its normal balance of performance, fan noise, and energy \(source). Only some Mac models offer High Power Mode.",
                why: "This is the default.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "PrioritizeNetworkReachabilityOverSleep") { context in
        let source: String = powerSourcePhrase(context.parentKey)

        return switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "The Mac stays reachable on the network instead of sleeping fully \(source), which uses more energy.",
                detail: "This keeps network services such as file or screen sharing available while the display is off.",
                why: "Other devices can reach the Mac while it would otherwise sleep, at the cost of more energy.",
                action: "Nothing to do if you share files or the screen from this Mac. Otherwise you can turn it off in System Settings › Energy or Battery › Options.",
                confidence: .documented
            )
        case false?:
            .normal(
                "The Mac can sleep fully \(source) instead of staying reachable on the network.",
                detail: "Network services such as file or screen sharing may not answer while the Mac sleeps.",
                why: "Sleeping fully saves the most energy. This is the default.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "ReduceBrightness") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "The display dims slightly on battery to save energy.",
                detail: "macOS lowers the brightness a little when the Mac switches to battery.",
                why: "The display is one of the biggest uses of battery, so this makes the battery last longer.",
                action: "Nothing to do. You can change it in System Settings › Battery › Options.",
                confidence: .documented
            )
        case false?:
            .info(
                "The display doesn't dim automatically on battery.",
                detail: "Brightness stays where you set it when the Mac switches to battery.",
                why: "The battery drains a little faster than with dimming on.",
                action: "Nothing to do if you prefer it. You can change it in System Settings › Battery › Options.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "sppower_battery_charger_connected") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "A power adapter was connected when the scan ran.",
                detail: "The Mac was drawing power from an adapter.",
                why: "It's a snapshot of that moment.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "No power adapter was connected when the scan ran, so the Mac was running on battery.",
                detail: "The Mac wasn't drawing power from an adapter.",
                why: "It's a snapshot of that moment. The battery was supplying power.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "sppower_ups_installed") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "macOS detected a UPS (backup power supply) that it can monitor.",
                detail: "A UPS is connected with a data cable, so macOS can see its charge.",
                why: "macOS can shut the Mac down safely before the UPS runs out during a power cut.",
                action: "Nothing to do. You can set when the Mac shuts down in System Settings › Energy › UPS.",
                confidence: .documented
            )
        case false?:
            .info(
                "macOS didn't detect a UPS (backup power supply).",
                detail: "A UPS connected only for power, without a USB data cable, doesn't appear here.",
                why: "Most Macs don't use one. Without it, a power cut turns off a desktop Mac at once.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "eventtype") { context in
        scheduledPowerEventExplanation(context.reportedValue)
    }
]

private func scheduledPowerEventExplanation(_ value: String) -> ValueExplanation? {
    let summary: String

    switch value.lowercased() {
    case "wake": summary = "A scheduled wake: the Mac wakes from sleep at this time."
    case "poweron": summary = "A scheduled start: the Mac turns on at this time if it's off."
    case "wakepoweron": summary = "A scheduled wake or start: the Mac wakes or turns on at this time."
    case "sleep": summary = "A scheduled sleep: the Mac goes to sleep at this time."
    case "shutdown": summary = "A scheduled shutdown: the Mac shuts down at this time."
    case "restart": summary = "A scheduled restart: the Mac restarts at this time."
    default: return nil
    }

    return .info(
        summary,
        detail: "macOS, an app, or you scheduled this event. Scheduled By names who asked for it.",
        why: "It explains why the Mac may wake, turn on, sleep, or restart on its own. macOS schedules short wakes itself, for example for maintenance and updates.",
        action: "Nothing to do if you recognize who scheduled it. Otherwise, check the app named in Scheduled By.",
        confidence: .documented
    )
}

// MARK: - Storage

// Sources: the values seen in docs/value-inventory.md (APFS, ssd, Verified, yes/no,
// unknown_partition_map_type, guid_partition_map_type, Apple Fabric, Disk Image) and
// the keys in Apple's SPStorageReporter and SPSupport strings: ssd and rotational;
// Verified, Failing, and Not Supported; guid_, master_boot_record_, apple_, and
// unknown_partition_map_type; Journaled HFS+ and Case-sensitive Journaled HFS+. The
// other file system and protocol names are unconfirmed and matched by name. File
// system facts come from the Disk Utility User Guide
// (https://support.apple.com/guide/disk-utility/dsku19ed921c) and the Signed System
// Volume from https://support.apple.com/guide/security/secd698747c9.
//
// Serial ATA drives and cards in a card reader report the same drive and volume fields.
// The macOS samples in https://github.com/glpi-project/glpi-agent
// (resources/macos/system_profiler) show a Serial ATA drive as Verified with
// guid_partition_map_type and Journaled HFS+ and MS-DOS FAT32 volumes, and an SD card as
// Not Supported with master_boot_record_partition_map_type and an MS-DOS FAT32 volume.

let lowFreeSpaceFraction: Double = 0.10

let storageValueRules: [ValueRule] = [
    ValueRule(.storage, .nvme, .serialATA, .cardReader, field: "smart_status") { context in
        smartStatusExplanation(context.reportedValue)
    },

    ValueRule(.storage, .serialATA, .cardReader, field: "writable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            return .normal(
                "Files can be written to this volume.",
                detail: "The volume is mounted with write access.",
                why: "You and your apps can save and change files on it, subject to the usual permissions.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false? where context.sibling("mount_point") == "/":
            return .normal(
                "Read-only by design: macOS seals its system volume so it can't be changed.",
                detail: "This is the Signed System Volume. Your files live on a separate, writable data volume.",
                why: "Sealing the system stops malware and mistakes from changing macOS itself.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false? where context.nestedSibling("physical_drive", "protocol") == "Disk Image":
            return .normal(
                "A read-only disk image, which is normal for installers and downloaded apps.",
                detail: "Most downloaded disk images are made read-only so their contents can't be changed.",
                why: "It keeps the installer or app exactly as its developer made it.",
                action: "Nothing to do. Copy the app to Applications and eject the disk image when you're done.",
                confidence: .documented
            )
        case false?:
            return .info(
                "This volume is mounted read-only, so files on it can't be changed.",
                detail: "Common reasons are a drive formatted as NTFS (which macOS can read but not write), a locked SD card, or a disk with errors.",
                why: "You can open files on it, but you can't save, change, or delete them.",
                action: "If you need to write to it, check the card's lock switch, run First Aid in Disk Utility, or reformat it after backing it up.",
                confidence: .documented
            )
        case nil:
            return nil
        }
    },

    ValueRule(.storage, field: "free_space_in_bytes", unrecognizedValues: .ignore) { context in
        guard case let .integer(free) = context.scalar,
              let sizeText = context.sibling("size_in_bytes"),
              let size = Int64(sizeText),
              size > 0,
              context.nestedSibling("physical_drive", "protocol") != "Disk Image" else {
            return nil
        }

        let fraction: Double = Double(free) / Double(size)
        let percent: String = fraction.formatted(.percent.precision(.fractionLength(0)))
        let amounts: String = "\(formattedByteCount(free)) of \(formattedByteCount(size))"

        // APFS system and data volumes share one pool of space. When the data volume is in
        // the report, it carries the warning, so the same shortage isn't flagged twice.
        if context.sibling("mount_point") == "/",
           context.report.storageMountPoints.contains("/System/Volumes/Data") {
            return .info(
                "\(percent) free (\(amounts)).",
                detail: "The system volume shares its space with the data volume, which shows the same free space.",
                why: "Any shortage is reported once, on the data volume.",
                action: "Nothing to do here; check the data volume instead.",
                confidence: .documented
            )
        }

        if fraction < lowFreeSpaceFraction {
            return .review(
                "Only \(percent) free (\(amounts)).",
                detail: "When a startup disk is nearly full, the Mac can slow down and macOS updates may not install.",
                why: "macOS needs free space for updates, virtual memory, and temporary files.",
                action: "Free up space in System Settings › General › Storage.",
                confidence: .observed
            )
        }

        let sharedSpaceNote: String = ["/", "/System/Volumes/Data"].contains(context.sibling("mount_point") ?? "")
            ? "The system and data volumes share the same disk space, so both report the same free space."
            : "This is the space left on the volume when the scan ran."

        return .normal(
            "\(percent) free (\(amounts)).",
            detail: sharedSpaceNote,
            why: "There's enough room for updates and everyday use.",
            action: "Nothing to do.",
            confidence: .observed
        )
    },

    ValueRule(.storage, field: "medium_type") { context in
        switch context.reportedValue.lowercased() {
        case "ssd":
            .info(
                "A solid-state drive (flash storage, no moving parts).",
                detail: "The drive stores data on flash memory chips.",
                why: "SSDs are fast and quiet, and they don't need defragmenting.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "rotational":
            .info(
                "A spinning hard drive.",
                detail: "The drive stores data on spinning magnetic disks.",
                why: "Hard drives are slower than SSDs, and their moving parts wear out over time.",
                action: "Nothing to do. Keep backups current, especially as the drive ages.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.storage, .serialATA, .cardReader, field: "file_system") { context in
        fileSystemExplanation(context.reportedValue)
    },

    ValueRule(.storage, .nvme, .serialATA, .cardReader, field: "partition_map_type") { context in
        partitionMapExplanation(context.reportedValue)
    }
]

private func fileSystemExplanation(_ reported: String) -> ValueExplanation? {
    let value: String = reported.lowercased()
    let caseNote: String = value.contains("case-sensitive")
        ? " It's case-sensitive, so “File” and “file” are different names, which some apps don't expect."
        : ""

    if value.hasPrefix("apfs") {
        return .normal(
            "APFS, the standard Mac file system since macOS High Sierra.",
            detail: "Apple File System is built for SSDs, with snapshots, space sharing between volumes, and built-in encryption.\(caseNote)",
            why: "It's what macOS needs for its startup disk, and it supports Time Machine and FileVault.",
            action: "Nothing to do.",
            confidence: .documented
        )
    }

    if value.contains("hfs") {
        return .info(
            "Mac OS Extended (HFS+), the older Mac file system, common on older and backup drives.",
            detail: "Mac OS Extended was the Mac's standard file system before APFS.\(caseNote)",
            why: "It still works well on hard drives, but a Mac with Apple silicon can't start up from it.",
            action: "Nothing to do for a backup or data drive. Use APFS if you format a drive for a current Mac.",
            confidence: .documented
        )
    }

    if value.contains("exfat") {
        return .info(
            "exFAT, which both Macs and Windows PCs can read and write. Common on USB drives and SD cards.",
            detail: "exFAT has no journal, so a drive unplugged without ejecting can lose data.",
            why: "It's the best choice for sharing a drive with Windows, but it's less resilient than APFS.",
            action: "Always eject the drive before unplugging it.",
            confidence: .documented
        )
    }

    if value.contains("msdos") || value.contains("ms-dos") || value.contains("fat32") {
        return .info(
            "FAT32 (MS-DOS), an old format readable almost everywhere, limited to files under 4 GB.",
            detail: "FAT32 works with cameras, older devices, and nearly every computer, but it can't store a file of 4 GB or more.",
            why: "Large video files and disk images won't fit on it.",
            action: "Nothing to do unless you need to store large files. Then use exFAT or APFS.",
            confidence: .documented
        )
    }

    if value.contains("ntfs") {
        return .info(
            "NTFS, the Windows file system. macOS can read it but can't write to it.",
            detail: "macOS mounts NTFS volumes read-only.",
            why: "You can open files from it, but you can't save or change files on it from this Mac.",
            action: "To write to it from a Mac, reformat it as exFAT after backing it up.",
            confidence: .documented
        )
    }

    return nil
}

private func partitionMapExplanation(_ value: String) -> ValueExplanation? {
    switch value {
    case "guid_partition_map_type":
        .normal(
            "GUID partition map, the standard layout for Mac disks.",
            detail: "Apple's System Information calls this GPT (GUID Partition Table).",
            why: "A Mac can start up from a disk with this layout, and it works with all current Macs.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "master_boot_record_partition_map_type":
        .info(
            "Master Boot Record, an older layout common on drives formatted for Windows PCs.",
            detail: "Apple's System Information calls this MBR (Master Boot Record).",
            why: "It's fine for sharing data, but a Mac can't start up from it and it can't hold volumes larger than 2 TB.",
            action: "Nothing to do for a data drive. Use GUID if you format a drive for a Mac.",
            confidence: .documented
        )
    case "apple_partition_map_type":
        .info(
            "Apple Partition Map, the layout used by PowerPC Macs.",
            detail: "Apple's System Information calls this APM (Apple Partition Map).",
            why: "Current Macs can read it, but can't start up from it.",
            action: "Nothing to do for an old data drive. Use GUID if you reformat it.",
            confidence: .documented
        )
    case "unknown_partition_map_type":
        .info(
            "macOS didn't report a partition layout for this device.",
            detail: "Apple's System Information shows this as Unknown.",
            why: "It's expected for the built-in SSD on Apple silicon Macs and for disk images, and doesn't mean anything is wrong.",
            action: "Nothing to do.",
            confidence: .likely(reasons: [
                "This value appears for the internal SSD on Apple silicon Macs and for mounted disk images, which macOS manages differently from ordinary disks."
            ])
        )
    default:
        nil
    }
}

let storageConnectionValueRules: [ValueRule] = [
    ValueRule(.storage, field: "is_internal_disk") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            return .info(
                "A drive built into this Mac.",
                detail: "The volume is on a drive inside the Mac.",
                why: "It's always available, and on most Macs it holds macOS and your data.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false? where context.sibling("protocol") == "Disk Image":
            return .info(
                "Not a physical drive: a disk image file opened as a volume.",
                detail: "A disk image is a file that macOS opens as if it were a drive.",
                why: "It's often an installer or a downloaded app, and it goes away when you eject it.",
                action: "Nothing to do. Eject it when you're done.",
                confidence: .documented
            )
        case false?:
            return .info(
                "An external drive connected to this Mac.",
                detail: "The volume is on a drive connected by a cable or card slot.",
                why: "External drives can be unplugged, so eject them first to avoid losing data.",
                action: "Nothing to do. Eject it before unplugging it.",
                confidence: .documented
            )
        case nil:
            return nil
        }
    },

    ValueRule(.storage, field: "protocol") { context in
        storageProtocolExplanation(context.reportedValue)
    },

    ValueRule(.storage, field: "ignore_ownership") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Ownership is ignored on this volume, so anyone using this Mac can open and change its files.",
                detail: "This is the Ignore ownership on this volume option in the Finder's Get Info window. It's common for external drives shared between Macs.",
                why: "It makes a shared drive easy to use on several Macs, but every user of this Mac can read and change everything on it.",
                action: "Nothing to do for a shared drive. If it holds private files, turn the option off in Get Info.",
                confidence: .documented
            )
        case false?:
            .normal(
                "File ownership and permissions are enforced on this volume.",
                detail: "macOS checks who owns each file before letting someone open or change it.",
                why: "Other users of this Mac can't read or change your files unless you share them.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.nvme, .serialATA, .cardReader, field: "removable_media") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "The storage medium can be taken out of the drive, like a memory card.",
                detail: "The drive reports that its medium can be removed while the drive stays connected.",
                why: "Eject the medium before removing it to avoid losing data.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "The storage medium is fixed in the drive, as it is in an SSD.",
                detail: "The drive reports that its storage can't be taken out separately.",
                why: "This is how SSDs and hard drives work.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.nvme, .serialATA, .cardReader, field: "detachable_drive") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "macOS treats this drive as one that can be disconnected, like an external SSD.",
                detail: "The drive is connected in a way that lets it be unplugged, such as over Thunderbolt or USB.",
                why: "Eject it before unplugging it to avoid losing data.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "macOS treats this drive as permanently connected, like a built-in SSD.",
                detail: "The drive is inside the Mac or otherwise can't be unplugged.",
                why: "It's always available to macOS.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
]

// MARK: - Serial ATA

// Sources: the macOS samples in https://github.com/glpi-project/glpi-agent
// (resources/macos/system_profiler) show spsata_medium_type (Rotational, Solid State),
// spsata_physical_interconnect (SATA, PCI), spsata_negotiatedlinkspeed and
// spsata_portspeed (3 Gigabit), spsata_ncq (Yes, No), and, for Apple's SSD controller,
// spsata_linkspeed (5.0 GT/s) and spsata_linkwidth (x2). 1.5 and 6 Gigabit, the other
// SATA generations, and the other PCI Express rates are unconfirmed in system_profiler
// output. Speeds follow the SATA-IO and PCI-SIG specifications.

let serialATAValueRules: [ValueRule] = [
    ValueRule(.serialATA, field: "spsata_medium_type") { context in
        switch context.reportedValue.lowercased() {
        case "solid state":
            .info(
                "A solid-state drive (flash storage, no moving parts).",
                detail: "The drive stores data on flash memory chips.",
                why: "SSDs are much faster than hard drives, and they have no moving parts to wear out.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case "rotational":
            .info(
                "A spinning hard drive.",
                detail: "The drive stores data on spinning magnetic disks, as the internal drives of many older iMacs and Mac minis do.",
                why: "Hard drives are much slower than SSDs, and their moving parts wear out over time.",
                action: "Nothing to do. Keep backups current, especially as the drive ages.",
                confidence: .observed
            )
        default:
            nil
        }
    },

    ValueRule(.serialATA, field: "spsata_physical_interconnect") { context in
        switch context.reportedValue.uppercased() {
        case "SATA":
            .info(
                "The controller connects its drives over Serial ATA (SATA).",
                detail: "SATA is the connection the internal hard drives, SSDs, and optical drives of Intel Macs use.",
                why: "SATA tops out at 6 Gb/s, slower than the PCI Express and NVMe storage in newer Macs.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case "PCI":
            .info(
                "The controller connects over PCI Express, as the built-in flash storage of some Intel Macs does.",
                detail: "The SSD uses the same commands as a SATA drive (AHCI), but it's wired to the Mac over PCI Express instead of a SATA cable.",
                why: "That's why a fast SSD appears under Serial ATA. It isn't limited to SATA speeds.",
                action: "Nothing to do.",
                confidence: .likely(reasons: [
                    "In a published sample, Apple's SSD Controller reports PCI here, together with a PCI Express link speed and width.",
                    "Its port description names AHCI, the standard interface for SATA controllers."
                ])
            )
        default:
            nil
        }
    },

    ValueRule(.serialATA, field: "spsata_portspeed") { context in
        sataLinkSpeed(context.reportedValue).map { speed in
            .info(
                "This port supports up to \(speed.label) (\(speed.generation)).",
                detail: "It's the fastest speed the port can run. The drive decides whether it runs that fast.",
                why: "A drive can't be faster than its port. Hard drives rarely need more than 3 Gb/s, but SSDs can use 6 Gb/s.",
                action: "Nothing to do.",
                confidence: .observed
            )
        }
    },

    ValueRule(.serialATA, field: "spsata_negotiatedlinkspeed") { context in
        guard let negotiated = sataLinkSpeed(context.reportedValue) else {
            return nil
        }

        if let port = context.sibling("spsata_portspeed").flatMap(sataLinkSpeed), negotiated.gigabits < port.gigabits {
            return .info(
                "The link runs at \(negotiated.label), slower than the \(port.label) the port supports.",
                detail: "The drive and port agreed on the slower speed. Older drives and optical drives often support only that speed, and a worn cable can force it too.",
                why: "An SSD on a slower link can't reach its full speed. Hard drives and optical drives are rarely held back by it.",
                action: "Nothing to do for a hard drive or optical drive. For an SSD, check that it supports \(port.label).",
                confidence: .observed
            )
        }

        return .normal(
            "The link runs at \(negotiated.label) (\(negotiated.generation)).",
            detail: "This is the speed the drive and port agreed on when the drive connected.",
            why: "It's the most the connection can carry. The drive itself may be slower.",
            action: "Nothing to do.",
            confidence: .observed
        )
    },

    ValueRule(.serialATA, field: "spsata_ncq") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "The drive supports Native Command Queuing (NCQ).",
                detail: "The drive can accept several requests at once and reorder them to finish sooner.",
                why: "It helps the drive keep up when apps read and write many small files.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case false?:
            .info(
                "The drive doesn't use Native Command Queuing (NCQ).",
                detail: "The drive handles one request at a time. That's usual for optical drives, some older drives, and virtual machine disks.",
                why: "Busy workloads can be a little slower without it. It doesn't mean anything is wrong.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case nil:
            nil
        }
    },

    ValueRule(.serialATA, field: "spsata_linkspeed") { context in
        pciExpressGeneration(context.reportedValue).map { generation in
            .info(
                "The controller's PCI Express link runs at \(context.reportedValue) per lane (\(generation)).",
                detail: "This is the speed of each lane between the storage controller and the Mac.",
                why: "Together with the number of lanes, it sets the most the storage can transfer.",
                action: "Nothing to do.",
                confidence: .observed
            )
        }
    },

    ValueRule(.serialATA, field: "spsata_linkwidth") { context in
        pciExpressLaneCount(context.reportedValue).map { lanes in
            .info(
                lanes == 1
                    ? "The controller uses one PCI Express lane."
                    : "The controller uses \(lanes) PCI Express lanes.",
                detail: "Each lane carries data separately, so more lanes allow faster transfers.",
                why: "Together with the link speed, it sets the most the storage can transfer.",
                action: "Nothing to do.",
                confidence: .observed
            )
        }
    }
]

private struct SATALinkSpeed {
    let gigabits: Double
    let label: String
    let generation: String
}

/// Reads speeds such as `3 Gigabit`. Some locales write `1,5 Gigabit`.
private func sataLinkSpeed(_ value: String) -> SATALinkSpeed? {
    let parts: [Substring] = value.split(separator: " ")

    guard parts.count == 2,
          parts[1].lowercased() == "gigabit",
          let gigabits = Double(parts[0].replacingOccurrences(of: ",", with: ".")) else {
        return nil
    }

    switch gigabits {
    case 1.5:
        return SATALinkSpeed(gigabits: gigabits, label: "1.5 Gb/s", generation: "SATA I")
    case 3:
        return SATALinkSpeed(gigabits: gigabits, label: "3 Gb/s", generation: "SATA II")
    case 6:
        return SATALinkSpeed(gigabits: gigabits, label: "6 Gb/s", generation: "SATA III")
    default:
        return nil
    }
}

/// Names the PCI Express generation of a per-lane rate such as `5.0 GT/s`.
func pciExpressGeneration(_ value: String) -> String? {
    let parts: [Substring] = value.split(separator: " ")

    guard parts.count == 2,
          parts[1] == "GT/s",
          let rate = Double(parts[0].replacingOccurrences(of: ",", with: ".")) else {
        return nil
    }

    switch rate {
    case 2.5: return "PCI Express 1"
    case 5: return "PCI Express 2"
    case 8: return "PCI Express 3"
    case 16: return "PCI Express 4"
    case 32: return "PCI Express 5"
    default: return nil
    }
}

/// Reads a lane count such as `x2`.
func pciExpressLaneCount(_ value: String) -> Int? {
    let trimmed: String = value.trimmingCharacters(in: .whitespaces).lowercased()
    let digits: Substring = trimmed.dropFirst()

    guard trimmed.hasPrefix("x"), !digits.isEmpty,
          digits.allSatisfy({ ("0"..."9").contains($0) }),
          let lanes: Int = Int(digits), [1, 2, 4, 8, 16].contains(lanes) else {
        return nil
    }

    return lanes
}

/// Explains the connection a storage device reports, such as `Apple Fabric` or `USB`.
func storageProtocolExplanation(_ value: String) -> ValueExplanation? {
    let external: String = "External drives should be ejected before they're unplugged."

    return switch value.lowercased() {
    case "apple fabric":
        .info(
            "Connected over Apple Fabric, the internal connection to the built-in SSD.",
            detail: "The SSD is part of the Apple silicon chip's storage system rather than a separate drive.",
            why: "It's the fastest storage in the Mac, and it can't be removed or upgraded.",
            action: "Nothing to do.",
            confidence: .likely(reasons: [
                "Apple doesn't document this name. system_profiler reports it for the built-in SSD on Apple silicon Macs."
            ])
        )
    case "disk image":
        .info(
            "A disk image file opened as a volume, such as an installer or a downloaded app.",
            detail: "It's a file that macOS opens as if it were a drive.",
            why: "It isn't a physical drive, so its speed and health depend on the drive the file is on.",
            action: "Nothing to do. Eject it when you're done.",
            confidence: .documented
        )
    case "usb":
        .info(
            "Connected over USB.",
            detail: "The drive is connected by USB, directly or through an adapter or hub.",
            why: "USB speed depends on the port, cable, and drive. \(external)",
            action: "Nothing to do. If it's slow, connect it directly to the Mac with a faster cable.",
            confidence: .documented
        )
    case "thunderbolt":
        .info(
            "Connected over Thunderbolt.",
            detail: "The drive is connected by Thunderbolt.",
            why: "Thunderbolt is the fastest external connection on a Mac. \(external)",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "sata":
        .info(
            "Connected over SATA, the connection older internal drives use.",
            detail: "The drive uses a SATA connection, as internal drives in Intel Macs from before about 2013 do.",
            why: "SATA is slower than the NVMe and Apple Fabric connections newer Macs use.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "pci-express", "pci express", "pci":
        .info(
            "Connected over PCI Express.",
            detail: "The drive connects directly over PCI Express, like the built-in SSDs in Intel Macs from about 2013 on.",
            why: "PCI Express is much faster than SATA.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "nvme", "nvm express":
        .info(
            "An NVMe solid-state drive.",
            detail: "NVMe is the fast storage standard most modern SSDs use.",
            why: "It's much faster than older SATA drives.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "secure digital", "sd":
        .info(
            "A memory card in an SD card reader.",
            detail: "The volume is on a removable SD card.",
            why: "Memory cards are slower than SSDs and wear out with heavy use. Eject the card before removing it.",
            action: "Nothing to do.",
            confidence: .documented
        )
    default:
        nil
    }
}

func smartStatusExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "verified":
        .normal(
            "The drive's self-check (SMART) reports no problems.",
            detail: "The drive monitors its own health, and none of its checks had failed when the scan ran.",
            why: "It's a good sign, but it can't predict every failure.",
            action: "Nothing to do. Keep backups current anyway.",
            confidence: .documented
        )
    case "failing":
        .review(
            "The drive's self-check (SMART) reports that it is failing.",
            detail: "The drive's own health checks have found a problem that often comes before the drive stops working.",
            why: "You could lose the data on it at any time.",
            action: "Back up this drive now and plan to replace it.",
            confidence: .documented
        )
    case "not supported":
        .info(
            "This drive doesn't report a SMART status, which is common for external and USB drives.",
            detail: "macOS can't read the drive's self-check results, often because the enclosure or adapter doesn't pass them on.",
            why: "The drive may be healthy, but macOS can't warn you if it starts to fail.",
            action: "Keep backups current, and use the drive maker's tools if you want to check its health.",
            confidence: .documented
        )
    default:
        nil
    }
}
