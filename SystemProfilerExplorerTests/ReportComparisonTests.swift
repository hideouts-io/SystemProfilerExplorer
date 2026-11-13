import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ReportComparisonTests {
    @Test(arguments: [
        ["serial_number": ProfileValue.string("SYNTHETICMACA")],
        ["platform_UUID": ProfileValue.string("11111111-2222-3333-4444-555555555555")],
        ["serial_number": ProfileValue.string("SYNTHETICMACA"),
         "platform_UUID": .string("11111111-2222-3333-4444-555555555555")]
    ])
    func commonHardwareOverviewIdentifiersVerifyIdentity(fields: [String: ProfileValue]) throws {
        let baseline: SystemProfilerReport = machineIdentityReport(fields: fields)
        let current: SystemProfilerReport = machineIdentityReport(fields: fields)
        #expect(comparisonMachineIdentity(baseline: baseline, current: current) == .matched)
        #expect(try compareReports(baseline: baseline, current: current).machineIdentity == .matched)
    }

    @Test
    func identifierWhitespaceAndCaseDoNotCreateMachineConflicts() {
        let baseline: SystemProfilerReport = machineIdentityReport(fields: [
            "serial_number": .string(" syntheticmaca \n"),
            "platform_UUID": .string("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        ])
        let current: SystemProfilerReport = machineIdentityReport(fields: [
            "serial_number": .string("SYNTHETICMACA"),
            "platform_UUID": .string("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        ])
        #expect(comparisonMachineIdentity(baseline: baseline, current: current) == .matched)
    }

    @Test(arguments: [
        ProfileValue.null, .integer(1), .array([.string("SYNTHETICMACA")]),
        .string(""), .string(" \n"), .string("[REDACTED]"), .string("REDACTED"),
        .string("unknown"), .string("N/A"), .string("Not Available"),
        .string("000000000000"), .string("not a serial"), .string("ſYNTHETICMACA")
    ])
    func missingOrUnusableSerialsNeverVerifyIdentity(value: ProfileValue) throws {
        let report: SystemProfilerReport = machineIdentityReport(fields: ["serial_number": value])
        #expect(comparisonMachineIdentity(baseline: report, current: report) == .unverified)
        #expect(try compareReports(baseline: report, current: report).machineIdentity == .unverified)
    }

    @Test(arguments: [
        "", "[REDACTED]", "unknown", "invalid-uuid",
        "00000000-0000-0000-0000-000000000000", "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
    ])
    func unusableUUIDsNeverVerifyIdentity(value: String) {
        let report: SystemProfilerReport = machineIdentityReport(fields: ["platform_UUID": .string(value)])
        #expect(comparisonMachineIdentity(baseline: report, current: report) == .unverified)
    }

    @Test
    func absentHardwareAndDisjointIdentifyingFieldsRemainUnverified() throws {
        let serialOnly: SystemProfilerReport = machineIdentityReport(fields: ["serial_number": .string("SYNTHETICMACA")])
        let uuidOnly: SystemProfilerReport = machineIdentityReport(fields: [
            "platform_UUID": .string("11111111-2222-3333-4444-555555555555")
        ])
        let missing: SystemProfilerReport = machineIdentityReport(fields: ["machine_model": .string("Synthetic Model")])
        let noHardware: SystemProfilerReport = SystemProfilerReport(
            sections: [SystemProfilerSection(dataType: .software, items: [.object(["value": .integer(1)])])],
            commandArguments: [], standardError: "", startedAt: missing.startedAt, completedAt: missing.completedAt
        )
        for (baseline, current) in [(serialOnly, uuidOnly), (serialOnly, missing), (missing, serialOnly), (missing, missing), (noHardware, noHardware)] {
            #expect(comparisonMachineIdentity(baseline: baseline, current: current) == .unverified)
            #expect(try compareReports(baseline: baseline, current: current).machineIdentity == .unverified)
        }
    }

    @Test(arguments: ["serial_number", "platform_UUID"])
    func anyCommonIdentifierConflictBlocksComparisonEvenWhenAnotherAgrees(field: String) {
        let fields: [String: ProfileValue] = [
            "serial_number": .string("SYNTHETICMACA"),
            "platform_UUID": .string("11111111-2222-3333-4444-555555555555")
        ]
        var conflictingFields: [String: ProfileValue] = fields
        conflictingFields[field] = field == "serial_number"
            ? .string("SYNTHETICMACB") : .string("99999999-2222-3333-4444-555555555555")
        let baseline: SystemProfilerReport = machineIdentityReport(fields: fields)
        let current: SystemProfilerReport = machineIdentityReport(fields: conflictingFields)
        for (first, second) in [(baseline, current), (current, baseline)] {
            #expect(comparisonMachineIdentity(baseline: first, current: second) == .conflicting)
            #expect(throws: ReportComparisonError.conflictingMachineIdentifiers) {
                _ = try compareReports(baseline: first, current: second)
            }
        }
        let message: String = ReportComparisonError.conflictingMachineIdentifiers.localizedDescription
        for value in Array(fields.values) + Array(conflictingFields.values) {
            if case let .string(identifier) = value { #expect(!message.contains(identifier)) }
        }
        #expect(message.contains("same Mac"))
        #expect(message.contains("Hardware overview"))
    }

    @Test(arguments: ["SYNTHETICMACA", "SYNTHETICMACB"])
    func repeatedHardwareOverviewsCannotVerifyMachineIdentity(secondSerial: String) {
        let overview: ProfileValue = namedRecord(name: "hardware_overview", fields: [
            "serial_number": .string("SYNTHETICMACA")
        ])
        let duplicate: ProfileValue = namedRecord(name: "hardware_overview", fields: [
            "serial_number": .string(secondSerial)
        ])
        let baseline: SystemProfilerReport = machineIdentityReport(fields: ["serial_number": .string("SYNTHETICMACA")])
        let repeated: SystemProfilerReport = comparisonReport(
            items: [overview, duplicate], completedAt: baseline.completedAt
        )
        for (first, second) in [(baseline, repeated), (repeated, baseline), (repeated, repeated)] {
            #expect(comparisonMachineIdentity(baseline: first, current: second) == .conflicting)
            #expect(throws: ReportComparisonError.conflictingMachineIdentifiers) {
                _ = try compareReports(baseline: first, current: second)
            }
        }
    }

    @Test
    func peripheralSerialsAndUUIDsNeverIdentifyTheMac() {
        func report(_ suffix: String) -> SystemProfilerReport {
            comparisonReport(items: [
                namedRecord(name: "hardware_overview", fields: [
                    "machine_model": .string("Synthetic Model"),
                    "_items": .array([.object([
                        "serial_number": .string("SYNTHETIC" + suffix),
                        "platform_UUID": .string("11111111-2222-3333-4444-555555555555")
                    ])])
                ]),
                namedRecord(name: "Peripheral", fields: [
                    "serial_number": .string("SYNTHETIC" + suffix),
                    "platform_UUID": .string("11111111-2222-3333-4444-555555555555")
                ])
            ], completedAt: Date(timeIntervalSince1970: 1_700_000_000))
        }
        let baseline: SystemProfilerReport = report("A")
        #expect(comparisonMachineIdentity(baseline: baseline, current: baseline) == .unverified)
        #expect(comparisonMachineIdentity(baseline: baseline, current: report("B")) == .unverified)
        let unnamed: SystemProfilerReport = comparisonReport(
            items: [.object(["serial_number": .string("SYNTHETICMACA")])], completedAt: baseline.completedAt
        )
        #expect(comparisonMachineIdentity(baseline: unnamed, current: unnamed) == .matched)
    }

    @Test
    func sectionAmbiguityPreservesConfirmedChangesAndOriginalCandidateIndices() throws {
        let exact: ProfileValue = namedRecord(name: "Device", fields: ["value": .integer(2)])
        let baseline: SystemProfilerReport = comparisonReport(items: [
            namedRecord(name: "Device", fields: ["value": .integer(1)]),
            namedRecord(name: "Unique", fields: ["value": .integer(4)]), exact
        ], completedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let current: SystemProfilerReport = comparisonReport(items: [
            exact, namedRecord(name: "Device", fields: ["value": .integer(3)]),
            namedRecord(name: "Unique", fields: ["value": .integer(5)])
        ], completedAt: Date(timeIntervalSince1970: 1_700_000_001))
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.summary.baselineFindingCount == 2)
        #expect(comparison.summary.currentFindingCount == 2)
        #expect(comparison.summary.changedCount == 1)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.changes.first?.baselineAddress?.path == [.index(1), .field("value")])
        #expect(comparison.changes.first?.currentAddress?.path == [.index(2), .field("value")])
        let unresolved: UnresolvedRecordMatch = try #require(comparison.unresolvedMatches.first)
        #expect(comparison.unresolvedMatches.count == 1)
        #expect(unresolved.baselineCandidates.map(\.path) == [[.index(0)]])
        #expect(unresolved.currentCandidates.map(\.path) == [[.index(1)]])
        #expect(try profileValue(at: unresolved.baselineCandidates[0], in: baseline) == baseline.sections[0].items[0])
        #expect(try profileValue(at: unresolved.currentCandidates[0], in: current) == current.sections[0].items[1])
        #expect(try compareReports(baseline: baseline, current: current).unresolvedMatches == comparison.unresolvedMatches)
    }

    @Test
    func nestedUnresolvedGroupsPreserveParentAndSiblingChangesAfterReordering() throws {
        func parent(_ value: Int64, children: [ProfileValue]) -> ProfileValue {
            namedRecord(name: "Parent", fields: [
                "value": .integer(value), "children": .array(children),
                "children[0]": .array([.object(["value": .integer(value)])])
            ])
        }
        let duplicate: ProfileValue = namedRecord(name: "Device", fields: ["value": .integer(1)])
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [
            parent(1, children: [duplicate, duplicate, namedRecord(name: "Unique", fields: ["value": .integer(3)])]),
            namedRecord(name: "Other", fields: ["value": .integer(7)])
        ])
        let current: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Other", fields: ["value": .integer(8)]),
            parent(2, children: [namedRecord(name: "Unique", fields: ["value": .integer(4)]), duplicate, duplicate])
        ])
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.summary.baselineFindingCount == 3)
        #expect(comparison.summary.currentFindingCount == 3)
        #expect(comparison.summary.changedCount == 3)
        #expect(comparison.summary.unchangedCount == 0)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.unresolvedMatches.count == 2)
        #expect(Set(comparison.unresolvedMatches.map(\.id)).count == 2)
        let duplicates: UnresolvedRecordMatch = try #require(comparison.unresolvedMatches.first { $0.recordName == "Device" })
        #expect(duplicates.baselineCandidates.map(\.sourcePath) == [
            "SPHardwareDataType[0]._items[0].children[0]", "SPHardwareDataType[0]._items[0].children[1]"
        ])
        #expect(duplicates.currentCandidates.map(\.sourcePath) == [
            "SPHardwareDataType[0]._items[1].children[1]", "SPHardwareDataType[0]._items[1].children[2]"
        ])
        for group in comparison.unresolvedMatches {
            for address in group.baselineCandidates { _ = try profileValue(at: address, in: baseline) }
            for address in group.currentCandidates { _ = try profileValue(at: address, in: current) }
        }
        #expect(try compareReports(baseline: baseline, current: current).unresolvedMatches.map(\.id) == comparison.unresolvedMatches.map(\.id))
        #expect(comparison.changes.contains {
            $0.baselineSourcePath == "SPHardwareDataType[0]._items[0].children[2].value"
                && $0.currentSourcePath == "SPHardwareDataType[0]._items[1].children[0].value"
        })
    }

    @Test(arguments: [
        "", "collection timed out", "operation not permitted", "reporter unavailable"
    ])
    func omittedRequestedSectionsCannotProduceAComparison(standardError: String) throws {
        let privateDiagnostic: String = "SYNTHETIC-PRIVATE-DIAGNOSTIC"
        let request: SystemProfilerRequest = SystemProfilerRequest(
            dataTypes: [.hardware, .wifi], detailLevel: .full, timeoutSeconds: 90
        )
        let partial: SystemProfilerReport = try SystemProfilerParser().parse(SystemProfilerExecution(
            request: request,
            standardOutput: Data(#"{"SPHardwareDataType":[{"_name":"Synthetic Hardware","physical_memory":"16 GB"}]}"#.utf8),
            standardError: standardError + "\n" + privateDiagnostic,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_001)
        ))
        let exported: SystemProfilerReport = try loadComparisonBaseline(
            from: encodeReportExport(makeFullReportExport(partial)),
            importedAt: Date(timeIntervalSince1970: 1_700_000_002)
        )
        let complete: SystemProfilerReport = comparisonReport(
            items: partial.sections[0].items,
            completedAt: Date(timeIntervalSince1970: 1_700_000_003)
        )
        #expect(exported == partial)
        #expect(collectionCoverage(for: exported).incompleteEntries.map(\.dataType) == [.wifi])
        let missing: [CollectionCoverageEntry] = collectionCoverage(for: exported).incompleteEntries
        #expect(!ReportComparisonError.incompleteCollection(
            baseline: missing, current: missing
        ).localizedDescription.contains(privateDiagnostic))
        let completeScope: SystemProfilerReport = SystemProfilerReport(
            sections: complete.sections + [SystemProfilerSection(dataType: .wifi, items: [])],
            commandArguments: request.arguments, standardError: "",
            startedAt: complete.startedAt, completedAt: complete.completedAt
        )
        #expect(throws: ReportComparisonError.incompleteCollection(baseline: [], current: missing)) {
            _ = try compareReports(baseline: complete, current: exported)
        }
        #expect(throws: ReportComparisonError.incompleteCollection(baseline: missing, current: [])) {
            _ = try compareReports(baseline: exported, current: complete)
        }
        #expect(throws: ReportComparisonError.incompleteCollection(baseline: missing, current: missing)) {
            _ = try compareReports(baseline: exported, current: exported)
        }
        #expect(throws: ReportComparisonError.incompleteCollection(baseline: [], current: missing)) {
            _ = try compareReports(baseline: completeScope, current: exported)
        }
        #expect(throws: ReportComparisonError.incompleteCollection(baseline: missing, current: [])) {
            _ = try compareReports(baseline: exported, current: completeScope)
        }
    }

    @Test
    func explicitlyReturnedEmptySectionsRemainComparable() throws {
        let request: SystemProfilerRequest = SystemProfilerRequest(
            dataTypes: [.hardware, .wifi], detailLevel: .full, timeoutSeconds: 90
        )
        func parse(_ json: String) throws -> SystemProfilerReport {
            try SystemProfilerParser().parse(SystemProfilerExecution(
                request: request, standardOutput: Data(json.utf8),
                standardError: "Class NoFlyZone is implemented in both Apple components",
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                completedAt: Date(timeIntervalSince1970: 1_700_000_001)
            ))
        }
        let baseline: SystemProfilerReport = try parse(#"{"SPHardwareDataType":[{"physical_memory":"16 GB"}],"SPAirPortDataType":[{"_name":"Synthetic Wi-Fi","spairport_status_information":"spairport_status_connected"}]}"#)
        let current: SystemProfilerReport = try parse(#"{"SPHardwareDataType":[{"physical_memory":"16 GB"}],"SPAirPortDataType":[]}"#)
        #expect(collectionCoverage(for: current).incompleteEntries.isEmpty)
        #expect(collectionCoverage(for: current).emptyCount == 1)
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.summary.removedCount == 1)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.changedCount == 0)
        #expect(comparison.changes.first?.dataType == .wifi)
        #expect(try compareReports(baseline: current, current: current).changes.isEmpty)
    }

    @Test
    func completeButDifferentScopesRemainIncompatible() throws {
        let hardware: SystemProfilerReport = try loadComparisonBaseline(
            from: Data(#"{"SPHardwareDataType":[{"physical_memory":"16 GB"}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let software: SystemProfilerReport = try loadComparisonBaseline(
            from: Data(#"{"SPSoftwareDataType":[{"os_version":"Synthetic OS"}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        #expect(throws: ReportComparisonError.coverageMismatch(
            baseline: [SystemProfilerDataType.hardware.title], current: [SystemProfilerDataType.software.title]
        )) {
            _ = try compareReports(baseline: hardware, current: software)
        }
    }

    /// Exercises the actual importer and comparison pipeline with the files supplied
    /// to manual compatibility testers; these are synthetic, not hardware captures.
    @Test
    func importedReorderedDifferencesKeepBothSourceLocations() throws {
        let baseline: SystemProfilerReport = try loadComparisonBaseline(
            from: Data(#"{"SPHardwareDataType":[{"_name":"Synthetic Alpha","_items":[{"_name":"Module Alpha","value":null},{"_name":"Module Beta","value":2},{"_name":"Removed Module","value":"removed"}]},{"_name":"Synthetic Beta","value":4}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = try loadComparisonBaseline(
            from: Data(#"{"SPHardwareDataType":[{"_name":"Synthetic Beta","value":5},{"_name":"Synthetic Alpha","_items":[{"_name":"Module Beta","value":2},{"_name":"Module Alpha","value":3},{"_name":"Added Module","value":"added"}]}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.summary.addedCount == 1)
        #expect(comparison.summary.removedCount == 1)
        #expect(comparison.summary.changedCount == 2)
        #expect(comparison.summary.unchangedCount == 1)
        let changed: ReportChange = try #require(comparison.changes.first {
            $0.kind == .changed && $0.previousValue == .null
        })
        #expect(changed.baselineSourcePath == "SPHardwareDataType[0]._items[0].value")
        #expect(changed.currentSourcePath == "SPHardwareDataType[1]._items[1].value")
        #expect(changed.sourcePath == changed.currentSourcePath)
        #expect(changed.previousValue == .null)
        #expect(changed.currentValue == .integer(3))
        let parentChange: ReportChange = try #require(comparison.changes.first {
            $0.kind == .changed && $0.previousValue == .integer(4)
        })
        #expect(parentChange.baselineSourcePath == "SPHardwareDataType[1].value")
        #expect(parentChange.currentSourcePath == "SPHardwareDataType[0].value")
        let added: ReportChange = try #require(comparison.changes.first { $0.kind == .added })
        #expect(added.baselineSourcePath == nil)
        #expect(added.currentSourcePath == "SPHardwareDataType[1]._items[2].value")
        #expect(added.sourcePath == added.currentSourcePath)
        let removed: ReportChange = try #require(comparison.changes.first { $0.kind == .removed })
        #expect(removed.baselineSourcePath == "SPHardwareDataType[0]._items[2].value")
        #expect(removed.currentSourcePath == nil)
        #expect(removed.sourcePath == removed.baselineSourcePath)

        let reverse: ReportComparison = try compareReports(baseline: current, current: baseline)
        for change in comparison.changes {
            let inverse: ReportChange = try #require(reverse.changes.first {
                $0.baselineSourcePath == change.currentSourcePath
                    && $0.currentSourcePath == change.baselineSourcePath
            })
            #expect(inverse.previousValue == change.currentValue)
            #expect(inverse.currentValue == change.previousValue)
            #expect(reportChangeInsight(change).change == change)
        }
    }

    @Test
    func compatibilityFixturesHaveReproducibleComparisonResults() throws {
        let directory: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Compatibility", isDirectory: true)
        func load(_ name: String) throws -> SystemProfilerReport {
            try loadComparisonBaseline(
                from: Data(contentsOf: directory.appendingPathComponent(name)),
                importedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
        let baseline: SystemProfilerReport = try load("baseline.json")
        let reordered: SystemProfilerReport = try load("reordered.json")
        let changed: SystemProfilerReport = try load("changed.json")
        let moved: SystemProfilerReport = try load("moved-change.json")
        let ambiguous: SystemProfilerReport = try load("ambiguous.json")
        let partial: SystemProfilerReport = try load("incomplete-export.json")
        #expect(collectionCoverage(for: partial).incompleteEntries == [
            CollectionCoverageEntry(dataType: .wifi, status: .skipped)
        ])
        #expect(throws: ReportComparisonError.incompleteCollection(
            baseline: [CollectionCoverageEntry(dataType: .wifi, status: .skipped)], current: []
        )) {
            _ = try compareReports(baseline: partial, current: baseline)
        }
        #expect(try compareReports(baseline: baseline, current: reordered).summary.changeCount == 0)
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: changed)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.summary.changedCount == 1)
        let change: ReportChange = try #require(comparison.changes.first)
        #expect(change.sourcePath == "SPHardwareDataType[0].physical_memory")
        #expect(change.previousValue == .string("16 GB"))
        #expect(change.currentValue == .string("32 GB"))
        let movedComparison: ReportComparison = try compareReports(baseline: baseline, current: moved)
        #expect(movedComparison.summary.changeCount == 1)
        let movedChange: ReportChange = try #require(movedComparison.changes.first)
        #expect(movedChange.kind == .changed)
        #expect(movedChange.previousValue == .string("1"))
        #expect(movedChange.currentValue == .string("3"))
        #expect(movedChange.baselineSourcePath == "SPHardwareDataType[0]._items[0].version")
        #expect(movedChange.currentSourcePath == "SPHardwareDataType[0]._items[1].version")
        let unresolvedComparison: ReportComparison = try compareReports(baseline: baseline, current: ambiguous)
        #expect(unresolvedComparison.changes.isEmpty)
        #expect(unresolvedComparison.summary.unchangedCount == 3)
        #expect(unresolvedComparison.summary.baselineFindingCount == 3)
        #expect(unresolvedComparison.summary.currentFindingCount == 3)
        let unresolved: UnresolvedRecordMatch = try #require(unresolvedComparison.unresolvedMatches.first)
        #expect(unresolvedComparison.unresolvedMatches.count == 1)
        #expect(unresolved.recordName == "Synthetic Module")
        #expect(unresolved.baselineCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[1]"])
        #expect(unresolved.currentCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[2]"])
    }

    @Test
    func namedRecordsRemainMatchedWhenTheirOrderChanges() throws {
        let baseline: SystemProfilerReport = comparisonReport(
            items: [
                namedRecord(name: "Alpha", fields: ["value": .integer(1)]),
                namedRecord(name: "Beta", fields: ["value": .integer(2)])
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [
                namedRecord(name: "Beta", fields: ["value": .integer(2)]),
                namedRecord(name: "Alpha", fields: ["value": .integer(1)])
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.changeCount == 0)
        #expect(comparison.summary.unchangedCount == 2)
        #expect(comparison.changes.isEmpty)
    }

    @Test(arguments: [
        [
            namedRecord(name: "Device", fields: ["value": .integer(1)]),
            namedRecord(name: "Device", fields: ["value": .integer(2)]),
            namedRecord(name: "Device", fields: ["value": .integer(1)])
        ],
        [
            ProfileValue.object(["value": .integer(1)]),
            .object(["value": .integer(2)]),
            .object(["value": .integer(1)])
        ]
    ])
    func identicalDuplicatesRemainUnresolvedWhenReordered(records: [ProfileValue]) throws {
        let baseline: SystemProfilerReport = comparisonReport(
            items: records,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [records[1], records[2], records[0]],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.baselineFindingCount == 1)
        #expect(comparison.summary.currentFindingCount == 1)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.changes.isEmpty)
        #expect(comparison.unresolvedMatches.count == 1)
        #expect(comparison.unresolvedMatches.first?.baselineCandidates.map(\.path) == [[.index(0)], [.index(2)]])
        #expect(comparison.unresolvedMatches.first?.currentCandidates.map(\.path) == [[.index(1)], [.index(2)]])
    }

    @Test(arguments: [
        namedRecord(name: "Device", fields: ["value": .integer(1)]),
        ProfileValue.object(["value": .integer(1)])
    ])
    func duplicateMultiplicityIsRetainedAsUnresolvedCandidates(record: ProfileValue) throws {
        let baseline: SystemProfilerReport = comparisonReport(
            items: [record, record],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [record],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let removal: ReportComparison = try compareReports(baseline: baseline, current: current)
        let addition: ReportComparison = try compareReports(baseline: current, current: baseline)

        #expect(removal.summary.baselineFindingCount == 0)
        #expect(removal.summary.currentFindingCount == 0)
        #expect(removal.summary.unchangedCount == 0)
        #expect(removal.summary.removedCount == 0)
        #expect(removal.summary.changedCount == 0)
        #expect(removal.summary.addedCount == 0)
        #expect(addition.summary.unchangedCount == 0)
        #expect(addition.summary.addedCount == 0)
        #expect(addition.summary.changedCount == 0)
        #expect(addition.summary.removedCount == 0)
        #expect(removal.unresolvedMatches.first?.baselineCandidates.map(\.path) == [[.index(0)], [.index(1)]])
        #expect(removal.unresolvedMatches.first?.currentCandidates.map(\.path) == [[.index(0)]])
        #expect(addition.unresolvedMatches.first?.baselineCandidates == removal.unresolvedMatches.first?.currentCandidates)
        #expect(addition.unresolvedMatches.first?.currentCandidates == removal.unresolvedMatches.first?.baselineCandidates)
    }

    @Test(arguments: [
        [
            namedRecord(name: "Device", fields: ["value": .integer(1)]),
            namedRecord(name: "Device", fields: ["value": .integer(2)]),
            namedRecord(name: "Device", fields: ["value": .integer(3)])
        ],
        [
            ProfileValue.object(["value": .integer(1)]),
            .object(["value": .integer(2)]),
            .object(["value": .integer(3)])
        ]
    ])
    func unresolvedRecordsAreNotPairedAfterAnExactMatch(records: [ProfileValue]) throws {
        let ambiguousPairs: [([ProfileValue], [ProfileValue])] = [
            ([records[0], records[1]], [records[1], records[2]]),
            ([records[0], records[1]], [records[2]])
        ]
        for (baselineItems, currentItems) in ambiguousPairs {
            let baseline: SystemProfilerReport = comparisonReport(
                items: baselineItems,
                completedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
            let current: SystemProfilerReport = comparisonReport(
                items: currentItems,
                completedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )

            let forward: ReportComparison = try compareReports(baseline: baseline, current: current)
            let reverse: ReportComparison = try compareReports(baseline: current, current: baseline)
            let exactCount: Int = currentItems.count == 2 ? 1 : 0
            for comparison in [forward, reverse] {
                #expect(comparison.changes.isEmpty)
                #expect(comparison.summary.changeCount == 0)
                #expect(comparison.summary.unchangedCount == exactCount)
                #expect(comparison.summary.baselineFindingCount == exactCount)
                #expect(comparison.summary.currentFindingCount == exactCount)
                #expect(comparison.unresolvedMatches.count == 1)
                #expect(comparison.unresolvedMatches.first?.recordName == records[0].preferredName)
            }
            #expect(forward.unresolvedMatches.first?.baselineCandidates.count == baselineItems.count - exactCount)
            #expect(forward.unresolvedMatches.first?.currentCandidates.count == currentItems.count - exactCount)
            #expect(reverse.unresolvedMatches.first?.baselineCandidates == forward.unresolvedMatches.first?.currentCandidates)
            #expect(reverse.unresolvedMatches.first?.currentCandidates == forward.unresolvedMatches.first?.baselineCandidates)
        }
    }

    @Test
    func aSingleUnnamedRecordAmongNamedRecordsHasNoAssumedIdentity() throws {
        let named: ProfileValue = namedRecord(name: "Device", fields: ["value": .integer(1)])
        let baseline: SystemProfilerReport = comparisonReport(
            items: [named, .object(["value": .integer(2)])],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [.object(["value": .integer(3)]), named],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.changes.isEmpty)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.summary.baselineFindingCount == 1)
        #expect(comparison.summary.currentFindingCount == 1)
        #expect(comparison.unresolvedMatches.count == 1)
        #expect(comparison.unresolvedMatches.first?.recordName == nil)
        #expect(comparison.unresolvedMatches.first?.baselineCandidates.map(\.path) == [[.index(1)]])
        #expect(comparison.unresolvedMatches.first?.currentCandidates.map(\.path) == [[.index(0)]])
    }

    @Test
    func genuineChangeInAUniqueNamedRecordSurvivesReordering() throws {
        let baseline: SystemProfilerReport = comparisonReport(
            items: [
                namedRecord(name: "Alpha", fields: ["value": .integer(1)]),
                namedRecord(name: "Beta", fields: ["value": .integer(2)])
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [
                namedRecord(name: "Beta", fields: ["value": .integer(2)]),
                namedRecord(name: "Alpha", fields: ["value": .integer(3)])
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.changeCount == 1)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.changes.first?.kind == .changed)
        #expect(comparison.changes.first?.recordLabel == "Alpha")
        #expect(comparison.changes.first?.previousValue == .integer(1))
        #expect(comparison.changes.first?.currentValue == .integer(3))
    }

    @Test
    func singleUnnamedSectionContainerRetainsFieldComparison() throws {
        let baseline: SystemProfilerReport = comparisonReport(
            items: [.object(["value": .integer(1)])],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [.object(["value": .integer(2)])],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.changedCount == 1)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.changes.first?.previousValue == .integer(1))
        #expect(comparison.changes.first?.currentValue == .integer(2))
    }

    @Test
    func comparisonClassifiesAddedRemovedAndChangedFindings() throws {
        let baseline: SystemProfilerReport = comparisonReport(
            items: [
                namedRecord(
                    name: "Device",
                    fields: [
                        "status": .string("old"),
                        "removed_field": .boolean(true),
                        "values": .array([.integer(1), .integer(2)])
                    ]
                )
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = comparisonReport(
            items: [
                namedRecord(
                    name: "Device",
                    fields: [
                        "status": .string("new"),
                        "added_field": .integer(3),
                        "values": .array([.integer(1), .integer(4)])
                    ]
                )
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.baselineFindingCount == 4)
        #expect(comparison.summary.currentFindingCount == 4)
        #expect(comparison.summary.addedCount == 1)
        #expect(comparison.summary.removedCount == 1)
        #expect(comparison.summary.changedCount == 2)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.changes.contains { change in
            change.kind == .changed && change.sourcePath.hasSuffix("values[1]")
        })
    }

    @Test(arguments: [
        [
            namedRecord(name: "Alpha", fields: ["value": .integer(1)]),
            namedRecord(name: "Beta", fields: ["value": .integer(2)])
        ],
        [
            namedRecord(name: "Device", fields: ["value": .integer(1)]),
            namedRecord(name: "Device", fields: ["value": .integer(2)])
        ],
        [ProfileValue.object(["value": .integer(1)]), .object(["value": .integer(2)])]
    ])
    func nestedObjectRecordsRemainMatchedWhenReordered(records: [ProfileValue]) throws {
        let baseline: SystemProfilerReport = nestedComparisonReport(children: records)
        let current: SystemProfilerReport = nestedComparisonReport(children: records.reversed())

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.baselineFindingCount == 2)
        #expect(comparison.summary.currentFindingCount == 2)
        #expect(comparison.summary.unchangedCount == 2)
        #expect(comparison.changes.isEmpty)
    }

    @Test
    func nestedNamedRecordChangesUseTheCurrentSourceIndex() throws {
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Alpha", fields: ["value": .integer(1)]),
            namedRecord(name: "Beta", fields: ["value": .integer(2)])
        ])
        let current: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Beta", fields: ["value": .integer(2)]),
            namedRecord(name: "Alpha", fields: ["value": .integer(3)])
        ])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.changedCount == 1)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.changes.first?.previousValue == .integer(1))
        #expect(comparison.changes.first?.currentValue == .integer(3))
        #expect(comparison.changes.first?.sourcePath == "SPHardwareDataType[0]._items[1].value")
        #expect(comparison.changes.first?.baselineSourcePath == "SPHardwareDataType[0]._items[0].value")
        #expect(comparison.changes.first?.currentSourcePath == "SPHardwareDataType[0]._items[1].value")
        #expect(comparison.changes.first?.catalogPath == ["_items", "[]", "value"])
    }

    @Test(arguments: [
        [
            namedRecord(name: "Device", fields: ["value": .integer(1)]),
            namedRecord(name: "Device", fields: ["value": .integer(2)]),
            namedRecord(name: "Device", fields: ["value": .integer(3)])
        ],
        [
            ProfileValue.object(["value": .integer(1)]),
            .object(["value": .integer(2)]),
            .object(["value": .integer(3)])
        ]
    ])
    func nestedResidualAmbiguityRemainsUnresolvedInBothDirections(records: [ProfileValue]) throws {
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [records[0], records[1]])
        let current: SystemProfilerReport = nestedComparisonReport(children: [records[1], records[2]])

        let forward: ReportComparison = try compareReports(baseline: baseline, current: current)
        let reverse: ReportComparison = try compareReports(baseline: current, current: baseline)
        for comparison in [forward, reverse] {
            #expect(comparison.changes.isEmpty)
            #expect(comparison.summary.unchangedCount == 1)
            #expect(comparison.summary.baselineFindingCount == 1)
            #expect(comparison.summary.currentFindingCount == 1)
            #expect(comparison.unresolvedMatches.count == 1)
            #expect(comparison.unresolvedMatches.first?.recordName == records[0].preferredName)
        }
        #expect(forward.unresolvedMatches.first?.baselineCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[0]"])
        #expect(forward.unresolvedMatches.first?.currentCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[1]"])
        #expect(reverse.unresolvedMatches.first?.baselineCandidates == forward.unresolvedMatches.first?.currentCandidates)
        #expect(reverse.unresolvedMatches.first?.currentCandidates == forward.unresolvedMatches.first?.baselineCandidates)
    }

    @Test
    func aSingleUnnamedNestedRecordDoesNotInheritTheSectionContainerException() throws {
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [.object(["value": .integer(1)])])
        let current: SystemProfilerReport = nestedComparisonReport(children: [.object(["value": .integer(2)])])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.changes.isEmpty)
        #expect(comparison.summary.baselineFindingCount == 0)
        #expect(comparison.summary.currentFindingCount == 0)
        #expect(comparison.summary.unchangedCount == 0)
        #expect(comparison.unresolvedMatches.count == 1)
        #expect(comparison.unresolvedMatches.first?.recordName == nil)
        #expect(comparison.unresolvedMatches.first?.baselineCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[0]"])
        #expect(comparison.unresolvedMatches.first?.currentCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[0]"])
    }

    @Test(arguments: [
        namedRecord(name: "Device", fields: ["value": .integer(1)]),
        ProfileValue.object(["value": .integer(1)])
    ])
    func nestedDuplicateMultiplicityRemainsUnresolved(record: ProfileValue) throws {
        let other: ProfileValue = namedRecord(name: "Other", fields: ["value": .integer(2)])
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [record, other, record])
        let current: SystemProfilerReport = nestedComparisonReport(children: [other, record])

        let removal: ReportComparison = try compareReports(baseline: baseline, current: current)
        let addition: ReportComparison = try compareReports(baseline: current, current: baseline)

        #expect(removal.summary.unchangedCount == 1)
        #expect(removal.summary.removedCount == 0)
        #expect(removal.summary.addedCount == 0)
        #expect(removal.summary.changedCount == 0)
        #expect(removal.changes.isEmpty)
        #expect(addition.summary.unchangedCount == 1)
        #expect(addition.summary.addedCount == 0)
        #expect(addition.summary.removedCount == 0)
        #expect(addition.summary.changedCount == 0)
        #expect(addition.changes.isEmpty)
        #expect(removal.summary.baselineFindingCount == 1)
        #expect(removal.summary.currentFindingCount == 1)
        #expect(removal.unresolvedMatches.count == 1)
        #expect(addition.unresolvedMatches.count == 1)
        #expect(removal.unresolvedMatches.first?.baselineCandidates.map(\.sourcePath) == [
            "SPHardwareDataType[0]._items[0]", "SPHardwareDataType[0]._items[2]"
        ])
        #expect(removal.unresolvedMatches.first?.currentCandidates.map(\.sourcePath) == ["SPHardwareDataType[0]._items[1]"])
        #expect(addition.unresolvedMatches.first?.baselineCandidates == removal.unresolvedMatches.first?.currentCandidates)
        #expect(addition.unresolvedMatches.first?.currentCandidates == removal.unresolvedMatches.first?.baselineCandidates)
    }

    @Test
    func nestedMatchingRecursesWithoutCollidingAcrossSiblingArrays() throws {
        let alpha: ProfileValue = namedRecord(name: "Alpha", fields: ["value": .integer(1)])
        let beta: ProfileValue = namedRecord(name: "Beta", fields: ["value": .integer(2)])
        let first: ProfileValue = namedRecord(name: "First", fields: ["children": .array([alpha, beta])])
        let second: ProfileValue = namedRecord(name: "Second", fields: ["children": .array([alpha, beta])])
        let changedFirst: ProfileValue = namedRecord(name: "First", fields: ["children": .array([
            beta, namedRecord(name: "Alpha", fields: ["value": .integer(3)])
        ])])
        let reorderedSecond: ProfileValue = namedRecord(name: "Second", fields: ["children": .array([beta, alpha])])
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [first, second])
        let current: SystemProfilerReport = nestedComparisonReport(children: [reorderedSecond, changedFirst])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.baselineFindingCount == 4)
        #expect(comparison.summary.currentFindingCount == 4)
        #expect(comparison.summary.unchangedCount == 3)
        #expect(comparison.summary.changedCount == 1)
        #expect(comparison.changes.first?.previousValue == .integer(1))
        #expect(comparison.changes.first?.currentValue == .integer(3))
        #expect(comparison.changes.first?.sourcePath == "SPHardwareDataType[0]._items[1].children[1].value")
        #expect(comparison.changes.first?.baselineSourcePath == "SPHardwareDataType[0]._items[0].children[0].value")
        #expect(comparison.changes.first?.currentSourcePath == "SPHardwareDataType[0]._items[1].children[1].value")
    }

    @Test
    func scalarArraysRemainOrderedInsideMatchedNestedRecords() throws {
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Alpha", fields: ["values": .array([.integer(1), .integer(2)])]),
            namedRecord(name: "Beta", fields: ["value": .integer(3)])
        ])
        let current: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Beta", fields: ["value": .integer(3)]),
            namedRecord(name: "Alpha", fields: ["values": .array([.integer(2), .integer(1)])])
        ])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.changedCount == 2)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(Set(comparison.changes.map(\.sourcePath)) == [
            "SPHardwareDataType[0]._items[1].values[0]",
            "SPHardwareDataType[0]._items[1].values[1]"
        ])
    }

    @Test
    func nestedNamedAdditionsAndRemovalsRemainDistinctFromChanges() throws {
        let alpha: ProfileValue = namedRecord(name: "Alpha", fields: ["value": .integer(1)])
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Removed", fields: ["value": .integer(2)]), alpha
        ])
        let current: SystemProfilerReport = nestedComparisonReport(children: [
            alpha, namedRecord(name: "Added", fields: ["value": .integer(3)])
        ])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.summary.addedCount == 1)
        #expect(comparison.summary.removedCount == 1)
        #expect(comparison.summary.changedCount == 0)
        #expect(comparison.changes.contains {
            $0.kind == .removed && $0.previousValue == .integer(2)
                && $0.sourcePath == "SPHardwareDataType[0]._items[0].value"
        })
        #expect(comparison.changes.contains {
            $0.kind == .added && $0.currentValue == .integer(3)
                && $0.sourcePath == "SPHardwareDataType[0]._items[1].value"
        })
    }

    @Test
    func emptyAndObjectRecordArraysPreserveAddedAndRemovedSourceIndices() throws {
        let empty: SystemProfilerReport = nestedComparisonReport(children: [])
        let populated: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Alpha", fields: ["value": .integer(1)]),
            namedRecord(name: "Beta", fields: ["value": .integer(2)])
        ])

        let addition: ReportComparison = try compareReports(baseline: empty, current: populated)
        let removal: ReportComparison = try compareReports(baseline: populated, current: empty)
        let expectedPaths: Set<String> = [
            "SPHardwareDataType[0]._items[0].value",
            "SPHardwareDataType[0]._items[1].value"
        ]

        #expect(addition.summary.baselineFindingCount == 0)
        #expect(addition.summary.currentFindingCount == 2)
        #expect(addition.summary.addedCount == 2)
        #expect(addition.summary.changedCount == 0)
        #expect(addition.summary.removedCount == 0)
        #expect(addition.summary.unchangedCount == 0)
        #expect(Set(addition.changes.map(\.sourcePath)) == expectedPaths)
        #expect(removal.summary.baselineFindingCount == 2)
        #expect(removal.summary.currentFindingCount == 0)
        #expect(removal.summary.removedCount == 2)
        #expect(removal.summary.changedCount == 0)
        #expect(removal.summary.addedCount == 0)
        #expect(removal.summary.unchangedCount == 0)
        #expect(Set(removal.changes.map(\.sourcePath)) == expectedPaths)
    }

    @Test
    func objectAndMixedArrayTransitionsRetainPositionalSemantics() throws {
        let objectRecords: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Alpha", fields: ["value": .integer(1)]),
            namedRecord(name: "Beta", fields: ["value": .integer(2)])
        ])
        let mixedValues: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Alpha", fields: ["value": .integer(3)]), .integer(7)
        ])

        let forward: ReportComparison = try compareReports(baseline: objectRecords, current: mixedValues)
        let reverse: ReportComparison = try compareReports(baseline: mixedValues, current: objectRecords)

        for comparison in [forward, reverse] {
            #expect(comparison.summary.baselineFindingCount == 2)
            #expect(comparison.summary.currentFindingCount == 2)
            #expect(comparison.summary.changedCount == 1)
            #expect(comparison.summary.addedCount == 1)
            #expect(comparison.summary.removedCount == 1)
            #expect(comparison.summary.unchangedCount == 0)
            #expect(comparison.changes.contains {
                $0.kind == .changed && $0.sourcePath == "SPHardwareDataType[0]._items[0].value"
            })
        }
        #expect(forward.changes.contains {
            $0.kind == .removed && $0.previousValue == .integer(2)
                && $0.sourcePath == "SPHardwareDataType[0]._items[1].value"
        })
        #expect(forward.changes.contains {
            $0.kind == .added && $0.currentValue == .integer(7)
                && $0.sourcePath == "SPHardwareDataType[0]._items[1]"
        })
        #expect(reverse.changes.contains {
            $0.kind == .removed && $0.previousValue == .integer(7)
                && $0.sourcePath == "SPHardwareDataType[0]._items[1]"
        })
        #expect(reverse.changes.contains {
            $0.kind == .added && $0.currentValue == .integer(2)
                && $0.sourcePath == "SPHardwareDataType[0]._items[1].value"
        })
    }

    @Test
    func aThousandReorderedDuplicateNamesDoNotProduceFalseChanges() throws {
        let records: [ProfileValue] = (0..<1_000).map {
            namedRecord(name: "Device", fields: ["value": .integer(Int64($0))])
        }
        let baseline: SystemProfilerReport = nestedComparisonReport(children: records)
        let current: SystemProfilerReport = nestedComparisonReport(children: records.reversed())

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.baselineFindingCount == 1_000)
        #expect(comparison.summary.currentFindingCount == 1_000)
        #expect(comparison.summary.unchangedCount == 1_000)
        #expect(comparison.changes.isEmpty)
    }

    @Test(arguments: [
        ["_name": ProfileValue.string("Device")],
        [:]
    ])
    func tenThousandReorderedAmbiguousRecordsKeepEveryOccurrence(recordMetadata: [String: ProfileValue]) throws {
        let records: [ProfileValue] = (0..<10_000).map { index in
            var fields: [String: ProfileValue] = recordMetadata
            fields["value"] = .integer(Int64(index))
            return .object(fields)
        }
        let baseline: SystemProfilerReport = nestedComparisonReport(children: records)
        let current: SystemProfilerReport = nestedComparisonReport(children: records.reversed())
        let clock: ContinuousClock = ContinuousClock()
        let startedAt: ContinuousClock.Instant = clock.now

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        let duration: Duration = startedAt.duration(to: clock.now)
        print("COMPARISON_GROUP_PERFORMANCE records=10000 duration=\(duration)")
        #expect(comparison.summary.baselineFindingCount == 10_000)
        #expect(comparison.summary.currentFindingCount == 10_000)
        #expect(comparison.summary.unchangedCount == 10_000)
        #expect(comparison.changes.isEmpty)
        #expect(duration < .seconds(10))
    }

    @Test
    func ambiguousExactMatchingKeepsDictionaryAndStringEqualityWithoutMergingScalarTypes() throws {
        let composed: ProfileValue = try JSONDecoder().decode(ProfileValue.self, from: Data(
            #"{"_name":"Device","properties":{"first":1,"second":2},"value":"\u00e9"}"#.utf8
        ))
        let decomposed: ProfileValue = try JSONDecoder().decode(ProfileValue.self, from: Data(
            #"{"value":"e\u0301","properties":{"second":2,"first":1},"_name":"Device"}"#.utf8
        ))
        let scalars: [ProfileValue] = [.string("1"), .integer(1), .decimal(1), .boolean(true), .null, .decimal(0), .decimal(-0.0)]
        let scalarRecords: [ProfileValue] = scalars.map { value in
            return namedRecord(name: "Device", fields: ["value": value])
        }
        #expect(composed == decomposed)
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [composed, composed] + scalarRecords)
        let current: SystemProfilerReport = nestedComparisonReport(children: scalarRecords.reversed() + [decomposed])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)

        #expect(comparison.summary.unchangedCount == 5)
        #expect(comparison.summary.baselineFindingCount == 5)
        #expect(comparison.summary.currentFindingCount == 5)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.changedCount == 0)
        #expect(comparison.changes.isEmpty)
        #expect(comparison.unresolvedMatches.count == 1)
        #expect(comparison.unresolvedMatches.first?.baselineCandidates.map(\.sourcePath) == [
            "SPHardwareDataType[0]._items[0]", "SPHardwareDataType[0]._items[1]",
            "SPHardwareDataType[0]._items[7]", "SPHardwareDataType[0]._items[8]"
        ])
        #expect(comparison.unresolvedMatches.first?.currentCandidates.map(\.sourcePath) == [
            "SPHardwareDataType[0]._items[0]", "SPHardwareDataType[0]._items[1]", "SPHardwareDataType[0]._items[7]"
        ])
    }

    @Test
    func cancelledComparisonFailsBeforePreparingMatches() async throws {
        let report: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Device", fields: ["value": .integer(1)])
        ])
        let work: Task<ReportComparison, any Error> = Task {
            try withUnsafeCurrentTask { task in
                try #require(task).cancel()
            }
            return try compareReports(baseline: report, current: report)
        }

        await #expect(throws: CancellationError.self) {
            _ = try await work.value
        }
    }

    @Test
    func nestedAmbiguityReportsBothLocationsAfterItsParentMoves() throws {
        let other: ProfileValue = namedRecord(name: "Other", fields: ["value": .integer(4)])
        let baseline: SystemProfilerReport = nestedComparisonReport(children: [
            namedRecord(name: "Parent", fields: ["children": .array([.object(["value": .integer(1)])])]),
            other
        ])
        let current: SystemProfilerReport = nestedComparisonReport(children: [
            other,
            namedRecord(name: "Parent", fields: ["children": .array([.object(["value": .integer(2)])])])
        ])

        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.changes.isEmpty)
        #expect(comparison.summary.unchangedCount == 1)
        #expect(comparison.unresolvedMatches.count == 1)
        let unresolved: UnresolvedRecordMatch = try #require(comparison.unresolvedMatches.first)
        #expect(unresolved.dataType == .hardware)
        #expect(unresolved.recordName == nil)
        #expect(unresolved.baselineCandidates == [ProfileValueAddress(
            dataType: .hardware, path: [.index(0), .field("_items"), .index(0), .field("children"), .index(0)]
        )])
        #expect(unresolved.currentCandidates == [ProfileValueAddress(
            dataType: .hardware, path: [.index(0), .field("_items"), .index(1), .field("children"), .index(0)]
        )])
        #expect(try profileValue(at: unresolved.baselineCandidates[0], in: baseline) == .object(["value": .integer(1)]))
        #expect(try profileValue(at: unresolved.currentCandidates[0], in: current) == .object(["value": .integer(2)]))
    }

    @Test
    func redactedReportCannotBecomeAComparisonBaseline() {
        let report: SystemProfilerReport = comparisonReport(
            items: [namedRecord(name: "Device", fields: ["value": .integer(1)])],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let export: ReportExportEnvelope = makeRedactedReportExport(report)

        #expect(throws: ReportComparisonError.redactedBaseline) {
            _ = try comparisonBaselineReport(from: export)
        }
    }

    @Test
    func fullReportRequiresCompletionMetadataForComparison() {
        let report: SystemProfilerReport = comparisonReport(
            items: [namedRecord(name: "Device", fields: ["value": .integer(1)])],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let validExport: ReportExportEnvelope = makeFullReportExport(report)
        let incompleteExport = ReportExportEnvelope(
            formatIdentifier: validExport.formatIdentifier,
            formatVersion: validExport.formatVersion,
            privacy: validExport.privacy,
            summary: validExport.summary,
            redactedValueCount: validExport.redactedValueCount,
            report: StoredSystemProfilerReport(
                sections: validExport.report.sections,
                commandArguments: validExport.report.commandArguments,
                standardError: validExport.report.standardError,
                startedAt: validExport.report.startedAt,
                completedAt: nil
            )
        )

        #expect(
            throws: ReportComparisonError.missingFullReportMetadata(field: "completion time")
        ) {
            _ = try comparisonBaselineReport(from: incompleteExport)
        }
    }

    @Test
    func comparisonRejectsDifferentProfilerCoverage() {
        let baseline: SystemProfilerReport = comparisonReport(
            items: [namedRecord(name: "Device", fields: ["value": .integer(1)])],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current = SystemProfilerReport(
            sections: [
                SystemProfilerSection(
                    dataType: .power,
                    items: [namedRecord(name: "Battery", fields: ["value": .integer(1)])]
                )
            ],
            commandArguments: ["SPPowerDataType", "-json"],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_700_000_099),
            completedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        #expect(throws: ReportComparisonError.self) {
            _ = try compareReports(baseline: baseline, current: current)
        }
    }

    @Test
    func comparisonRejectsRepeatedDataTypeSections() {
        let sections: [SystemProfilerSection] = [1, 2].map { value in
            SystemProfilerSection(dataType: .hardware, items: [.object(["value": .string(String(value))])])
        }
        let baseline = SystemProfilerReport(
            sections: sections,
            commandArguments: ["SPHardwareDataType", "-json"],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let current = SystemProfilerReport(
            sections: sections.reversed(),
            commandArguments: ["SPHardwareDataType", "-json"],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_700_000_100),
            completedAt: Date(timeIntervalSince1970: 1_700_000_101)
        )

        #expect(throws: ReportComparisonError.repeatedSections(dataTypes: [.hardware])) {
            _ = try compareReports(baseline: baseline, current: current)
        }
        let unique: SystemProfilerReport = comparisonReport(
            items: [], completedAt: Date(timeIntervalSince1970: 1_700_000_002)
        )
        #expect(throws: ReportComparisonError.repeatedSections(dataTypes: [.hardware])) {
            _ = try compareReports(baseline: unique, current: current)
        }
        #expect(throws: ReportComparisonError.repeatedSections(dataTypes: [.hardware])) {
            _ = try compareReports(baseline: baseline, current: unique)
        }
    }
}

private func comparisonReport(
    items: [ProfileValue],
    completedAt: Date
) -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(dataType: .hardware, items: items)
        ],
        commandArguments: ["SPHardwareDataType", "-json"],
        standardError: "",
        startedAt: completedAt.addingTimeInterval(-1),
        completedAt: completedAt
    )
}

private func namedRecord(
    name: String,
    fields: [String: ProfileValue]
) -> ProfileValue {
    var object: [String: ProfileValue] = fields
    object["_name"] = .string(name)
    return .object(object)
}

private func nestedComparisonReport(children: [ProfileValue]) -> SystemProfilerReport {
    comparisonReport(
        items: [namedRecord(name: "Container", fields: ["_items": .array(children)])],
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

private func machineIdentityReport(fields: [String: ProfileValue]) -> SystemProfilerReport {
    comparisonReport(
        items: [namedRecord(name: "hardware_overview", fields: fields)],
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
