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
