import Foundation

func storageExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch path.joined(separator: ".") {
    case "bsd_name":
        FieldExplanation(
            title: "BSD Device Name",
            meaning: "This is the kernel device identifier used by command-line tools, such as disk3s1s1. The disk portion identifies a device and the suffixes identify slices, synthesized volumes, or snapshots.",
            significance: "Utilities such as diskutil, mount, and filesystem tools use this name when addressing the currently attached storage object.",
            interpretation: "Disk identifiers are assigned dynamically and can change after restart, reconnect, or storage-topology changes. Always obtain a fresh inventory before using one in a command.",
            privacy: nil
        )

    case "file_system":
        FieldExplanation(
            title: "File System",
            meaning: "This identifies the filesystem used to organize files and metadata on the volume. APFS is Apple's modern filesystem for macOS startup and data volumes.",
            significance: "The filesystem determines supported features such as snapshots, encryption, cloning, permissions, case sensitivity, and compatibility with other operating systems.",
            interpretation: "The filesystem name does not show whether the volume is healthy, encrypted, case-sensitive, or free of corruption. Those properties require additional fields or dedicated checks.",
            privacy: nil
        )

    case "free_space_in_bytes":
        FieldExplanation(
            title: "Available Space",
            meaning: "This is the amount of storage that system_profiler reported as available when the scan ran.",
            significance: "Low available space can affect application updates, virtual memory, snapshots, caches, and general system reliability.",
            interpretation: "APFS volumes commonly share one container's free-space pool, so multiple volumes may report the same available space. Do not add repeated values together, and expect the number to change as purgeable data and snapshots are managed.",
            privacy: nil
        )

    case "ignore_ownership":
        FieldExplanation(
            title: "Ignore Ownership",
            meaning: "This reports whether macOS is configured to disregard stored Unix user and group ownership when accessing the mounted volume.",
            significance: "Ignoring ownership can make removable or shared media easier to use across accounts. Enforcing ownership is important when file access must follow local user and group permissions.",
            interpretation: "Either state can be legitimate depending on the volume's purpose. This field alone does not prove that files are publicly accessible or that permissions are insecure.",
            privacy: nil
        )

    case "mount_point":
        FieldExplanation(
            title: "Mount Point",
            meaning: "This is the filesystem path where the volume is attached and its contents become accessible, such as `/` or `/System/Volumes/Data`.",
            significance: "The mount point reveals the volume's role in the active macOS filesystem and distinguishes startup, data, recovery, removable, and auxiliary volumes.",
            interpretation: "A path shows where a volume is mounted, not why it was mounted, who accessed it, or whether every item beneath the path belongs to that volume.",
            privacy: "Mount paths can contain usernames or descriptive volume names. Review them before sharing exported reports."
        )

    case "physical_drive.device_name":
        FieldExplanation(
            title: "Physical Device",
            meaning: "This is the hardware or controller-provided model name for the physical storage device backing the volume.",
            significance: "It helps identify the storage family when investigating performance, compatibility, firmware, or hardware-service questions.",
            interpretation: "A device name is not a complete health assessment and may describe a controller, virtual media layer, or generic product family rather than a unique physical unit.",
            privacy: nil
        )

    case "physical_drive.is_internal_disk":
        FieldExplanation(
            title: "Internal Storage",
            meaning: "This reports whether macOS classifies the underlying storage as internal to the Mac rather than externally attached.",
            significance: "Internal and external devices can have different removal behavior, performance expectations, security policies, and startup support.",
            interpretation: "This classification describes the connection topology reported by macOS. It does not prove that the hardware is original, permanently installed, or inaccessible to other systems.",
            privacy: nil
        )

    case "physical_drive.media_name":
        FieldExplanation(
            title: "Media Name",
            meaning: "This is the name assigned to the storage media object by its driver or storage stack.",
            significance: "It helps correlate a volume with the physical or synthesized media shown by Disk Utility, diskutil, and I/O Registry tools.",
            interpretation: "Generic names such as AppleAPFSMedia describe a storage layer, not necessarily the retail name or unique identity of the physical drive.",
            privacy: nil
        )

    case "physical_drive.medium_type":
        FieldExplanation(
            title: "Medium Type",
            meaning: "This identifies the broad storage technology, such as solid-state storage or a rotating hard disk.",
            significance: "The medium type affects expected latency, throughput, power consumption, noise, shock tolerance, and maintenance behavior.",
            interpretation: "The category does not measure actual performance, remaining endurance, health, or connection speed.",
            privacy: nil
        )

    case "physical_drive.partition_map_type":
        FieldExplanation(
            title: "Partition Map Type",
            meaning: "This describes the partition-map scheme that divides a physical device into addressable regions, when system_profiler can identify it.",
            significance: "Partition layout affects boot compatibility and how operating systems locate volumes on a physical disk.",
            interpretation: "An `unknown` value does not by itself mean the disk is corrupt or suspicious. Synthesized APFS media and storage abstraction layers may not expose a conventional map here; use `diskutil list` for authoritative topology.",
            privacy: nil
        )

    case "physical_drive.protocol":
        FieldExplanation(
            title: "Storage Protocol",
            meaning: "This identifies the connection or transport through which macOS communicates with the storage device, such as Apple Fabric, NVMe, SATA, or USB.",
            significance: "The protocol influences available bandwidth, latency, hot-plug behavior, and which diagnostic tools apply.",
            interpretation: "The protocol name does not show the negotiated speed, current workload, encryption state, or health of the connection.",
            privacy: nil
        )

    case "physical_drive.smart_status":
        smartStatusExplanation(reportedValue: reportedValue)

    case "size_in_bytes":
        FieldExplanation(
            title: "Capacity",
            meaning: "This is the byte capacity system_profiler associates with the volume or storage object.",
            significance: "Capacity provides context for free-space calculations, storage planning, and comparisons between volumes.",
            interpretation: "APFS volumes can share container capacity, so the same total may appear more than once. The value is not necessarily the amount exclusively reserved for this volume and may differ from marketing capacity because of formatting conventions and filesystem overhead.",
            privacy: nil
        )

    case "volume_uuid":
        FieldExplanation(
            title: "Volume UUID",
            meaning: "This is a filesystem-level unique identifier assigned to the volume. macOS can use it to recognize the volume independently of its display name or current disk number.",
            significance: "It helps correlate mount records, configuration, backups, and repeated observations of the same logical volume.",
            interpretation: "It identifies a volume, not a user or a physical disk. Cloning, restoration, or filesystem recreation can preserve or replace identifiers depending on the operation.",
            privacy: "This persistent identifier can correlate reports involving the same volume. Redact it from public reports when that correlation is unnecessary."
        )

    case "writable":
        FieldExplanation(
            title: "Writable",
            meaning: "This reports whether the mounted volume currently accepts ordinary filesystem writes through this mount.",
            significance: "A writable data volume permits normal file changes, while a read-only mount protects its contents from ordinary modification.",
            interpretation: "A read-only result is not automatically an error. Modern macOS normally presents the sealed system volume as read-only while pairing it with a writable Data volume; mount options, permissions, and filesystem health require separate evaluation.",
            privacy: nil
        )

    default:
        nil
    }
}
private func smartStatusExplanation(reportedValue: String) -> FieldExplanation {
    let normalizedValue: String = reportedValue.lowercased()
    let significance: String

    if normalizedValue == "verified" {
        significance = "The device reported a passing status at scan time, so its self-monitoring system was not signaling an imminent failure through this summary field."
    } else {
        significance = "The reported status is not the normal `Verified` summary and should be investigated with current backups and storage-specific diagnostics before relying on the device."
    }

    return FieldExplanation(
        title: "SMART Status",
        meaning: "SMART is a drive self-monitoring system that exposes a summarized hardware-health assessment when the device and connection support it.",
        significance: significance,
        interpretation: "A passing SMART result does not guarantee that the drive is healthy, that data is intact, or that failure is impossible. Some failure modes occur without advance warning, and external bridges may not expose complete SMART data.",
        privacy: nil
    )
}
