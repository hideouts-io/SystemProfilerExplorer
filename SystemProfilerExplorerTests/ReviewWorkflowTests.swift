import Foundation
import CoreGraphics
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

        #expect(snapshotCanBeCompared(SnapshotSummary(snapshot(.full, current)), with: current))
        #expect(!snapshotCanBeCompared(SnapshotSummary(snapshot(.redacted, current)), with: current))
        #expect(!snapshotCanBeCompared(SnapshotSummary(snapshot(.full, otherSubject)), with: current))
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
        #expect(throws: SystemReviewPDFError.renderingFailed) {
            try makeSystemReviewPDF(markdown: "")
        }
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
        #expect(text.split(whereSeparator: \.isNewline) == markdown.split(whereSeparator: \.isNewline))
    }

    @Test
    @MainActor
    func reviewPDFPreservesWrappedSummaryText() throws {
        let report: SystemProfilerReport = workflowReport()
        let selected: [SystemReviewFinding] = selectedSystemReviewFindings(
            report: report,
            selectedSourcePaths: ["SPHardwareDataType.physical_memory"]
        )
        let markdown: String = makeSystemReviewMarkdown(report: report, selectedFindings: selected)
        let document: PDFDocument = try #require(PDFDocument(data: makeSystemReviewPDF(markdown: markdown)))
        let text: String = try #require(document.string)

        #expect(text.filter { !$0.isWhitespace } == markdown.filter { !$0.isWhitespace })
        for index in 0..<document.pageCount {
            #expect(document.page(at: index)?.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792))
        }
    }

    @Test(arguments: [("🧑‍💻", "🧑💻"), ("👩‍🔬", "👩🔬"), ("👨‍👩‍👧", "👨👩👧")])
    @MainActor
    func reviewPDFPreservesJoinedEmojiInLargeDocuments(joined: String, separated: String) throws {
        // Short Core Text documents already join these glyphs; reproduce the
        // mixed-script workload that exceeded its default typesetter limit.
        let suffix: String = String(repeating: " ", count: 24) + "café e\u{301} 界 Ελληνικά 🙂 END\n"
        let joinedWidth: Int = try reviewPDFLeadingInkWidth(String(repeating: joined + suffix, count: 300))
        let separatedWidth: Int = try reviewPDFLeadingInkWidth(String(repeating: separated + suffix, count: 300))

        #expect(joinedWidth * 5 < separatedWidth * 4)
    }

    @Test
    @MainActor
    func reviewPDFPaginatesUnicodeAndPreservesOriginalSummaryBytes() throws {
        let unicode: String = "café e\u{301} 界 Ελληνικά 🙂"
        let markdown: String = (1...400).map { "BEGIN-\($0) \(unicode) END-\($0)" }.joined(separator: "\r\n")
        let document: PDFDocument = try #require(PDFDocument(data: makeSystemReviewPDF(markdown: markdown)))
        let text: String = try #require(document.string)

        #expect(document.pageCount > 1)
        #expect(text.filter { !$0.isWhitespace } == markdown.filter { !$0.isWhitespace })
        for index in 0..<document.pageCount {
            #expect(document.page(at: index)?.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792))
        }

        // PDFKit may omit invisible joiners when extracting correctly shaped
        // glyphs. The raster test checks their appearance; original summary
        // bytes must remain intact independently of PDF text extraction.
        let original: String = unicode + " 🧑‍💻"
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [SystemProfilerSection(dataType: .hardware, items: [.object([
                "_name": .string("Synthetic Unicode"),
                "future_apple_field": .string(original)
            ])])],
            commandArguments: [],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001)
        )
        let selected: [SystemReviewFinding] = selectedSystemReviewFindings(
            report: report,
            selectedSourcePaths: ["SPHardwareDataType.future_apple_field"]
        )
        let summary: String = makeSystemReviewMarkdown(report: report, selectedFindings: selected)
        #expect(Data(summary.utf8).range(of: Data(original.utf8)) != nil)
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

        let comparisonHistory: ComparisonSnapshotHistoryState = .load(from: store)
        #expect(comparisonHistory == .loaded(history))
        #expect(comparisonHistory.comparableSnapshots(with: workflowReport()).map(\.id) == [saved.id])
        #expect(try Data(contentsOf: snapshotDirectoryURL.appendingPathComponent(damagedFileName)) == Data("not a snapshot".utf8))

        _ = try store.saveSnapshot(
            name: "After Update",
            privacy: .full,
            report: workflowReport(),
            retention: .five
        )
        #expect(try store.loadSnapshotHistory().snapshots.count == 2)
    }

    @Test
    func comparisonSnapshotHistoryDistinguishesMissingHistoryWithoutCreatingFiles() {
        let applicationSupportURL: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store: SnapshotStore = SnapshotStore(applicationSupportURL: applicationSupportURL)

        #expect(ComparisonSnapshotHistoryState.load(from: store) == .loaded(
            SnapshotHistory(snapshots: [], unreadableFileNames: [])
        ))
        #expect(!FileManager.default.fileExists(atPath: applicationSupportURL.path))
    }

    @Test
    func comparisonSnapshotHistoryReportsDirectoryFailureAndCanBeRefreshedAfterRepair() throws {
        let fileManager: FileManager = .default
        let applicationSupportURL: URL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            do {
                try fileManager.removeItem(at: applicationSupportURL)
            } catch {
                Issue.record(error)
            }
        }

        let appDirectoryURL: URL = applicationSupportURL
            .appendingPathComponent("com.netctl.SystemProfilerExplorer", isDirectory: true)
        try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true)
        let blockedDirectoryURL: URL = appDirectoryURL.appendingPathComponent("Snapshots")
        let original: Data = Data("Task-owned directory obstruction".utf8)
        try original.write(to: blockedDirectoryURL)
        let store: SnapshotStore = SnapshotStore(applicationSupportURL: applicationSupportURL)

        let failed: ComparisonSnapshotHistoryState = .load(from: store)
        guard case let .unavailable(message) = failed else {
            Issue.record("A snapshot directory failure must be visible instead of an empty history.")
            return
        }
        #expect(!message.isEmpty)
        #expect(failed.comparableSnapshots(with: workflowReport()).isEmpty)
        #expect(try Data(contentsOf: blockedDirectoryURL) == original)

        try fileManager.removeItem(at: blockedDirectoryURL)
        let saved: SystemProfilerSnapshot = try store.saveSnapshot(
            name: "Recovered Baseline",
            privacy: .full,
            report: workflowReport(),
            retention: .unlimited
        )
        _ = try store.saveSnapshot(
            name: "Redacted Baseline",
            privacy: .redacted,
            report: workflowReport(),
            retention: .unlimited
        )

        let refreshed: ComparisonSnapshotHistoryState = .load(from: store)
        #expect(refreshed.comparableSnapshots(with: workflowReport()).map(\.id) == [saved.id])
        #expect(try store.loadSnapshotHistory().snapshots.count == 2)
    }
}

@MainActor
private func reviewPDFLeadingInkWidth(_ markdown: String) throws -> Int {
    let document: PDFDocument = try #require(PDFDocument(data: makeSystemReviewPDF(markdown: markdown)))
    let page: PDFPage = try #require(document.page(at: 0))
    let width: Int = 1_224
    let height: Int = 1_584
    let bytesPerRow: Int = width * 4
    var pixels: [UInt8] = [UInt8](repeating: 255, count: bytesPerRow * height)
    try pixels.withUnsafeMutableBytes { buffer in
        let context: CGContext = try #require(CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: 2, y: 2)
        page.draw(with: .mediaBox, to: context)
    }

    var minimumX: Int = width
    var maximumX: Int = -1
    // Only the leading emoji column lies within the first 100 paper points.
    // The same-host separated control avoids a font-version-specific golden image.
    for y in 0..<height {
        for x in 0..<200 {
            let offset: Int = y * bytesPerRow + x * 4
            if pixels[offset] < 240 || pixels[offset + 1] < 240 || pixels[offset + 2] < 240 {
                minimumX = min(minimumX, x)
                maximumX = max(maximumX, x)
            }
        }
    }
    try #require(maximumX >= minimumX)
    return maximumX - minimumX + 1
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
