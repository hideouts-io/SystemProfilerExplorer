import Foundation
import Testing
@testable import SystemProfilerExplorer

struct RawReportImportTests {
    @Test
    func importsRecognizedSectionsAndIgnoresUnrelatedRootData() throws {
        let data: Data = Data(
            #"{"SPHardwareDataType":[{"_name":"Hardware","machine_model":"Mac00,0","nested":{"count":2}}],"unrelated":{"format":"metadata"}}"#.utf8
        )
        let importedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)

        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            data,
            importedAt: importedAt
        )

        #expect(report.sections.count == 1)
        #expect(report.sections[0].dataType == .hardware)
        #expect(report.sections[0].items.count == 1)
        #expect(report.commandArguments.isEmpty)
        #expect(report.standardError.isEmpty)
        #expect(report.startedAt == importedAt)
        #expect(report.completedAt == importedAt)
    }

    @Test
    func importedSectionsUseTheApplicationDataTypeOrder() throws {
        let data: Data = Data(
            #"{"SPPowerDataType":[],"SPHardwareDataType":[],"SPUSBHostDataType":[]}"#.utf8
        )

        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            data,
            importedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(report.sections.map(\.dataType) == [.hardware, .power, .usb])
    }

    @Test
    func rejectsJSONWithoutRecognizedSystemProfilerSections() {
        let data: Data = Data(#"{"metadata":{"format":"other"}}"#.utf8)

        #expect(throws: SystemProfilerParsingError.noSupportedDataTypes) {
            _ = try SystemProfilerParser().parseImportedReport(
                data,
                importedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }

    @Test
    func rejectsRecognizedSectionWithTheWrongJSONShape() {
        let data: Data = Data(#"{"SPHardwareDataType":{"machine_model":"Mac00,0"}}"#.utf8)

        #expect(
            throws: SystemProfilerParsingError.invalidDataTypeSection(
                identifier: SystemProfilerDataType.hardware.rawValue
            )
        ) {
            _ = try SystemProfilerParser().parseImportedReport(
                data,
                importedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }
}
