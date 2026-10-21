import Foundation
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

    @Test
    func importedCameraIdentifiersKeepEvidenceAndTruthfulCoverage() throws {
        let fixture: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Compatibility/camera-identifiers.json")
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            Data(contentsOf: fixture), importedAt: Date(timeIntervalSince1970: 3_000)
        )
        let findings: [SystemReviewFinding] = systemReviewFindings(report)
        let identifiers: [(String, String)] = [
            ("spcamera_model-id", "synthetic_camera_model"),
            ("spcamera_unique-id", "synthetic_camera_unit_enabled")
        ]
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        #expect(index.summary.privacyFindingCount == 2)

        for (key, value) in identifiers {
            let finding: SystemReviewFinding = try #require(findings.first {
                $0.location == "SPCameraDataType[0].\(key)"
            })
            #expect(finding.coverage == .curatedField)
            #expect(finding.presentation.rawValue == value)
            #expect(finding.presentation.displayedValue == value)
            #expect(finding.presentation.searchableValueTexts.allSatisfy { $0 == value })
            #expect(finding.presentation.explanation?.privacy != nil)
            let address: ProfileValueAddress = ProfileValueAddress(
                dataType: .camera, path: [.index(0), .field(key)]
            )
            #expect(try profileValue(at: address, in: report) == .string(value))
            #expect(try index.queryResult(for: FindingQuery(text: value, filter: .privacy)).findingCount == 1)
            #expect(!hasValueRule(dataType: .camera, path: [key]))
            #expect(valueExplanation(dataType: .camera, path: [key], scalar: .string(value)) == nil)
            #expect(!plainEnglishFieldIsSupported(dataType: .camera, path: [key]))
            #expect(throws: PlainEnglishExplanationError.unsupportedField) {
                try plainEnglishExplanationInput(dataType: .camera, path: [key])
            }
        }
        let unknown: SystemReviewFinding = try #require(findings.first {
            $0.location == "SPCameraDataType[0].future_camera_field"
        })
        #expect(unknown.coverage == .generalDataTypeContext)
        let full: ReportExportEnvelope = try decodeReportExport(encodeReportExport(makeFullReportExport(report)))
        #expect(full.report.sections == report.sections)
        let redacted: String = String(decoding: try encodeReportExport(makeRedactedReportExport(report)), as: UTF8.self)
        let sample: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            encodeAnonymizedSample(makeAnonymizedSample(report)), importedAt: Date(timeIntervalSince1970: 3_001)
        )
        for (key, value) in identifiers {
            #expect(!redacted.contains(value))
            #expect(try profileValue(at: ProfileValueAddress(dataType: .camera, path: [.index(0), .field(key)]), in: sample)
                == .string(anonymizedSampleRemovedValue))
        }
    }

    @Test(arguments: [
        ProfileScalar.string("synthetic_camera_id"), .string("synthetic_camera_enabled"),
        .string("true"), .string("no"), .string(""), .string("invented é界 🧑‍💻 identifier"),
        .integer(987_654), .decimal(98_765.125), .boolean(true), .null
    ])
    func cameraIdentifierScalarsStayOpaqueAndAreRemovedFromSamples(scalar: ProfileScalar) throws {
        let keys: [String] = ["spcamera_model-id", "spcamera_unique-id"]
        let record: ProfileValue = .object(Dictionary(uniqueKeysWithValues: keys.map {
            ($0, cameraTestValue(scalar))
        }))
        let report: SystemProfilerReport = try cameraTestReport(record)
        let full: ReportExportEnvelope = try decodeReportExport(encodeReportExport(makeFullReportExport(report)))
        #expect(full.report.sections == report.sections)
        let sample: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            encodeAnonymizedSample(makeAnonymizedSample(report)), importedAt: Date(timeIntervalSince1970: 3_001)
        )

        for key in keys {
            let finding: SystemReviewFinding = try #require(systemReviewFindings(report).first {
                $0.presentation.sourcePath == "SPCameraDataType.\(key)"
            })
            #expect(finding.coverage == .curatedField)
            #expect(finding.presentation.rawValue == scalar.rawDescription)
            #expect(finding.presentation.displayedValue == scalar.rawDescription)
            #expect(valueExplanation(dataType: .camera, path: [key], scalar: scalar) == nil)
            #expect(try profileValue(at: ProfileValueAddress(dataType: .camera, path: [.index(0), .field(key)]), in: sample)
                == .string(anonymizedSampleRemovedValue))
        }
    }

    @Test
    func cameraLiteralKeysAndUnexpectedContainersKeepStructuredBoundaries() throws {
        let report: SystemProfilerReport = try cameraTestReport(.object([
            "_items": .array([.object([
                "spcamera_model-id": .string("nested_camera_model"),
                "spcamera_unique-id": .string("nested_camera_yes"),
                "future.spcamera_model-id": .string("literal_camera_token"),
                "SPCamera_unique-id": .string("case_camera_token")
            ])]),
            "spcamera_model-id": .object([
                "part": .integer(654_321), "flag": .boolean(true),
                "physical_memory": .string("embedded_camera_enabled")
            ]),
            "spcamera_unique-id": .array([.string("array_camera_token"), .decimal(65_432.75), .null])
        ]))
        let findings: [SystemReviewFinding] = systemReviewFindings(report)
        #expect(findings.filter { $0.coverage == .curatedField }.count == 2)
        for key in ["future.spcamera_model-id", "SPCamera_unique-id"] {
            let finding: SystemReviewFinding = try #require(findings.first {
                $0.location == "SPCameraDataType[0]._items.[0].\(key)"
            })
            #expect(finding.coverage == .generalDataTypeContext)
        }
        let literal: ProfileValueAddress = ProfileValueAddress(
            dataType: .camera, path: [.index(0), .field("_items"), .index(0), .field("future.spcamera_model-id")]
        )
        #expect(try profileValue(at: literal, in: report) == .string("literal_camera_token"))
        #expect(try decodeReportExport(encodeReportExport(makeFullReportExport(report))).report.sections == report.sections)
        let sample: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            encodeAnonymizedSample(makeAnonymizedSample(report)), importedAt: Date(timeIntervalSince1970: 3_001)
        )
        for key in ["<name 1>", "<name 2>", "<name 3>"] {
            let address: ProfileValueAddress = ProfileValueAddress(
                dataType: .camera, path: [.index(0), .field("spcamera_model-id"), .field(key)]
            )
            #expect(try profileValue(at: address, in: sample) == .string(anonymizedSampleRemovedValue))
        }
        for index in 0..<3 {
            let address: ProfileValueAddress = ProfileValueAddress(
                dataType: .camera, path: [.index(0), .field("spcamera_unique-id"), .index(index)]
            )
            #expect(try profileValue(at: address, in: sample) == .string(anonymizedSampleRemovedValue))
        }
        let empty: SystemProfilerReport = try cameraTestReport(.object([:]))
        #expect(systemReviewFindings(empty).isEmpty)
        #expect(throws: ProfileValueAddressError.missingField) {
            try profileValue(at: ProfileValueAddress(dataType: .camera, path: [.index(0), .field("spcamera_unique-id")]), in: empty)
        }
        #expect(throws: SystemProfilerParsingError.invalidDataTypeSection(identifier: "SPCameraDataType")) {
            try SystemProfilerParser().parseImportedReport(
                Data(#"{"SPCameraDataType":{}}"#.utf8), importedAt: Date(timeIntervalSince1970: 3_000)
            )
        }
    }

    @Test
    func opaqueCameraObjectKeysAreRemovedWithoutCollisionsOrRepeatedChanges() throws {
        let privateKey: String = "synthetic_private_camera_identifier"
        let report: SystemProfilerReport = try cameraTestReport(.object([
            "spcamera_unique-id": .object([
                "<name 2>": .array([.integer(7), .null]),
                "physical_memory": .string("synthetic_camera_enabled"),
                privateKey: .object(["nested_private_camera_key": .boolean(true)])
            ])
        ]))
        let original: ProfileValueAddress = ProfileValueAddress(
            dataType: .camera,
            path: [.index(0), .field("spcamera_unique-id"), .field(privateKey), .field("nested_private_camera_key")]
        )
        #expect(try profileValue(at: original, in: report) == .boolean(true))
        #expect(try decodeReportExport(encodeReportExport(makeFullReportExport(report))).report.sections == report.sections)
        let redactedBytes: Data = try encodeReportExport(makeRedactedReportExport(report))
        let redactedText: String = String(decoding: redactedBytes, as: UTF8.self)
        #expect(!redactedText.contains(privateKey))
        #expect(!redactedText.contains("nested_private_camera_key"))
        #expect(!redactedText.contains("physical_memory"))
        let redacted: ReportExportEnvelope = try decodeReportExport(redactedBytes)
        #expect(redacted.redactedValueCount == 4)
        #expect(redacted.report.sections[0].items == [.object([
            "spcamera_unique-id": .object([
                "[REDACTED] 1": .array([.string(redactedProfileValue), .string(redactedProfileValue)]),
                "[REDACTED] 2": .string(redactedProfileValue),
                "[REDACTED] 3": .object(["[REDACTED] 1": .string(redactedProfileValue)])
            ])
        ])])
        let sampleBytes: Data = try encodeAnonymizedSample(makeAnonymizedSample(report))
        let sampleText: String = String(decoding: sampleBytes, as: UTF8.self)
        #expect(!sampleText.contains(privateKey))
        #expect(!sampleText.contains("nested_private_camera_key"))
        #expect(!sampleText.contains("physical_memory"))
        let sample: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            sampleBytes, importedAt: Date(timeIntervalSince1970: 3_001)
        )
        let identifier: ProfileValue = try profileValue(
            at: ProfileValueAddress(dataType: .camera, path: [.index(0), .field("spcamera_unique-id")]), in: sample
        )
        #expect(identifier == .object([
            "<name 1>": .string(anonymizedSampleRemovedValue),
            "<name 2>": .array([.string(anonymizedSampleRemovedValue), .string(anonymizedSampleRemovedValue)]),
            "<name 3>": .object(["<name 1>": .string(anonymizedSampleRemovedValue)])
        ]))
        #expect(try encodeAnonymizedSample(makeAnonymizedSample(sample)) == sampleBytes)
    }
}

private func cameraTestReport(_ record: ProfileValue) throws -> SystemProfilerReport {
    let payload: [String: [ProfileValue]] = ["SPCameraDataType": [record]]
    return try SystemProfilerParser().parseImportedReport(
        JSONEncoder().encode(payload), importedAt: Date(timeIntervalSince1970: 3_000)
    )
}

private func cameraTestValue(_ scalar: ProfileScalar) -> ProfileValue {
    switch scalar {
    case let .string(value): .string(value)
    case let .integer(value): .integer(value)
    case let .decimal(value): .decimal(value)
    case let .boolean(value): .boolean(value)
    case .null: .null
    }
}
