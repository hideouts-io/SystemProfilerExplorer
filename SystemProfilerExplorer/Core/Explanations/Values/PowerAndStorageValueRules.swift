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

    ValueRule(.storage, field: "partition_map_type") { context in
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
