import Testing
@testable import SystemProfilerExplorer

struct FindingExplanationTests {
    @Test
    func currentHardwareAndStorageFieldsHaveCuratedExplanations() {
        let fields: [(SystemProfilerDataType, [String], String)] = [
            (.hardware, ["activation_lock_status"], "activation_lock_disabled"),
            (.hardware, ["boot_rom_version"], "1234.0.0"),
            (.hardware, ["chip_type"], "Apple silicon"),
            (.hardware, ["machine_model"], "Mac00,0"),
            (.hardware, ["machine_name"], "Mac"),
            (.hardware, ["model_number"], "MODEL"),
            (.hardware, ["number_processors"], "proc 8:4:4:0"),
            (.hardware, ["os_loader_version"], "1234.0.0"),
            (.hardware, ["physical_memory"], "16 GB"),
            (.hardware, ["platform_UUID"], "REDACTED"),
            (.hardware, ["provisioning_UDID"], "REDACTED"),
            (.hardware, ["serial_number"], "REDACTED"),
            (.storage, ["bsd_name"], "disk0s1"),
            (.storage, ["file_system"], "APFS"),
            (.storage, ["free_space_in_bytes"], "1000000"),
            (.storage, ["ignore_ownership"], "no"),
            (.storage, ["mount_point"], "/"),
            (.storage, ["physical_drive", "device_name"], "Storage Device"),
            (.storage, ["physical_drive", "is_internal_disk"], "yes"),
            (.storage, ["physical_drive", "media_name"], "Media"),
            (.storage, ["physical_drive", "medium_type"], "ssd"),
            (.storage, ["physical_drive", "partition_map_type"], "unknown_partition_map_type"),
            (.storage, ["physical_drive", "protocol"], "NVMe"),
            (.storage, ["physical_drive", "smart_status"], "Verified"),
            (.storage, ["size_in_bytes"], "1000000"),
            (.storage, ["volume_uuid"], "REDACTED"),
            (.storage, ["writable"], "yes")
        ]

        for (dataType, path, value) in fields {
            #expect(explanation(for: dataType, path: path, reportedValue: value) != nil)
        }
    }

    @Test
    func sensitiveIdentifiersIncludePrivacyGuidance() throws {
        let serialExplanation = try #require(
            explanation(for: .hardware, path: ["serial_number"], reportedValue: "REDACTED")
        )
        let volumeExplanation = try #require(
            explanation(for: .storage, path: ["volume_uuid"], reportedValue: "REDACTED")
        )

        #expect(serialExplanation.privacy != nil)
        #expect(volumeExplanation.privacy != nil)
    }

    @Test
    func byteValuesAreReadableWithoutLosingTheRawValue() {
        let presentation = fieldPresentation(
            dataType: .storage,
            path: ["size_in_bytes"],
            scalar: .integer(1_000_000_000)
        )

        #expect(presentation.displayedValue.contains("GB"))
        #expect(presentation.rawValue == "1000000000")
    }

    @Test
    func unknownFieldsRemainExplicitlyUnexplained() {
        let presentation = fieldPresentation(
            dataType: .hardware,
            path: ["future_apple_field"],
            scalar: .string("future_value")
        )

        #expect(presentation.title == "Future Apple Field")
        #expect(presentation.explanation == nil)
    }

    @Test
    func enumeratedTokensAreReadableButReportedNamesKeepTheirSpelling() {
        let token = fieldPresentation(
            dataType: .wifi,
            path: ["spairport_status_information"],
            scalar: .string("spairport_status_connected")
        )
        let mountPoint = fieldPresentation(
            dataType: .storage,
            path: ["mount_point"],
            scalar: .string("/Library/Developer/CoreSimulator/Volumes/iOS_23D8133")
        )
        let volumeName = fieldPresentation(
            dataType: .storage,
            path: ["_name"],
            scalar: .string("Backup_Disk")
        )

        #expect(token.displayedValue == "Spairport Status Connected")
        #expect(mountPoint.displayedValue == "/Library/Developer/CoreSimulator/Volumes/iOS_23D8133")
        #expect(volumeName.displayedValue == "Backup_Disk")
    }
}
