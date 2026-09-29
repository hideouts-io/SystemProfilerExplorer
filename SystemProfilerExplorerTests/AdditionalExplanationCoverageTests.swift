import Testing
@testable import SystemProfilerExplorer

struct AdditionalExplanationCoverageTests {
    @Test
    func previouslyGenericDataTypesHaveContextualExplanations() {
        let fields: [(SystemProfilerDataType, [String], String)] = [
            (.audio, ["coreaudio_device_srate"], "48000"),
            (.camera, ["spcamera_unique-id"], "REDACTED"),
            (.cardReader, ["spcardreader_link-speed"], "8 GT/s"),
            (.diagnostics, ["diagnostic_status"], "Passed"),
            (.disabledSoftware, ["reason"], "Disabled"),
            (.discBurning, ["media_support"], "Supported"),
            (.displays, ["_spdisplays_resolution"], "3456 x 2234"),
            (.fibreChannel, ["firmware_version"], "1.0"),
            (.logs, ["contents"], "REDACTED"),
            (.memory, ["dimm_type"], "LPDDR5"),
            (.nvme, ["smart_status"], "Verified"),
            (.pci, ["vendor_id"], "0x0000"),
            (.parallelATA, ["device_model"], "Device"),
            (.parallelSCSI, ["device_revision"], "1.0"),
            (.printers, ["uri"], "REDACTED"),
            (.rawCamera, ["model"], "Camera"),
            (.sas, ["link_speed"], "12 Gb/s"),
            (.serialATA, ["device_serial"], "REDACTED"),
            (.spi, ["c_stfw_version"], "1.0"),
            (.thunderbolt, ["domain_uuid_key"], "REDACTED"),
            (.usb, ["USBKeyLocationID"], "REDACTED"),
            (.iBridge, ["ibridge_secure_boot"], "Enabled")
        ]

        for (dataType, path, value) in fields {
            #expect(explanation(for: dataType, path: path, reportedValue: value) != nil)
        }
    }

    @Test
    func identifiersAndLogContentsIncludePrivacyGuidance() throws {
        let cameraIdentifier = try #require(
            explanation(for: .camera, path: ["spcamera_unique-id"], reportedValue: "REDACTED")
        )
        let logContents = try #require(
            explanation(for: .logs, path: ["contents"], reportedValue: "REDACTED")
        )

        #expect(cameraIdentifier.privacy != nil)
        #expect(logContents.privacy != nil)
    }

    @Test
    func inventoryFieldsWithoutExplanationsNowHaveThem() {
        let fields: [(SystemProfilerDataType, [String], String)] = [
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "device_address"], "REDACTED"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "Left", "device_address"], "REDACTED"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "device_caseVersion"], "1.0"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "device_firmwareVersion"], "1.0"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "device_minorType"], "Headphones"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "device_productID"], "0x0000"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "Left", "device_rssi"], "-60"),
            (.bluetooth, ["device_not_connected", "[]", "Headphones", "device_serialNumber"], "REDACTED"),
            (.bluetooth, ["device_connected", "[]", "Keyboard", "device_vendorID"], "0x0000"),
            (.international, ["boot_kbd"], "REDACTED"),
            (.international, ["boot_locale"], "en-US"),
            (.international, ["user_assistant_voice_gender"], "REDACTED"),
            (.legacySoftware, ["process_identity", "identity_bundle_id"], "com.example.tool"),
            (.legacySoftware, ["process_identity", "identity_path"], "REDACTED"),
            (.legacySoftware, ["process_identity", "identity_team_id"], "ABCDE12345"),
            (.legacySoftware, ["process_identity", "identity_version"], "1.0"),
            (.legacySoftware, ["process_uid"], "501"),
            (.legacySoftware, ["responsible_identity", "identity_bundle_id"], "com.example.tool"),
            (.legacySoftware, ["responsible_identity", "identity_path"], "REDACTED"),
            (.legacySoftware, ["responsible_identity", "identity_team_id"], "ABCDE12345"),
            (.legacySoftware, ["responsible_identity", "identity_version"], "1.0")
        ]

        for (dataType, path, value) in fields {
            #expect(explanation(for: dataType, path: path, reportedValue: value) != nil, "\(dataType) \(path)")
        }
    }

    @Test
    func accessoryIdentifiersIncludePrivacyGuidance() throws {
        let address = try #require(
            explanation(for: .bluetooth, path: ["device_connected", "[]", "Mouse", "device_address"], reportedValue: "REDACTED")
        )
        let serial = try #require(
            explanation(for: .bluetooth, path: ["device_connected", "[]", "Mouse", "device_serialNumber"], reportedValue: "REDACTED")
        )

        #expect(address.privacy != nil)
        #expect(serial.privacy != nil)
    }

    @Test
    func legacyIdentityFieldsDistinguishProcessFromResponsibleSoftware() throws {
        let process = try #require(
            explanation(for: .legacySoftware, path: ["process_identity", "identity_team_id"], reportedValue: "ABCDE12345")
        )
        let responsible = try #require(
            explanation(for: .legacySoftware, path: ["responsible_identity", "identity_team_id"], reportedValue: "ABCDE12345")
        )

        #expect(process.title == "Process Team Identifier")
        #expect(responsible.title == "Responsible Team Identifier")
    }

    @Test
    func unknownFieldsReceiveDataTypeSpecificContext() throws {
        let fieldExplanation = try #require(
            explanation(for: .usb, path: ["future_apple_field"], reportedValue: "future_value")
        )

        #expect(fieldExplanation.meaning.contains("USB host-controller topology"))
        #expect(fieldExplanation.interpretation.contains("Schema names"))
    }
}
