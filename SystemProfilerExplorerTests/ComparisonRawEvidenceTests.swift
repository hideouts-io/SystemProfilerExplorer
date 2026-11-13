import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ComparisonRawEvidenceTests {
    @Test
    func addressedEvidenceSeparatesExactOriginalFromReconstructedAndMissingSource() throws {
        let input: String = #"{ "SPHardwareDataType" : [ { "value" : "escaped\u0020value 👩🏽‍💻" } ] }"#
        let report: SystemProfilerReport = try rawEvidenceReport(json: input, completedAt: Date(timeIntervalSince1970: 1_000))
        let address = ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")])
        let evidence: AddressedReportEvidence = try addressedReportEvidence(at: address, in: report)
        #expect(evidence.value == .string("escaped value 👩🏽‍💻"))
        #expect(try JSONDecoder().decode(ProfileValue.self, from: Data(evidence.structuredPages.joined().utf8)) == evidence.value)
        guard case let .available(pages, byteRange) = evidence.original else {
            Issue.record("Retained input must provide an original excerpt")
            return
        }
        #expect(pages.joined() == #""escaped\u0020value 👩🏽‍💻""#)
        #expect(Data(input.utf8).subdata(in: byteRange) == Data(pages.joined().utf8))

        let reopened: SystemProfilerReport = try comparisonBaselineReport(from: makeFullReportExport(report))
        let withoutSource: AddressedReportEvidence = try addressedReportEvidence(at: address, in: reopened)
        #expect(withoutSource.value == evidence.value)
        #expect(withoutSource.original == .unavailable)
        let record = ProfileValueAddress(dataType: .hardware, path: [.index(0)])
        let context: AddressedReportEvidence = try addressedReportEvidence(at: record, in: report)
        guard case let .available(recordPages, _) = context.original else {
            Issue.record("Surrounding record must retain original formatting")
            return
        }
        #expect(recordPages.joined() == #"{ "value" : "escaped\u0020value 👩🏽‍💻" }"#)
    }

    @Test
    func missingAddressFailsInsteadOfBecomingSourceUnavailable() throws {
        let report: SystemProfilerReport = try rawEvidenceReport(json: #"{"SPHardwareDataType":[{"value":null}]}"#, completedAt: Date(timeIntervalSince1970: 1_000))
        let absent = ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("absent")])
        #expect(throws: ProfileValueAddressError.missingField) {
            _ = try addressedReportEvidence(at: absent, in: report)
        }
        let address = ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")])
        #expect(try addressedReportEvidence(at: address, in: report).value == .null)
    }

    @Test
    func importedLiteralKeysAndNestedPathsResolveDistinctEvidence() throws {
        let baseline: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"_name":"Synthetic Context","a.b":1,"a":{"b":2},"items[0]":3,"items":[4],"":5,"[]":6,"[0]":7,"x|y":8}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"_name":"Synthetic Context","a.b":11,"a":{"b":12},"items[0]":13,"items":[14],"":15,"[]":16,"[0]":17,"x|y":18}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        let expected: [(path: [ProfileValuePathComponent], baseline: ProfileValue, current: ProfileValue)] = [
            ([.index(0), .field("a.b")], .integer(1), .integer(11)),
            ([.index(0), .field("a"), .field("b")], .integer(2), .integer(12)),
            ([.index(0), .field("items[0]")], .integer(3), .integer(13)),
            ([.index(0), .field("items"), .index(0)], .integer(4), .integer(14)),
            ([.index(0), .field("")], .integer(5), .integer(15)),
            ([.index(0), .field("[]")], .integer(6), .integer(16)),
            ([.index(0), .field("[0]")], .integer(7), .integer(17)),
            ([.index(0), .field("x|y")], .integer(8), .integer(18))
        ]
        #expect(comparison.summary.changedCount == expected.count)
        #expect(Set(comparison.changes.map(\.id)).count == expected.count)
        let addresses: [ProfileValueAddress] = expected.map {
            ProfileValueAddress(dataType: .hardware, path: $0.path)
        }
        #expect(Set(addresses.map(\.identity)).count == expected.count)
        for item in expected {
            let address: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: item.path)
            let change: ReportChange = try #require(comparison.changes.first { $0.currentAddress == address })
            #expect(change.baselineAddress == address)
            let previous: ComparisonRawEvidence = try comparisonRawEvidence(
                for: change, side: .baseline, comparison: comparison
            )
            let present: ComparisonRawEvidence = try comparisonRawEvidence(
                for: change, side: .current, comparison: comparison
            )
            #expect(previous.side == .baseline)
            #expect(present.side == .current)
            #expect(previous.address == address)
            #expect(present.address == address)
            #expect(previous.value == item.baseline)
            #expect(present.value == item.current)
        }
    }

    @Test
    func movedRecordsKeepBothSidesAndAbsentSidesFailExplicitly() throws {
        let baseline: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"_name":"Synthetic Alpha","_items":[{"_name":"Module Alpha","value":null},{"_name":"Module Beta","value":2},{"_name":"Removed Module","value":"removed"}]},{"_name":"Synthetic Beta","value":4}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"_name":"Synthetic Beta","value":5},{"_name":"Synthetic Alpha","_items":[{"_name":"Module Beta","value":2},{"_name":"Module Alpha","value":3},{"_name":"Added Module","value":"added"}]}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        #expect(comparison.summary.changedCount == 2)
        #expect(comparison.summary.addedCount == 1)
        #expect(comparison.summary.removedCount == 1)
        let nested: ReportChange = try #require(comparison.changes.first { $0.previousValue == .null })
        #expect(nested.baselineAddress == ProfileValueAddress(
            dataType: .hardware, path: [.index(0), .field("_items"), .index(0), .field("value")]
        ))
        #expect(nested.currentAddress == ProfileValueAddress(
            dataType: .hardware, path: [.index(1), .field("_items"), .index(1), .field("value")]
        ))
        #expect(try comparisonRawEvidence(for: nested, side: .baseline, comparison: comparison).value == .null)
        #expect(try comparisonRawEvidence(for: nested, side: .current, comparison: comparison).value == .integer(3))
        let parent: ReportChange = try #require(comparison.changes.first { $0.previousValue == .integer(4) })
        #expect(parent.baselineAddress == ProfileValueAddress(dataType: .hardware, path: [.index(1), .field("value")]))
        #expect(parent.currentAddress == ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")]))
        #expect(try comparisonRawEvidence(for: parent, side: .baseline, comparison: comparison).value == .integer(4))
        #expect(try comparisonRawEvidence(for: parent, side: .current, comparison: comparison).value == .integer(5))
        let added: ReportChange = try #require(comparison.changes.first { $0.kind == .added })
        #expect(added.baselineAddress == nil)
        #expect(try comparisonRawEvidence(for: added, side: .current, comparison: comparison).value == .string("added"))
        #expect(throws: ComparisonRawEvidenceError.missingSide(.baseline)) {
            _ = try comparisonRawEvidence(for: added, side: .baseline, comparison: comparison)
        }
        let removed: ReportChange = try #require(comparison.changes.first { $0.kind == .removed })
        #expect(removed.currentAddress == nil)
        #expect(try comparisonRawEvidence(for: removed, side: .baseline, comparison: comparison).value == .string("removed"))
        #expect(throws: ComparisonRawEvidenceError.missingSide(.current)) {
            _ = try comparisonRawEvidence(for: removed, side: .current, comparison: comparison)
        }

        let reverse: ReportComparison = try compareReports(baseline: current, current: baseline)
        for change in comparison.changes {
            let inverse: ReportChange = try #require(reverse.changes.first {
                $0.baselineAddress == change.currentAddress && $0.currentAddress == change.baselineAddress
            })
            if change.baselineAddress != nil {
                let previous: ComparisonRawEvidence = try comparisonRawEvidence(for: change, side: .baseline, comparison: comparison)
                let reversed: ComparisonRawEvidence = try comparisonRawEvidence(for: inverse, side: .current, comparison: reverse)
                #expect(previous.address == reversed.address)
                #expect(previous.value == reversed.value)
                #expect(previous.completedAt == reversed.completedAt)
            }
            if change.currentAddress != nil {
                let present: ComparisonRawEvidence = try comparisonRawEvidence(for: change, side: .current, comparison: comparison)
                let reversed: ComparisonRawEvidence = try comparisonRawEvidence(for: inverse, side: .baseline, comparison: reverse)
                #expect(present.address == reversed.address)
                #expect(present.value == reversed.value)
                #expect(present.completedAt == reversed.completedAt)
            }
        }
    }

    @Test
    func typedResolutionPreservesScalarTypesAndContainers() throws {
        let report: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"string":"1","integer":9007199254740993,"decimal":1.5,"boolean":true,"null":null,"array":[],"object":{}}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let expected: [(key: String, value: ProfileValue)] = [
            ("string", .string("1")), ("integer", .integer(9_007_199_254_740_993)),
            ("decimal", .decimal(1.5)), ("boolean", .boolean(true)), ("null", .null),
            ("array", .array([])), ("object", .object([:]))
        ]
        for item in expected {
            let address: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: [.index(0), .field(item.key)])
            #expect(try profileValue(at: address, in: report) == item.value)
        }
    }

    @Test
    func malformedAddressesAndLookupFailuresRemainExplicit() throws {
        let report: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"scalar":1,"array":[1],"empty":[]}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let failures: [(path: [ProfileValuePathComponent], error: ProfileValueAddressError)] = [
            ([], .expectedRecordIndex), ([.field("scalar")], .expectedRecordIndex),
            ([.index(-1)], .invalidIndex(-1)), ([.index(1)], .invalidIndex(1)),
            ([.index(0), .field("missing")], .missingField),
            ([.index(0), .field("scalar"), .field("child")], .expectedObject),
            ([.index(0), .index(0)], .expectedArray),
            ([.index(0), .field("scalar"), .index(0)], .expectedArray),
            ([.index(0), .field("array"), .index(-1)], .invalidIndex(-1)),
            ([.index(0), .field("array"), .index(1)], .invalidIndex(1)),
            ([.index(0), .field("empty"), .index(0)], .invalidIndex(0)),
            ([.index(0), .field("array"), .field("child")], .expectedObject)
        ]
        for failure in failures {
            let address: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: failure.path)
            #expect(throws: failure.error) {
                _ = try profileValue(at: address, in: report)
            }
        }
        let missing: ProfileValueAddress = ProfileValueAddress(dataType: .wifi, path: [.index(0)])
        #expect(throws: ProfileValueAddressError.missingSection(.wifi)) {
            _ = try profileValue(at: missing, in: report)
        }
        let repeated: SystemProfilerReport = SystemProfilerReport(
            sections: report.sections + report.sections, commandArguments: report.commandArguments,
            standardError: report.standardError, startedAt: report.startedAt, completedAt: report.completedAt
        )
        let record: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: [.index(0)])
        #expect(throws: ProfileValueAddressError.repeatedSection(.hardware)) {
            _ = try profileValue(at: record, in: repeated)
        }
    }

    @Test
    func comparisonEvidenceKeepsCapturedReportsDespiteSameTimestampReplacements() throws {
        let baselineDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
        let currentDate: Date = Date(timeIntervalSince1970: 1_700_000_001)
        var baseline: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"value":1}]}"#, completedAt: baselineDate
        )
        var current: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"value":2}]}"#, completedAt: currentDate
        )
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        let change: ReportChange = try #require(comparison.changes.first)
        baseline = try rawEvidenceReport(json: #"{"SPHardwareDataType":[{"value":99}]}"#, completedAt: baselineDate)
        current = try rawEvidenceReport(json: #"{"SPHardwareDataType":[{"value":77}]}"#, completedAt: currentDate)
        #expect(comparison.baselineReport != baseline)
        #expect(comparison.currentReport != current)
        let previous: ComparisonRawEvidence = try comparisonRawEvidence(for: change, side: .baseline, comparison: comparison)
        let present: ComparisonRawEvidence = try comparisonRawEvidence(for: change, side: .current, comparison: comparison)
        #expect(previous.value == .integer(1))
        #expect(present.value == .integer(2))
        #expect(previous.completedAt == baselineDate)
        #expect(present.completedAt == currentDate)
        #expect(try profileValue(at: previous.address, in: baseline) == .integer(99))
        #expect(try profileValue(at: present.address, in: current) == .integer(77))
    }

    @Test
    func evidenceFromAnotherComparisonCannotBecomeAnApparentSuccess() throws {
        let baseline: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"value":1}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let current: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"value":2}]}"#,
            completedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let otherCurrent: SystemProfilerReport = try rawEvidenceReport(
            json: #"{"SPHardwareDataType":[{"value":3}]}"#,
            completedAt: current.completedAt
        )
        let comparison: ReportComparison = try compareReports(baseline: baseline, current: current)
        let otherComparison: ReportComparison = try compareReports(baseline: baseline, current: otherCurrent)
        let otherChange: ReportChange = try #require(otherComparison.changes.first)
        #expect(throws: ComparisonRawEvidenceError.valueMismatch) {
            _ = try comparisonRawEvidence(for: otherChange, side: .current, comparison: comparison)
        }
    }

    @Test
    func importedPaginationFixturesKeepBothSidesAndExactPageBoundaries() throws {
        let directory: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Compatibility", isDirectory: true)
        let reports: [SystemProfilerReport] = try [
            "raw-evidence-pagination-baseline.json", "raw-evidence-pagination-current.json"
        ].map { name in
            try loadComparisonBaseline(
                from: Data(contentsOf: directory.appendingPathComponent(name)),
                importedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
        let comparison: ReportComparison = try compareReports(baseline: reports[0], current: reports[1])
        #expect(comparison.summary.addedCount == 0)
        #expect(comparison.summary.removedCount == 0)
        #expect(comparison.summary.changedCount == 1)
        let change: ReportChange = try #require(comparison.changes.first)
        let address: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")])
        #expect(change.baselineAddress == address)
        #expect(change.currentAddress == address)
        let previous: ComparisonRawEvidence = try comparisonRawEvidence(for: change, side: .baseline, comparison: comparison)
        #expect(try comparisonRawEvidencePages(previous) == [#""short baseline""#])
        let present: ComparisonRawEvidence = try comparisonRawEvidence(for: change, side: .current, comparison: comparison)
        let pages: [String] = try comparisonRawEvidencePages(present)
        #expect(pages.count == 3)
        #expect(pages.map(\.count) == [12_000, 12_000, 17])
        #expect(pages[0].hasPrefix(#""BEGIN-PAGE-1|"#))
        #expect(pages[1].hasPrefix("BEGIN-PAGE-2|"))
        #expect(pages[2] == #"BEGIN-PAGE-3|END""#)
        #expect(try JSONDecoder().decode(ProfileValue.self, from: Data(pages.joined().utf8)) == present.value)
    }

    @Test
    func paginatedRawJSONPreservesLongUnicodeAndScalarTypes() throws {
        let address: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")])
        let completedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
        let original: ProfileValue = .string(String(repeating: "👩🏽‍💻 e\u{301} \"\\\n", count: 3_000))
        let evidence: ComparisonRawEvidence = ComparisonRawEvidence(
            side: .current, address: address, value: original, completedAt: completedAt
        )
        let pages: [String] = try comparisonRawEvidencePages(evidence)
        #expect(pages.count > 1)
        #expect(pages.allSatisfy { !$0.isEmpty && $0.count <= 12_000 })
        #expect(try JSONDecoder().decode(ProfileValue.self, from: Data(pages.joined().utf8)) == original)

        let scalars: [ProfileValue] = [.null, .integer(Int64.max), .boolean(true), .decimal(1.5)]
        for scalar in scalars {
            let scalarEvidence: ComparisonRawEvidence = ComparisonRawEvidence(
                side: .baseline, address: address, value: scalar, completedAt: completedAt
            )
            let scalarPages: [String] = try comparisonRawEvidencePages(scalarEvidence)
            #expect(scalarPages.allSatisfy { !$0.isEmpty && $0.count <= 12_000 })
            #expect(try JSONDecoder().decode(ProfileValue.self, from: Data(scalarPages.joined().utf8)) == scalar)
        }
    }
}

private func rawEvidenceReport(json: String, completedAt: Date) throws -> SystemProfilerReport {
    try loadComparisonBaseline(from: Data(json.utf8), importedAt: completedAt)
}
