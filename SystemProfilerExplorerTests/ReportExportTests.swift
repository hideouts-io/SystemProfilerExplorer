import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ReportExportTests {
    @Test
    func fullExportRoundTripsExactProfilerValuesAndMetadata() throws {
        let report: SystemProfilerReport = sampleReport()
        let export: ReportExportEnvelope = makeFullReportExport(report)
        let data: Data = try encodeReportExport(export)
        let decoded: ReportExportEnvelope = try decodeReportExport(data)

        #expect(decoded.privacy == .full)
        #expect(decoded.summary == reportSummary(report))
        #expect(decoded.redactedValueCount == 0)
        #expect(decoded.report.sections == report.sections)
        #expect(decoded.report.commandArguments == report.commandArguments)
        #expect(decoded.report.standardError == report.standardError)
        #expect(decoded.report.startedAt == report.startedAt)
        #expect(decoded.report.completedAt == report.completedAt)
    }

    @Test
    func redactedExportRemovesEveryScalarAndSensitiveMetadata() throws {
        let report: SystemProfilerReport = sampleReport()
        let export: ReportExportEnvelope = makeRedactedReportExport(report)
        let data: Data = try encodeReportExport(export)
        let encodedText: String = String(decoding: data, as: UTF8.self)
        let decoded: ReportExportEnvelope = try decodeReportExport(data)

        #expect(!encodedText.contains("Example User Mac"))
        #expect(!encodedText.contains("SECRET-SERIAL-123"))
        #expect(!encodedText.contains("private-user-path"))
        #expect(decoded.privacy == .redacted)
        #expect(decoded.summary == reportSummary(report))
        #expect(decoded.redactedValueCount == 6)
        #expect(decoded.report.standardError == nil)
        #expect(decoded.report.startedAt == nil)
        #expect(decoded.report.completedAt == nil)
        #expect(decoded.report.sections.allSatisfy(sectionIsFullyRedacted))
    }

    @Test
    func redactedExportRemovesNamesUsedAsDictionaryKeys() throws {
        let report = SystemProfilerReport(
            sections: [
                SystemProfilerSection(
                    dataType: .bluetooth,
                    items: [
                        .object([
                            "controller_properties": .object(["controller_state": .string("attrib_on")]),
                            "device_not_connected": .array([
                                .object(["Alex’s AirPods Pro": .object(["device_minorType": .string("Headphones")])]),
                                .object(["Keyboard": .object(["device_vendorID": .string("0x004C")])])
                            ])
                        ])
                    ]
                ),
                SystemProfilerSection(
                    dataType: .firewall,
                    items: [
                        .object([
                            "spfirewall_applications": .object([
                                "ABCDE12345.com.example.helper": .string("spfirewall_block_all"),
                                "Dropbox": .string("spfirewall_allow_all")
                            ]),
                            "spfirewall_globalstate": .string("spfirewall_globalstate_limit_connections")
                        ])
                    ]
                )
            ],
            commandArguments: ["-json", "SPBluetoothDataType", "SPFirewallDataType"],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_005)
        )

        let data: Data = try encodeReportExport(makeRedactedReportExport(report))
        let encodedText: String = String(decoding: data, as: UTF8.self)
        let decoded: ReportExportEnvelope = try decodeReportExport(data)

        for name in ["AirPods", "Alex", "Keyboard", "ABCDE12345", "com.example.helper", "Dropbox"] {
            #expect(!encodedText.contains(name), "Redacted export still contains \(name)")
        }

        #expect(encodedText.contains("controller_state"))
        #expect(encodedText.contains("device_minorType"))
        #expect(encodedText.contains("spfirewall_globalstate"))
        #expect(decoded.report.sections.allSatisfy(sectionIsFullyRedacted))
    }

    @Test
    func decoderRejectsUnsupportedReportFormatVersion() throws {
        let validExport: ReportExportEnvelope = makeFullReportExport(sampleReport())
        let unsupportedExport = ReportExportEnvelope(
            formatIdentifier: validExport.formatIdentifier,
            formatVersion: 99,
            privacy: validExport.privacy,
            summary: validExport.summary,
            redactedValueCount: validExport.redactedValueCount,
            report: validExport.report
        )
        let data: Data = try encodeReportExport(unsupportedExport)

        #expect(throws: ReportExportError.unsupportedVersion(version: 99)) {
            _ = try decodeReportExport(data)
        }
    }
}

private func sampleReport() -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(
                dataType: .hardware,
                items: [
                    .object([
                        "_name": .string("Example User Mac"),
                        "serial_number": .string("SECRET-SERIAL-123"),
                        "enabled": .boolean(true),
                        "metrics": .array([
                            .integer(42),
                            .decimal(3.5),
                            .null
                        ])
                    ])
                ]
            )
        ],
        commandArguments: ["SPHardwareDataType", "-json", "-detailLevel", "mini"],
        standardError: "warning at <private-user-path>",
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        completedAt: Date(timeIntervalSince1970: 1_700_000_005)
    )
}

private func sectionIsFullyRedacted(_ section: SystemProfilerSection) -> Bool {
    section.items.allSatisfy(profileValueIsFullyRedacted)
}

private func profileValueIsFullyRedacted(_ value: ProfileValue) -> Bool {
    switch value {
    case let .object(object):
        object.values.allSatisfy(profileValueIsFullyRedacted)
    case let .array(values):
        values.allSatisfy(profileValueIsFullyRedacted)
    case let .string(value):
        value == redactedProfileValue
    case .integer, .decimal, .boolean, .null:
        false
    }
}

struct AnonymizedSampleTests {
    private let report = SystemProfilerReport(
        sections: [
            SystemProfilerSection(
                dataType: .hardware,
                items: [
                    .object([
                        "_name": .string("hardware_overview"),
                        "machine_model": .string("Mac15,3"),
                        "serial_number": .string("SECRET-SERIAL-123"),
                        "platform_UUID": .string("8C1A2B3C-1111-2222-3333-444455556666"),
                        "activation_lock_status": .string("activation_lock_enabled"),
                        "number_processors": .string("proc 14:0:10:4")
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .software,
                items: [
                    .object([
                        "os_version": .string("macOS 26.0 (25A354)"),
                        "user_name": .string("alex_smith"),
                        "local_host_name": .string("Alexs-MacBook-Pro"),
                        "uptime": .string("up 0:1:17:52")
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .wifi,
                items: [
                    .object([
                        "spairport_airport_interfaces": .array([
                            .object([
                                "_name": .string("en0"),
                                "spairport_wireless_mac_address": .string("a4:83:e7:12:34:56"),
                                "spairport_current_network_information": .object([
                                    "_name": .string("Home Network"),
                                    "spairport_network_channel": .string("36 (5GHz, 160MHz)"),
                                    "spairport_security_mode": .string("spairport_security_mode_wpa3_personal")
                                ])
                            ])
                        ])
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .storage,
                items: [
                    .object([
                        "_name": .string("Alex’s Drive"),
                        "mount_point": .string("/Volumes/Alex’s Drive"),
                        "free_space_in_bytes": .integer(123_456),
                        "writable": .string("yes"),
                        "file_system": .string("APFS")
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .bluetooth,
                items: [
                    .object([
                        "device_not_connected": .array([
                            .object(["Alex’s AirPods Pro": .object(["device_minorType": .string("Headphones")])])
                        ])
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .syncServices,
                items: [
                    .object([
                        "_items": .array([
                            .object([
                                "description": .string("system_log_description"),
                                "contents": .string("Sep 19 15:26:50 syncd[88]: account alex@example.com")
                            ])
                        ])
                    ])
                ]
            )
        ],
        commandArguments: ["-json"],
        standardError: "private diagnostic text",
        startedAt: Date(timeIntervalSince1970: 1_000),
        completedAt: Date(timeIntervalSince1970: 1_001)
    )

    @Test
    func removesPersonalValuesAndKeepsWhatExplanationsNeed() throws {
        let data: Data = try encodeAnonymizedSample(makeAnonymizedSample(report))
        let text: String = String(decoding: data, as: UTF8.self)

        for removed in ["SECRET-SERIAL-123", "8C1A2B3C", "alex_smith", "Alexs-MacBook-Pro", "a4:83:e7",
                        "Home Network", "Alex’s", "alex@example.com", "private diagnostic text"] {
            #expect(!text.contains(removed), "\(removed) was kept")
        }

        for kept in ["hardware_overview", "Mac15,3", "activation_lock_enabled", "proc 14:0:10:4", "macOS 26.0 (25A354)",
                     "up 0:1:17:52", "36 (5GHz, 160MHz)", "spairport_security_mode_wpa3_personal", "123456",
                     "\"yes\"", "APFS", "device_minorType", "<name 1>", "system_log_description", anonymizedSampleRemovedLog] {
            #expect(text.contains(kept), "\(kept) was removed")
        }
    }

    @Test
    func samplesOpenAsSystemProfilerJSON() throws {
        let sample: [String: [ProfileValue]] = makeAnonymizedSample(report)
        let data: Data = try encodeAnonymizedSample(sample)
        let opened: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(data, importedAt: Date())

        #expect(Set(opened.sections.map(\.dataType)) == Set(report.sections.map(\.dataType)))
        // Anonymizing a sample again changes nothing, which the sample tests rely on.
        #expect(makeAnonymizedSample(opened) == sample)
        #expect(anonymizedSampleFilename(report) == "Sample-Mac15,3-macOS-26.0.sample.json")
        #expect(anonymizedSampleFilename(SystemProfilerReport(sections: [], commandArguments: [], standardError: "", startedAt: Date(), completedAt: Date())) == "Sample.sample.json")
    }
}

struct BluetoothAccessorySamplePrivacyTests {
    @Test
    func unknownAccessoryTypesAndInvalidBatteriesAreRemovedFromImportedSamples() throws {
        let fields: [String] = [
            "device_minorType", "device_batteryLevelMain", "device_batteryLevelLeft",
            "device_batteryLevelRight", "device_batteryLevelCase"
        ]
        let values: [String] = [
            "Example Private Owner", "Private project notes", "private_owner_token", "yes", "",
            "Toaster", "Headphones extra", "101%", "-1%", "+85%", "85", "85garbage%",
            "85.5%", "8 5%", "85%%", "８５%", "85\n%", "999999999999999999999999%"
        ]
        let records: [[String: ProfileValue]] = fields.flatMap { field in
            values.map { value in [field: .string(value)] }
        }
        let expected: [[String: ProfileValue]] = records.map { record in
            record.mapValues { _ in .string(anonymizedSampleRemovedValue) }
        }

        try verifyImportedSample(dataType: .bluetooth, records: records, expected: expected)
    }

    @Test
    func unknownOrMalformedServiceListsAreRemovedAsAWholeFromImportedSamples() throws {
        let fields: [String] = ["device_services", "controller_supportedServices"]
        let values: [String] = [
            "0x1 < A2DP Alice Smith >", "0x1 < A2DP private_owner_token >",
            "< A2DP XYZ >", "0x3 < XYZ >", "Private project notes", "private_owner_token", "yes",
            "", "< >", "0x1 < >", "0x < A2DP >", "0xG < A2DP >", "0xa\u{200d} < A2DP >",
            "0xa\u{FE0F} < A2DP >", "0x1 < A2DP > trailing", "0x1 < < A2DP >", "0x1 < A2DP > >"
        ]
        let records: [[String: ProfileValue]] = fields.flatMap { field in
            values.map { value in [field: .string(value)] }
        }
        let expected: [[String: ProfileValue]] = records.map { record in
            record.mapValues { _ in .string(anonymizedSampleRemovedValue) }
        }

        try verifyImportedSample(dataType: .bluetooth, records: records, expected: expected)
    }

    @Test
    func recognizedAccessoryValuesSurviveImportedSampleSerializationExactly() throws {
        let types: [String] = ["Headphones", "Headset", "Keyboard", "Mouse", "Trackpad", "Speaker", "Gamepad", "headphones"]
        let batteryFields: [String] = [
            "device_batteryLevelMain", "device_batteryLevelLeft", "device_batteryLevelRight", "device_batteryLevelCase"
        ]
        let percentages: [String] = ["0%", "10%", "11%", "20%", "21%", "100%", " 85% ", "85 %", "85\u{00A0}%"]
        let services: [String] = [
            "0x400000 < BLE >", "0xAB < A2DP AVRCP HFP HSP HID BRAILLE GATT BLE SERIALPORT SERIAL PAN AACP >",
            "< A2DP AVRCP >", " 0x1 < a2dp A2DP > \n"
        ]
        let records: [[String: ProfileValue]] = types.map { ["device_minorType": .string($0)] }
            + batteryFields.flatMap { field in percentages.map { [field: .string($0)] } }
            + ["device_services", "controller_supportedServices"].flatMap { field in
                services.map { [field: .string($0)] }
            }

        try verifyImportedSample(dataType: .bluetooth, records: records, expected: records)
    }

    @Test
    func otherFieldsKeepExistingSampleTokenBooleanAndNumberConventions() throws {
        let records: [[String: ProfileValue]] = [[
            "controller_state": .string("attrib_future_state"),
            "future_field": .string("future_value"),
            "future_boolean": .string("yes"),
            "device_vendorID": .string("0x004C"),
            "device_rssi": .integer(-42)
        ]]

        try verifyImportedSample(dataType: .bluetooth, records: records, expected: records)
    }
}

struct DriveAndMediaSamplePrivacyTests {
    @Test(arguments: [
        (SystemProfilerDataType.serialATA, "spsata_physical_interconnect"),
        (.discBurning, "device_cdwrite"),
        (.cardReader, "file_system")
    ])
    func unrecognizedDriveAndMediaFreeTextIsRemovedFromImportedSamples(
        _ dataType: SystemProfilerDataType,
        _ field: String
    ) throws {
        let values: [String] = ["Example Private Owner", "Private project notes", "SATA extra", "-R, +RW"]
        let records: [[String: ProfileValue]] = values.map { [field: .string($0)] }
        let expected: [[String: ProfileValue]] = values.map { _ in [field: .string(anonymizedSampleRemovedValue)] }

        try verifyImportedSample(dataType: dataType, records: records, expected: expected)
    }

    @Test(arguments: [
        (SystemProfilerDataType.serialATA, "spsata_physical_interconnect", "SATA"),
        (.discBurning, "device_cdwrite", "-R, -RW"),
        (.cardReader, "file_system", "APFS")
    ])
    func recognizedDriveAndMediaValuesAndExistingTokenConventionsSurviveExactly(
        _ dataType: SystemProfilerDataType,
        _ field: String,
        _ recognized: String
    ) throws {
        let records: [[String: ProfileValue]] = [recognized, "future_value", "yes"].map { [field: .string($0)] }

        try verifyImportedSample(dataType: dataType, records: records, expected: records)
    }
}

private func verifyImportedSample(
    dataType: SystemProfilerDataType,
    records: [[String: ProfileValue]],
    expected: [[String: ProfileValue]]
) throws {
    let items: [ProfileValue] = records.map { .object($0) }
    let expectedItems: [ProfileValue] = expected.map { .object($0) }
    let payload: [String: [ProfileValue]] = [dataType.rawValue: items]
    let input: Data = try JSONEncoder().encode(payload)
    let importedAt: Date = Date(timeIntervalSince1970: 3_000)
    let imported: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(input, importedAt: importedAt)
    #expect(imported.sections == [SystemProfilerSection(dataType: dataType, items: items)])

    let expectedSample: [String: [ProfileValue]] = [dataType.rawValue: expectedItems]
    let data: Data = try encodeAnonymizedSample(makeAnonymizedSample(imported))
    let decoded: [String: [ProfileValue]] = try JSONDecoder().decode([String: [ProfileValue]].self, from: data)
    #expect(decoded == expectedSample)
    #expect(data == (try encodeAnonymizedSample(expectedSample)))

    let reopened: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(data, importedAt: importedAt)
    #expect(reopened.sections == [SystemProfilerSection(dataType: dataType, items: expectedItems)])
    #expect(makeAnonymizedSample(reopened) == expectedSample)

    let full: ReportExportEnvelope = try decodeReportExport(encodeReportExport(makeFullReportExport(imported)))
    #expect(full.report.sections == imported.sections)
    #expect(full.redactedValueCount == 0)
}
