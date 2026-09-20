import Foundation
import Testing
@testable import SystemProfilerExplorer

struct CollectionCoverageTests {
    @Test
    func liveCoverageDistinguishesCollectedEmptyAndSkippedDataTypes() {
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [
                SystemProfilerSection(
                    dataType: .hardware,
                    items: [.object(["machine_model": .string("Mac00,0")])]
                ),
                SystemProfilerSection(dataType: .storage, items: [])
            ],
            commandArguments: SystemProfilerRequest(
                dataTypes: [.hardware, .storage, .wifi],
                detailLevel: .full,
                timeoutSeconds: 90
            ).arguments,
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001)
        )

        let coverage: CollectionCoverage = collectionCoverage(for: report)

        #expect(coverage.source == .liveScan)
        #expect(coverage.collectedCount == 1)
        #expect(coverage.emptyCount == 1)
        #expect(coverage.skippedEntries.map(\.dataType) == [.wifi])
        #expect(coverage.entries.map(\.status) == [.collected, .empty, .skipped])
    }

    @Test
    func importedCoverageDoesNotInventSkippedDataTypes() {
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [
                SystemProfilerSection(dataType: .hardware, items: [])
            ],
            commandArguments: [],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001)
        )

        let coverage: CollectionCoverage = collectionCoverage(for: report)

        #expect(coverage.source == .importedReport)
        #expect(coverage.emptyCount == 1)
        #expect(coverage.skippedCount == 0)
    }

    @Test
    func liveParserPreservesAReportWhenARequestedDataTypeIsNotReturned() throws {
        let request: SystemProfilerRequest = SystemProfilerRequest(
            dataTypes: [.hardware, .storage],
            detailLevel: .full,
            timeoutSeconds: 90
        )
        let execution: SystemProfilerExecution = SystemProfilerExecution(
            request: request,
            standardOutput: Data(#"{"SPHardwareDataType":[{"machine_model":"Mac00,0"}]}"#.utf8),
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001)
        )

        let report: SystemProfilerReport = try SystemProfilerParser().parse(execution)
        let coverage: CollectionCoverage = collectionCoverage(for: report)

        #expect(report.sections.map(\.dataType) == [.hardware])
        #expect(coverage.skippedEntries.map(\.dataType) == [.storage])
    }

    @Test
    func missingSectionsUseOnlyDiagnosticBackedHealthLabels() {
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [],
            commandArguments: ["SPAirPortDataType", "SPPowerDataType", "-json"],
            standardError: "operation not permitted while collecting profiler data",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001)
        )

        let coverage: CollectionCoverage = collectionCoverage(for: report)

        #expect(coverage.permissionLimitedCount == 2)
        #expect(coverage.incompleteEntries.count == 2)
        #expect(coverage.entries.allSatisfy { $0.status == .permissionLimited })
    }
}
