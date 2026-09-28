import Foundation
import PDFKit
import Testing
@testable import SystemProfilerExplorer

struct ReviewWorkflowTests {
    @Test
    func queryResultExposesSectionFindingBadges() throws {
        let report: SystemProfilerReport = workflowReport()
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)

        let unfiltered: ReportQueryResult = try index.queryResult(for: FindingQuery(text: "", filter: .all))
        let filtered: ReportQueryResult = try index.queryResult(for: FindingQuery(text: "battery", filter: .all))

        #expect(unfiltered.findingCount(for: .hardware) == 2)
        #expect(unfiltered.findingCount(for: .power) == 1)
        #expect(filtered.findingCount(for: .hardware) == 0)
        #expect(filtered.findingCount(for: .power) == 1)
    }

    @Test
    func explanationCoverageDistinguishesCuratedContextAndUnrecognizedFields() {
        let curated: FieldPresentation = fieldPresentation(
            dataType: .hardware,
            path: ["physical_memory"],
            scalar: .string("32 GB")
        )
        let contextual: FieldPresentation = fieldPresentation(
            dataType: .audio,
            path: ["device_name"],
            scalar: .string("Built-in Output")
        )
        let unrecognized: FieldPresentation = fieldPresentation(
            dataType: .hardware,
            path: ["future_apple_field"],
            scalar: .string("value")
        )

        #expect(explanationCoverage(for: curated) == .curatedField)
        #expect(explanationCoverage(for: contextual) == .generalDataTypeContext)
        #expect(explanationCoverage(for: unrecognized) == .unrecognizedField)
    }

    @Test
    func reviewSummaryUsesOnlySelectedFindingsAndStatesCoverageLimits() {
        let report: SystemProfilerReport = workflowReport()
        let selected: [SystemReviewFinding] = selectedSystemReviewFindings(
            report: report,
            selectedSourcePaths: ["SPHardwareDataType.physical_memory"]
        )
        let markdown: String = makeSystemReviewMarkdown(report: report, selectedFindings: selected)

        #expect(selected.count == 1)
        #expect(markdown.contains(selected[0].presentation.sourcePath))
        #expect(markdown.contains("Privacy warning"))
        #expect(markdown.contains("Skipped Data Types"))
        #expect(markdown.contains("Raw JSON is deliberately exported separately"))
    }

    @Test
    func summaryWorksWithoutBookmarks() {
        let item = WorthReviewingItem(
            id: 0,
            dataType: .storage,
            recordLabel: "Data",
            fieldTitle: "Available Space",
            summary: "Only 9% free (90 GB of 1 TB).",
            sourcePath: "SPStorageDataType.free_space_in_bytes",
            location: "SPStorageDataType[0].free_space_in_bytes"
        )
        let markdown: String = makeSystemReviewMarkdown(
            report: workflowReport(),
            selectedFindings: [],
            glance: ["This Mac runs macOS 27.0."],
            worthReviewingItems: [item]
        )

        #expect(markdown.contains("## At a Glance\n\n- This Mac runs macOS 27.0."))
        #expect(markdown.contains("- **Only 9% free (90 GB of 1 TB).** (Storage › Data › Available Space)"))
        #expect(!markdown.contains("## Bookmarked Findings"))
        #expect(makeSystemReviewMarkdown(report: workflowReport(), selectedFindings: []).contains("Nothing in this scan needs a look."))
    }

    @Test
    func onlyFullSnapshotsOfTheSameReportCanBeCompared() {
        func snapshot(_ privacy: SnapshotPrivacy, _ report: SystemProfilerReport) -> SystemProfilerSnapshot {
            SystemProfilerSnapshot(
                id: UUID(),
                name: "Baseline",
                createdAt: .now,
                privacy: privacy,
                report: privacy == .full ? makeFullReportExport(report) : makeRedactedReportExport(report)
            )
        }
        let current: SystemProfilerReport = workflowReport()
        let otherSubject = SystemProfilerReport(
            sections: [SystemProfilerSection(dataType: .firewall, items: [])],
            commandArguments: [],
            standardError: "",
            startedAt: .now,
            completedAt: .now
        )

        #expect(snapshotCanBeCompared(snapshot(.full, current), with: current))
        #expect(!snapshotCanBeCompared(snapshot(.redacted, current), with: current))
        #expect(!snapshotCanBeCompared(snapshot(.full, otherSubject), with: current))
    }

    @Test
    func snapshotRoundTripPreservesRedactionChoice() throws {
        let snapshot = SystemProfilerSnapshot(
            id: UUID(uuidString: "D97916FE-69A1-4AAB-9E42-E4D1A10AFB47")!,
            name: "Before Update",
            createdAt: Date(timeIntervalSince1970: 2_000),
            privacy: .redacted,
            report: makeRedactedReportExport(workflowReport())
        )

        let decoded: SystemProfilerSnapshot = try decodeSnapshot(encodeSnapshot(snapshot))

        #expect(decoded == snapshot)
    }

    @Test
    @MainActor
    func reviewPDFHasAPDFHeader() throws {
        let pdf: Data = try makeSystemReviewPDF(markdown: "# System Review Summary\n\nSelected findings: 1")
        let header: String = String(decoding: pdf.prefix(4), as: UTF8.self)

        #expect(header == "%PDF")
    }

    @Test
    @MainActor
    func reviewPDFPaginatesLongSummariesWithoutDroppingText() throws {
        let markdown: String = (1...400)
            .map { "Line \($0): selected finding" }
            .joined(separator: "\n")
        let document: PDFDocument = try #require(PDFDocument(data: makeSystemReviewPDF(markdown: markdown)))
        let text: String = document.string ?? ""

        #expect(document.pageCount > 1)
        #expect(document.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792))
        #expect(text.contains("Line 1:"))
        #expect(text.contains("Line 400:"))
    }

    @Test
    func snapshotHistorySkipsUnreadableFilesInsteadOfFailing() throws {
        let applicationSupportURL: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: applicationSupportURL)
        }

        let store: SnapshotStore = SnapshotStore(applicationSupportURL: applicationSupportURL)
        let saved: SystemProfilerSnapshot = try store.saveSnapshot(
            name: "Baseline",
            privacy: .full,
            report: workflowReport(),
            retention: .unlimited
        )
        let snapshotDirectoryURL: URL = applicationSupportURL
            .appendingPathComponent("com.netctl.SystemProfilerExplorer", isDirectory: true)
            .appendingPathComponent("Snapshots", isDirectory: true)
        let damagedFileName: String = "\(UUID().uuidString).systemprofiler-snapshot"
        try Data("not a snapshot".utf8).write(to: snapshotDirectoryURL.appendingPathComponent(damagedFileName))
        try Data("{}".utf8).write(to: snapshotDirectoryURL.appendingPathComponent("renamed.systemprofiler-snapshot"))

        let history: SnapshotHistory = try store.loadSnapshotHistory()

        #expect(history.snapshots.map(\.id) == [saved.id])
        #expect(history.unreadableFileNames == [damagedFileName, "renamed.systemprofiler-snapshot"].sorted())

        _ = try store.saveSnapshot(
            name: "After Update",
            privacy: .full,
            report: workflowReport(),
            retention: .five
        )
        #expect(try store.loadSnapshots().count == 2)
    }
}

private func workflowReport() -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(
                dataType: .hardware,
                items: [
                    .object([
                        "_name": .string("Example Mac"),
                        "physical_memory": .string("32 GB"),
                        "future_apple_field": .string("future")
                    ])
                ]
            ),
            SystemProfilerSection(
                dataType: .power,
                items: [
                    .object([
                        "_name": .string("Battery"),
                        "cycle_count": .integer(12)
                    ])
                ]
            )
        ],
        commandArguments: ["SPHardwareDataType", "SPPowerDataType", "SPStorageDataType", "-json"],
        standardError: "",
        startedAt: Date(timeIntervalSince1970: 1_000),
        completedAt: Date(timeIntervalSince1970: 1_001)
    )
}
