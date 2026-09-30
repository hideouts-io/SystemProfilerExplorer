import Foundation

// MARK: - Power

/// Apple designs current Mac notebook batteries for 1,000 charge cycles.
let batteryDesignCycleCount: Int = 1_000

/// Apple designs batteries to keep up to 80% of their original capacity through their rated cycles.
let batteryDesignCapacityPercent: Int = 80

let lowBatteryPercent: Int = 10

let powerValueRules: [ValueRule] = [
    ValueRule(.power, field: "sppower_battery_at_warn_level") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true? where decodeBooleanLike(context.sibling("sppower_battery_is_charging") ?? "") == true:
            .info("The battery was low when the scan ran, and it was charging.")
        case true?:
            .review("The battery was low when the scan ran.", action: "Connect power soon.")
        case false?:
            .normal("The battery wasn't low when the scan ran.")
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
            return .review("The battery was at \(percent)% when the scan ran.", action: "Connect power soon.")
        }

        return .normal("The battery was at \(percent)%\(charging ? " and charging" : "") when the scan ran.")
    },

    ValueRule(.power, field: "sppower_battery_is_charging") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            return .normal("The battery was charging.")
        case false? where decodeBooleanLike(context.sibling("sppower_battery_fully_charged") ?? "") == true:
            return .normal("The battery wasn't charging because it was full.")
        case false?:
            return .info(
                "The battery wasn't charging when the scan ran.",
                detail: "That's expected on battery power. On a power adapter, macOS can pause charging to protect the battery, for example with Optimized Battery Charging.",
                confidence: .documented
            )
        case nil:
            return nil
        }
    },

    ValueRule(.power, field: "sppower_battery_fully_charged") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .normal("The battery was fully charged.")
        case false?: .info("The battery wasn't fully charged.")
        case nil: nil
        }
    },

    ValueRule(.power, field: "sppower_battery_health") { context in
        let value: String = context.reportedValue.lowercased()

        if value == "good" || value == "normal" {
            return .normal("The battery reports a normal condition.", confidence: .documented)
        }

        if value.contains("service") || value.contains("replace") || value == "poor" {
            return .review(
                "The battery reports that it needs service (“\(context.reportedValue)”).",
                detail: "It may hold less charge than when it was new, or behave unexpectedly.",
                action: "Keep backups current and contact Apple or an Apple Authorized Service Provider.",
                confidence: .documented
            )
        }

        return nil
    },

    ValueRule(.power, field: "sppower_battery_cycle_count", unrecognizedValues: .ignore) { context in
        guard let cycles = leadingInteger(context.reportedValue) else {
            return nil
        }

        if cycles >= batteryDesignCycleCount {
            return .info(
                "\(cycles.formatted()) charge cycles, at or beyond the \(batteryDesignCycleCount.formatted()) cycles Mac notebook batteries are designed for.",
                detail: "A battery past its rated cycles still works, but usually holds less charge. Check the battery condition and maximum capacity.",
                confidence: .documented
            )
        }

        return .normal(
            "\(cycles.formatted()) charge cycles, within the \(batteryDesignCycleCount.formatted()) cycles Mac notebook batteries are designed for.",
            detail: "One cycle is using 100% of the battery's charge in total, even if that happens across several days.",
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
                action: "Expect shorter battery life. Battery service can restore it.",
                confidence: .documented
            )
        }

        return .normal("The battery holds \(percent)% of its original capacity.", confidence: .documented)
    },

    ValueRule(.power, field: "Current Power Source", unrecognizedValues: .ignore) { context in
        guard decodeBooleanLike(context.reportedValue) == true else {
            return nil
        }

        switch context.parentKey {
        case "Battery Power": return .info("This Mac was running on battery when the scan ran.")
        case "AC Power": return .info("This Mac was running on its power adapter when the scan ran.")
        default: return nil
        }
    },

    ValueRule(.power, field: "Hibernate Mode") { context in
        switch leadingInteger(context.reportedValue) {
        case 3:
            .normal(
                "Safe sleep: memory stays powered and is also saved to disk, the default for Mac notebooks.",
                confidence: .documented
            )
        case 0:
            .normal("Memory stays powered during sleep and isn't saved to disk, the default for Mac desktops.", confidence: .documented)
        case 25:
            .info("Memory is saved to disk and powered off during sleep, which saves battery but wakes more slowly.", confidence: .documented)
        default:
            nil
        }
    },

    ValueRule(.power, field: "Display Sleep Timer", unrecognizedValues: .ignore) { context in
        sleepTimerExplanation(
            context.reportedValue,
            timed: "The display turns off after",
            never: "The display doesn't turn off automatically on this power source."
        )
    },

    ValueRule(.power, field: "System Sleep Timer", unrecognizedValues: .ignore) { context in
        sleepTimerExplanation(
            context.reportedValue,
            timed: "The Mac can go to sleep after about",
            never: "The Mac doesn't go to sleep automatically on this power source.",
            detail: "macOS also waits for the display to turn off, and apps such as media players or downloads can keep it awake longer."
        )
    },

    ValueRule(.power, field: "Disk Sleep Timer", unrecognizedValues: .ignore) { context in
        sleepTimerExplanation(
            context.reportedValue,
            timed: "Hard disks spin down after",
            never: "Hard disks don't spin down automatically on this power source.",
            detail: "This only affects spinning hard drives; solid-state drives have no disks to spin down."
        )
    }
]

private func sleepTimerExplanation(
    _ value: String,
    timed: String,
    never: String,
    detail: String? = nil
) -> ValueExplanation? {
    guard let minutes = leadingInteger(value) else {
        return nil
    }

    if minutes == 0 {
        return .info(never, detail: detail, confidence: .documented)
    }

    return .info(
        "\(timed) \(minutes) \(minutes == 1 ? "minute" : "minutes") of inactivity.",
        detail: detail,
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
                confidence: .documented
            )
        case false?:
            .normal("Low Power Mode is off \(source).", confidence: .documented)
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
                confidence: .documented
            )
        case false?:
            .normal("High Power Mode is off \(source).", confidence: .documented)
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
                detail: "This keeps network services such as file or screen sharing available while the display is off."
            )
        case false?:
            .normal("The Mac can sleep fully \(source) instead of staying reachable on the network.")
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "ReduceBrightness") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?: .info("The display dims slightly on battery to save energy.", confidence: .documented)
        case false?: .info("The display doesn't dim automatically on battery.", confidence: .documented)
        case nil: nil
        }
    },

    ValueRule(.power, field: "sppower_battery_charger_connected") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("A power adapter was connected when the scan ran.")
        case false?: .info("No power adapter was connected when the scan ran, so the Mac was running on battery.")
        case nil: nil
        }
    },

    ValueRule(.power, field: "sppower_ups_installed") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info("macOS detected a UPS (backup power supply) that it can monitor.", confidence: .documented)
        case false?:
            .info(
                "macOS didn't detect a UPS (backup power supply).",
                detail: "A UPS connected only for power, without a USB data cable, doesn't appear here."
            )
        case nil:
            nil
        }
    },

    ValueRule(.power, field: "eventtype") { context in
        switch context.reportedValue.lowercased() {
        case "wake": .info("A scheduled wake: the Mac wakes from sleep at this time.", confidence: .documented)
        case "poweron": .info("A scheduled start: the Mac turns on at this time if it's off.", confidence: .documented)
        case "wakepoweron": .info("A scheduled wake or start: the Mac wakes or turns on at this time.", confidence: .documented)
        case "sleep": .info("A scheduled sleep: the Mac goes to sleep at this time.", confidence: .documented)
        case "shutdown": .info("A scheduled shutdown: the Mac shuts down at this time.", confidence: .documented)
        case "restart": .info("A scheduled restart: the Mac restarts at this time.", confidence: .documented)
        default: nil
        }
    }
]

// MARK: - Storage

let lowFreeSpaceFraction: Double = 0.10

let storageValueRules: [ValueRule] = [
    ValueRule(.storage, .nvme, .serialATA, field: "smart_status") { context in
        smartStatusExplanation(context.reportedValue)
    },

    ValueRule(.storage, field: "writable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            return .normal("Files can be written to this volume.")
        case false? where context.sibling("mount_point") == "/":
            return .normal(
                "Read-only by design: macOS seals its system volume so it can't be changed.",
                detail: "This is the Signed System Volume. Your files live on a separate, writable data volume.",
                confidence: .documented
            )
        case false? where context.nestedSibling("physical_drive", "protocol") == "Disk Image":
            return .normal("A read-only disk image, which is normal for installers and downloaded apps.")
        case false?:
            return .info("This volume is mounted read-only, so files on it can't be changed.")
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
                detail: "The system volume shares its space with the data volume, which shows the same free space."
            )
        }

        if fraction < lowFreeSpaceFraction {
            return .review(
                "Only \(percent) free (\(amounts)).",
                detail: "When a startup disk is nearly full, the Mac can slow down and macOS updates may not install.",
                action: "Free up space in System Settings › General › Storage."
            )
        }

        let sharedSpaceNote: String? = ["/", "/System/Volumes/Data"].contains(context.sibling("mount_point") ?? "")
            ? "The system and data volumes share the same disk space, so both report the same free space."
            : nil

        return .normal("\(percent) free (\(amounts)).", detail: sharedSpaceNote)
    },

    ValueRule(.storage, field: "medium_type") { context in
        switch context.reportedValue.lowercased() {
        case "ssd": .info("A solid-state drive (flash storage, no moving parts).")
        case "rotational": .info("A spinning hard drive.")
        default: nil
        }
    },

    ValueRule(.storage, field: "file_system") { context in
        let value: String = context.reportedValue.lowercased()

        if value == "apfs" {
            return .normal("APFS, the standard Mac file system since macOS High Sierra.", confidence: .documented)
        }

        if value.contains("hfs") {
            return .info("Mac OS Extended (HFS+), the older Mac file system, common on older and backup drives.", confidence: .documented)
        }

        if value.contains("exfat") {
            return .info("exFAT, which both Macs and Windows PCs can read and write. Common on USB drives and SD cards.", confidence: .documented)
        }

        if value.contains("msdos") || value.contains("fat32") {
            return .info("FAT32 (MS-DOS), an old format readable almost everywhere, limited to files under 4 GB.", confidence: .documented)
        }

        return nil
    },

    ValueRule(.storage, .nvme, field: "partition_map_type") { context in
        switch context.reportedValue {
        case "guid_partition_map_type":
            .normal("GUID partition map, the standard layout for Mac disks.", confidence: .documented)
        case "master_boot_record_partition_map_type":
            .info("Master Boot Record, an older layout common on drives formatted for Windows PCs.", confidence: .documented)
        case "unknown_partition_map_type":
            .info(
                "macOS didn't report a partition layout for this device.",
                confidence: .likely(reasons: [
                    "This value appears for the internal SSD on Apple silicon Macs and for mounted disk images, which macOS manages differently from ordinary disks."
                ])
            )
        default:
            nil
        }
    }
]

let storageConnectionValueRules: [ValueRule] = [
    ValueRule(.storage, field: "is_internal_disk") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            return .info("A drive built into this Mac.")
        case false? where context.sibling("protocol") == "Disk Image":
            return .info("Not a physical drive: a disk image file opened as a volume.")
        case false?:
            return .info("An external drive connected to this Mac.")
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
                confidence: .documented
            )
        case false?:
            .normal("File ownership and permissions are enforced on this volume.", confidence: .documented)
        case nil:
            nil
        }
    },

    ValueRule(.nvme, field: "removable_media") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("The storage medium can be taken out of the drive, like a memory card.")
        case false?: .info("The storage medium is fixed in the drive, as it is in an SSD.")
        case nil: nil
        }
    },

    ValueRule(.nvme, field: "detachable_drive") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("macOS treats this drive as one that can be disconnected, like an external SSD.")
        case false?: .info("macOS treats this drive as permanently connected, like a built-in SSD.")
        case nil: nil
        }
    }
]

/// Explains the connection a storage device reports, such as `Apple Fabric` or `USB`.
func storageProtocolExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "apple fabric":
        .info(
            "Connected over Apple Fabric, the internal connection to the built-in SSD.",
            confidence: .likely(reasons: [
                "Apple doesn't document this name. system_profiler reports it for the built-in SSD on Apple silicon Macs."
            ])
        )
    case "disk image":
        .info("A disk image file opened as a volume, such as an installer or a downloaded app.")
    case "usb":
        .info("Connected over USB.")
    case "thunderbolt":
        .info("Connected over Thunderbolt.")
    case "sata":
        .info("Connected over SATA, the connection older internal drives use.")
    case "pci-express", "pci express", "pci":
        .info("Connected over PCI Express.")
    case "nvme", "nvm express":
        .info("An NVMe solid-state drive.")
    case "secure digital", "sd":
        .info("A memory card in an SD card reader.")
    default:
        nil
    }
}

func smartStatusExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "verified":
        .normal("The drive's self-check (SMART) reports no problems.", confidence: .documented)
    case "failing":
        .review(
            "The drive's self-check (SMART) reports that it is failing.",
            action: "Back up this drive now and plan to replace it.",
            confidence: .documented
        )
    case "not supported":
        .info("This drive doesn't report a SMART status, which is common for external and USB drives.")
    default:
        nil
    }
}
