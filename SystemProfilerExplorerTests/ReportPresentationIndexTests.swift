import Foundation
import Testing
@testable import SystemProfilerExplorer

private let performanceFixturePath: String? = ProcessInfo.processInfo.environment[
    "SYSTEM_PROFILER_PERFORMANCE_FIXTURE"
]

struct ReportPresentationIndexTests {
    @Test
    func indexedSummaryAndQueriesMatchRecursiveBehavior() throws {
        let report: SystemProfilerReport = representativeReport()
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        let queries: [FindingQuery] = [
            FindingQuery(text: "", filter: .all),
            FindingQuery(text: "unified memory", filter: .all),
            FindingQuery(text: "Mac Studio", filter: .all),
            FindingQuery(text: "Mac Studio", filter: .explained),
            FindingQuery(text: "future value", filter: .explained),
            FindingQuery(text: "String Values", filter: .all),
            FindingQuery(text: "Item 1", filter: .all),
            FindingQuery(text: "", filter: .privacy)
        ]

        #expect(index.summary == reportSummary(report))

        for query in queries {
            let indexedResult: ReportQueryResult = try index.queryResult(for: query)
            let recursiveCount: Int = matchingFindingCount(report, query: query)

            #expect(indexedResult.findingCount == recursiveCount)

            for section in report.sections {
                let indexedSelection: MatchingRecordSelection = indexedResult.recordSelection(
                    for: section.dataType,
                    visibleLimit: 100
                )
                let recursiveSelection: MatchingRecordSelection = matchingRecordSelection(
                    items: section.items,
                    dataType: section.dataType,
                    query: query,
                    visibleLimit: 100
                )

                #expect(indexedSelection == recursiveSelection)
            }
        }
    }

    @Test
    func largeSyntheticReportIndexesAndSearchesWithinPerformanceBudget() throws {
        let report: SystemProfilerReport = largeSyntheticReport(
            recordCount: 650,
            fieldsPerRecord: 100
        )
        let clock = ContinuousClock()
        let indexingStart = clock.now
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        let indexingDuration: Duration = indexingStart.duration(to: clock.now)

        let query = FindingQuery(text: "needle-649-99", filter: .all)
        let queryStart = clock.now
        let result: ReportQueryResult = try index.queryResult(for: query)
        let queryDuration: Duration = queryStart.duration(to: clock.now)

        #expect(index.summary.recordCount == 650)
        #expect(index.summary.findingCount == 65_000)
        #expect(result.findingCount == 1)
        #expect(
            result.recordSelection(for: .applications, visibleLimit: 100)
                == MatchingRecordSelection(visibleIndices: [649], matchingCount: 1)
        )
        #expect(indexingDuration < .seconds(10))
        #expect(queryDuration < .seconds(2))
    }

    @Test(
        .enabled(
            if: performanceFixturePath != nil,
            "Set SYSTEM_PROFILER_PERFORMANCE_FIXTURE to a private system_profiler JSON file."
        )
    )
    func privateFullReportMeetsPerformanceBudget() throws {
        guard let performanceFixturePath else {
            throw CocoaError(.fileNoSuchFile)
        }

        let clock = ContinuousClock()
        let importStart = clock.now
        let data: Data = try Data(
            contentsOf: URL(fileURLWithPath: performanceFixturePath),
            options: .mappedIfSafe
        )
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            data,
            importedAt: Date(timeIntervalSince1970: 3_000)
        )
        let importDuration: Duration = importStart.duration(to: clock.now)

        let indexingStart = clock.now
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        let indexingDuration: Duration = indexingStart.duration(to: clock.now)

        let queryStart = clock.now
        let queryResult: ReportQueryResult = try index.queryResult(
            for: FindingQuery(text: "version", filter: .all)
        )
        let queryDuration: Duration = queryStart.duration(to: clock.now)

        print(
            "PRIVATE_REPORT_PERFORMANCE bytes=\(data.count) "
                + "findings=\(index.summary.findingCount) "
                + "matches=\(queryResult.findingCount) "
                + "import=\(importDuration) "
                + "index=\(indexingDuration) "
                + "query=\(queryDuration)"
        )

        #expect(index.summary.findingCount > 0)
        #expect(importDuration < .seconds(10))
        #expect(indexingDuration < .seconds(15))
        #expect(queryDuration < .seconds(3))
    }
}

private func representativeReport() -> SystemProfilerReport {
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
                        "future_apple_field": .string("future_value"),
                        "string_values": .array([.string("alpha")])
                    ]),
                    .object([
                        "_name": .string("Empty Synthetic Record")
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .storage,
                items: [
                    .object([
                        "_name": .string("Documentation Volume"),
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

private func largeSyntheticReport(
    recordCount: Int,
    fieldsPerRecord: Int
) -> SystemProfilerReport {
    let records: [ProfileValue] = (0..<recordCount).map { recordIndex in
        var object: [String: ProfileValue] = [
            "_name": .string("Synthetic Application \(recordIndex)")
        ]

        for fieldIndex in 0..<fieldsPerRecord {
            object["field_\(fieldIndex)"] = .string("needle-\(recordIndex)-\(fieldIndex)")
        }

        return .object(object)
    }

    return SystemProfilerReport(
        sections: [
            SystemProfilerSection(dataType: .applications, items: records)
        ],
        commandArguments: ["SPApplicationsDataType", "-json"],
        standardError: "",
        startedAt: Date(timeIntervalSince1970: 2_000),
        completedAt: Date(timeIntervalSince1970: 2_001)
    )
}
