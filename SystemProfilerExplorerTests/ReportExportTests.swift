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
