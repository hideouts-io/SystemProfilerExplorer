import Foundation
import Testing
@testable import SystemProfilerExplorer

struct FindingQueryTests {
    @Test
    func summaryCountsRecordsFindingsExplanationsAndPrivacyGuidance() {
        let summary: ReportSummary = reportSummary(sampleReport())

        #expect(summary.recordCount == 2)
        #expect(summary.findingCount == 7)
        #expect(summary.explainedFindingCount == 6)
        #expect(summary.privacyFindingCount == 2)
    }

    @Test
    func searchIncludesDetailedExplanationText() {
        let query = FindingQuery(text: "unified memory", filter: .all)

        #expect(matchingFindingCount(sampleReport(), query: query) == 1)
    }

    @Test
    func privacyFilterReturnsOnlyFindingsWithPrivacyGuidance() {
        let query = FindingQuery(text: "", filter: .privacy)

        #expect(matchingFindingCount(sampleReport(), query: query) == 2)
    }

    @Test
    func explainedFilterExcludesUnknownFieldsWithoutHidingThemFromAllFindings() {
        let allQuery = FindingQuery(text: "future value", filter: .all)
        let explainedQuery = FindingQuery(text: "future value", filter: .explained)

        #expect(matchingFindingCount(sampleReport(), query: allQuery) == 1)
        #expect(matchingFindingCount(sampleReport(), query: explainedQuery) == 0)
    }

    @Test
    func recordNameSearchIncludesThatRecordsDescendants() {
        let query = FindingQuery(text: "Mac Studio", filter: .all)

        #expect(matchingFindingCount(sampleReport(), query: query) == 4)
    }

    @Test
    func unmatchedSearchReturnsNoFindings() {
        let query = FindingQuery(text: "not present in the report", filter: .all)

        #expect(matchingFindingCount(sampleReport(), query: query) == 0)
    }

    @Test
    func inactiveQueryPagesRecordsWithoutDroppingTheTotalCount() {
        let section: SystemProfilerSection = sampleReport().sections[0]
        let selection: MatchingRecordSelection = matchingRecordSelection(
            items: section.items + section.items + section.items,
            dataType: section.dataType,
            query: FindingQuery(text: "", filter: .all),
            visibleLimit: 2
        )

        #expect(selection.visibleIndices == [0, 1])
        #expect(selection.matchingCount == 3)
    }

    @Test
    func activeQueryCountsAllMatchesWhilePagingVisibleRecords() {
        let items: [ProfileValue] = [
            .object(["_name": .string("First"), "serial_number": .string("MATCH")]),
            .object(["_name": .string("Second"), "serial_number": .string("MATCH")]),
            .object(["_name": .string("Third"), "serial_number": .string("OTHER")])
        ]
        let selection: MatchingRecordSelection = matchingRecordSelection(
            items: items,
            dataType: .hardware,
            query: FindingQuery(text: "MATCH", filter: .all),
            visibleLimit: 1
        )

        #expect(selection.visibleIndices == [0])
        #expect(selection.matchingCount == 2)
    }
}

private func sampleReport() -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(
                dataType: .hardware,
                items: [
                    .object([
                        "_name": .string("Mac Studio"),
                        "physical_memory": .string("32 GB"),
                        "serial_number": .string("REDACTED"),
                        "chip_type": .string("Apple M4 Max"),
                        "future_apple_field": .string("future_value")
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .storage,
                items: [
                    .object([
                        "_name": .string("Macintosh HD"),
                        "size_in_bytes": .integer(1_000_000_000),
                        "volume_uuid": .string("REDACTED"),
                        "writable": .string("yes")
                    ])
                ]
            )
        ],
        commandArguments: ["SPHardwareDataType", "SPStorageDataType", "-json"],
        standardError: "",
        startedAt: Date(timeIntervalSince1970: 1_000),
        completedAt: Date(timeIntervalSince1970: 1_001)
    )
}
