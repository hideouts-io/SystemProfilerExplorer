import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ReportFileLoadingTests {
    @Test
    func rawSystemProfilerJSONLoadsForViewingAndComparison() throws {
        let data = Data(#"{"SPSoftwareDataType":[{"_name":"os_overview","os_version":"macOS 27.0"}]}"#.utf8)
        let importedAt = Date(timeIntervalSince1970: 5_000)

        let viewable: SystemProfilerReport = try loadViewableReport(from: data, importedAt: importedAt)
        let baseline: SystemProfilerReport = try loadComparisonBaseline(from: data, importedAt: importedAt)

        #expect(viewable.sections.map(\.dataType) == [.software])
        #expect(baseline.sections == viewable.sections)
        #expect(baseline.completedAt == importedAt)
    }

    @Test
    func fullExportsLoadForViewingAndComparison() throws {
        let report: SystemProfilerReport = loadingReport()
        let data: Data = try encodeReportExport(makeFullReportExport(report))

        #expect(try loadViewableReport(from: data, importedAt: Date()) == report)
        #expect(try loadComparisonBaseline(from: data, importedAt: Date()) == report)
    }

    @Test
    func redactedExportsOpenForViewingButCannotBeCompared() throws {
        let data: Data = try encodeReportExport(makeRedactedReportExport(loadingReport()))
        let viewable: SystemProfilerReport = try loadViewableReport(from: data, importedAt: Date())

        #expect(viewable.sections.first?.items.first == .object(["os_version": .string(redactedProfileValue)]))
        #expect(throws: ReportComparisonError.redactedBaseline) {
            _ = try loadComparisonBaseline(from: data, importedAt: Date())
        }
    }

    @Test
    func redactedPlaceholdersAreNotExplainedAsValues() {
        #expect(valueExplanation(dataType: .software, path: ["system_integrity"], scalar: .string(redactedProfileValue)) == nil)
    }

    @Test
    func exportFilenamesUseTheJSONExtension() {
        let date = Date(timeIntervalSince1970: 0)

        #expect(fullReportExportFilename(completedAt: date).hasSuffix(".json"))
        #expect(redactedReportExportFilename(completedAt: date).hasSuffix(".json"))
    }
}

private func loadingReport() -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(dataType: .software, items: [.object(["os_version": .string("macOS 27.0")])])
        ],
        commandArguments: ["-json", "SPSoftwareDataType"],
        standardError: "",
        startedAt: Date(timeIntervalSince1970: 1_000),
        completedAt: Date(timeIntervalSince1970: 1_001)
    )
}
