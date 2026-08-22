import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ReportComparisonTests {
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
