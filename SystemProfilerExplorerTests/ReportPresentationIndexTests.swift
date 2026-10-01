import Foundation
import Testing
@testable import SystemProfilerExplorer

private let performanceFixturePath: String? = ProcessInfo.processInfo.environment[
    "SYSTEM_PROFILER_PERFORMANCE_FIXTURE"
]

struct ReportPresentationIndexTests {
    /// Groups show a field when the index says a match is on its path. That must agree with
    /// searching the field's subtree directly, which is what the groups used to do.
    @Test
    func visibleLocationsMatchSearchingEachField() throws {
        let report: SystemProfilerReport = representativeReport()
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        let queries: [FindingQuery] = [
            FindingQuery(text: "unified memory", filter: .all),
            FindingQuery(text: "Mac Studio", filter: .explained),
            FindingQuery(text: "String Values", filter: .all),
            FindingQuery(text: "Item 1", filter: .all),
            FindingQuery(text: "", filter: .privacy)
        ]

        #expect(try index.queryResult(for: FindingQuery(text: "", filter: .all)).visibleLocations == nil)

        for query in queries {
            let result: ReportQueryResult = try index.queryResult(for: query)

            for section in report.sections {
                for (recordIndex, record) in section.items.enumerated() {
                    expectFieldsAgree(
                        record,
                        label: recordDisplayLabel(record, fallback: "Record \(recordIndex + 1)"),
                        dataType: section.dataType,
                        path: [],
                        recordIndex: recordIndex,
                        arrayIndices: [],
                        query: query,
                        result: result
                    )
                }
            }
        }
    }

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

    @Test
    func worthALookFilterAndValueSummarySearchMatchRecursiveBehavior() throws {
        let report = SystemProfilerReport(
            sections: [
                SystemProfilerSection(
                    dataType: .power,
                    items: [
                        .object([
                            "sppower_battery_charge_info": .object([
                                "sppower_battery_state_of_charge": .integer(4),
                                "sppower_battery_is_charging": .string("FALSE"),
                                "sppower_battery_at_warn_level": .string("TRUE")
                            ]),
                            "sppower_battery_health_info": .object([
                                "sppower_battery_cycle_count": .integer(16),
                                "sppower_battery_health": .string("Good")
                            ])
                        ])
                    ]
                ),
                SystemProfilerSection(
                    dataType: .wifi,
                    items: [
                        .object([
                            "spairport_current_network_information": .object([
                                "spairport_network_phymode": .string("802.11ax")
                            ])
                        ])
                    ]
                )
            ],
            commandArguments: [],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 3_000),
            completedAt: Date(timeIntervalSince1970: 3_001)
        )
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        let worthALook = FindingQuery(text: "", filter: .worthALook)

        #expect(index.worthReviewingFindingCount == 2)
        #expect(worthReviewingFindingCount(report) == 2)
        #expect(try index.queryResult(for: worthALook).findingCount == 2)

        // "Wi-Fi 6" appears only in the value summary for 802.11ax.
        for query in [worthALook, FindingQuery(text: "Wi-Fi 6", filter: .all), FindingQuery(text: "Connect power", filter: .worthALook)] {
            let indexedCount: Int = try index.queryResult(for: query).findingCount
            #expect(indexedCount == matchingFindingCount(report, query: query), "\(query)")
        }

        #expect(try index.queryResult(for: FindingQuery(text: "Wi-Fi 6", filter: .all)).findingCount == 1)
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

/// Checks every field and array item below `value`: the index shows it exactly when its
/// own subtree matches the query a parent group passes down.
private func expectFieldsAgree(
    _ value: ProfileValue,
    label: String,
    dataType: SystemProfilerDataType,
    path: [String],
    recordIndex: Int,
    arrayIndices: [Int],
    query: FindingQuery,
    result: ReportQueryResult
) {
    let childQuery: FindingQuery = queryForDescendants(parentLabel: label, query: query)

    switch value {
    case let .object(object):
        for (key, fieldValue) in object where key != "_name" {
            let fieldLabel: String = displayName(for: key)
            let location: String = findingLocation(dataType: dataType, recordIndex: recordIndex, path: path + [key], arrayIndices: arrayIndices)
            let matches: Bool = profileValueMatches(fieldValue, label: fieldLabel, dataType: dataType, path: path + [key], query: childQuery, siblings: object)

            #expect(result.shows(location) == matches, "\(query) \(location)")

            if matches {
                expectFieldsAgree(fieldValue, label: fieldLabel, dataType: dataType, path: path + [key], recordIndex: recordIndex, arrayIndices: arrayIndices, query: childQuery, result: result)
            }
        }

    case let .array(values):
        for (offset, item) in values.enumerated() {
            let itemLabel: String = recordDisplayLabel(item, fallback: "Item \(offset + 1)")
            let location: String = findingLocation(dataType: dataType, recordIndex: recordIndex, path: path + ["[]"], arrayIndices: arrayIndices + [offset])
            let matches: Bool = profileValueMatches(item, label: itemLabel, dataType: dataType, path: path + ["[]"], query: childQuery)

            #expect(result.shows(location) == matches, "\(query) \(location)")

            if matches {
                expectFieldsAgree(item, label: itemLabel, dataType: dataType, path: path + ["[]"], recordIndex: recordIndex, arrayIndices: arrayIndices + [offset], query: childQuery, result: result)
            }
        }

    case .string, .integer, .decimal, .boolean, .null:
        break
    }
}
