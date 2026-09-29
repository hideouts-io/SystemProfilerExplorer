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
        let data: Data = try encodeAnonymizedSample(makeAnonymizedSample(report))
        let opened: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(data, importedAt: Date())

        #expect(Set(opened.sections.map(\.dataType)) == Set(report.sections.map(\.dataType)))
        #expect(anonymizedSampleFilename(report) == "Sample-Mac15,3-macOS-26.0.sample.json")
        #expect(anonymizedSampleFilename(SystemProfilerReport(sections: [], commandArguments: [], standardError: "", startedAt: Date(), completedAt: Date())) == "Sample.sample.json")
    }
}
