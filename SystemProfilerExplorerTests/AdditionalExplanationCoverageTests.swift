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
    func unknownFieldsReceiveDataTypeSpecificContext() throws {
        let fieldExplanation = try #require(
            explanation(for: .usb, path: ["future_apple_field"], reportedValue: "future_value")
        )

        #expect(fieldExplanation.meaning.contains("USB host-controller topology"))
        #expect(fieldExplanation.interpretation.contains("Schema names"))
    }
}
