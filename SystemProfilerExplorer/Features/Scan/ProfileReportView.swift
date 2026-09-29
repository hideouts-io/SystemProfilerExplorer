import SwiftUI
import UniformTypeIdentifiers

private let recordPageSize: Int = 100
private let largeReportFindingThreshold: Int = 5_000
private let automaticExpansionFindingLimit: Int = 200

private func shouldAutomaticallyExpandResults(
    query: FindingQuery,
    matchCount: Int
) -> Bool {
    !query.normalizedText.isEmpty && matchCount <= automaticExpansionFindingLimit
}

struct ProfileReportView: View {
    let report: SystemProfilerReport
    /// The report's index when it was already built, so showing the report again
    /// doesn't rebuild it. The view builds its own when this is nil.
    var preparedIndex: ReportPresentationIndex?

    @State private var searchText: String = ""
    @State private var selectedFilter: FindingFilter = .all
    @State private var isShowingExportReview: Bool = false
    @State private var presentationIndex: ReportPresentationIndex?
    @State private var displayedQueryResult: ReportQueryResult?
    @State private var isPreparingIndex: Bool = true
    @State private var isSearching: Bool = false
    @State private var indexingErrorMessage: String?
    @State private var queryTask: Task<Void, Never>?
    @State private var recentSearchTask: Task<Void, Never>?
    @State private var isShowingSkippedCollection: Bool = false
    @State private var isShowingSnapshotTimeline: Bool = false
    @State private var isShowingSystemReview: Bool = false
    @State private var highlightedLocation: String?
    @State private var isShowingCoverageDetails: Bool = false
    @State private var isConfirmingSampleExport: Bool = false
    @State private var sampleDocument: ReportExportFileDocument?
    @State private var sampleFilename: String = ""
    @State private var isShowingSampleExporter: Bool = false
    @State private var sampleExportErrorMessage: String?
    @Environment(\.explanationDetailMode) private var detailMode
    @AppStorage("bookmarked-finding-source-paths") private var storedBookmarks: String = ""
    @AppStorage("recent-finding-searches") private var storedRecentSearches: String = ""

    var body: some View {
        Group {
            if let presentationIndex, let displayedQueryResult {
                indexedReportContent(
                    presentationIndex: presentationIndex,
                    queryResult: displayedQueryResult
                )
            } else if let indexingErrorMessage {
                ReportIndexingFailureView(
                    message: indexingErrorMessage,
                    retry: retryIndexing
                )
            } else {
                ReportIndexingView()
            }
        }
        .environment(\.valueReportContext, valueReportContext(for: report))
        .task(id: report.completedAt) {
            await preparePresentationIndex()
        }
        .onChange(of: query) { newQuery in
            scheduleQuery(newQuery)
        }
        .onDisappear {
            queryTask?.cancel()
            recentSearchTask?.cancel()
        }
        .sheet(isPresented: $isShowingExportReview) {
            ReportExportReviewView(report: report)
        }
        .sheet(isPresented: $isShowingSkippedCollection) {
            SkippedCollectionView(
                coverage: collectionCoverage(for: report),
                standardError: report.standardError
            )
        }
        .sheet(isPresented: $isShowingSnapshotTimeline) {
            SnapshotTimelineView(currentReport: report)
        }
        .sheet(isPresented: $isShowingSystemReview) {
            SystemReviewSummaryView(
                report: report,
                selectedSourcePaths: bookmarkedSourcePaths,
                glance: presentationIndex?.glance ?? [],
                worthReviewingItems: presentationIndex?.worthReviewingItems ?? []
            )
        }
    }

    @ViewBuilder
    private func indexedReportContent(
        presentationIndex: ReportPresentationIndex,
        queryResult: ReportQueryResult
    ) -> some View {
        let summary: ReportSummary = presentationIndex.summary
        let matchCount: Int = queryResult.findingCount
        let displayedQuery: FindingQuery = queryResult.query
        let automaticallyExpandResults: Bool = shouldAutomaticallyExpandResults(
            query: displayedQuery,
            matchCount: matchCount
        )

        let coverage: CollectionCoverage = collectionCoverage(for: report)

        VStack(alignment: .leading, spacing: 16) {
            AtAGlanceCard(
                sentences: presentationIndex.glance,
                worthReviewingItems: presentationIndex.worthReviewingItems,
                showItem: showWorthReviewingItem,
                showAllWorthReviewing: showAllWorthReviewing
            )

            CollectionCoverageSummary(
                coverage: coverage,
                isShowingDetails: $isShowingCoverageDetails,
                showSkippedCollection: { isShowingSkippedCollection = true }
            )

            if detailMode == .developer {
                ReportSummaryStrip(summary: summary)

                if summary.findingCount >= largeReportFindingThreshold {
                    LargeReportNotice()
                }
            }

            FindingControls(
                searchText: $searchText,
                selectedFilter: $selectedFilter,
                isSearching: isSearching,
                recentSearches: recentSearches,
                applyRecentSearch: applyRecentSearch,
                submitSearch: submitSearch
            )

            if !bookmarkedSourcePaths.isEmpty {
                FindingBookmarkBar(
                    bookmarkCount: bookmarkedSourcePaths.count,
                    bookmarkedSourcePaths: bookmarkedSourcePaths,
                    openSourceLocation: openSourceLocation
                )
            }

            HStack(spacing: 10) {
                Text(resultDescription(
                    matchCount: matchCount,
                    totalCount: summary.findingCount,
                    query: displayedQuery
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                reportActions
            }

            if matchCount == 0 {
                NoMatchingFindingsView(clearQuery: clearQuery)
            } else {
                ForEach(report.sections) { section in
                    ProfileSectionView(
                        section: section,
                        queryResult: queryResult,
                        worthReviewingCounts: presentationIndex.worthReviewingCountsByRecord(for: section.dataType),
                        automaticallyExpandResults: automaticallyExpandResults,
                        bookmarkedSourcePaths: bookmarkedSourcePaths,
                        toggleBookmark: toggleBookmark,
                        openSourceLocation: openSourceLocation,
                        highlightedLocation: highlightedLocation
                    )
                }
            }

            if detailMode == .developer {
                ScanProvenanceView(report: report)
            }
        }
    }

    @ViewBuilder
    private var reportActions: some View {
        Button {
            isShowingSnapshotTimeline = true
        } label: {
            Label("Snapshots", systemImage: "clock.arrow.circlepath")
        }
        .buttonStyle(.bordered)
        .help("Save this report as a baseline to compare with later in What Changed")
        .accessibilityIdentifier("open-snapshots")

        Menu {
            Button("Summary…") {
                isShowingSystemReview = true
            }
            .help("A readable Markdown or PDF summary")

            Button("Report File…") {
                isShowingExportReview = true
            }
            .help("The full scan data as JSON, redacted or complete")

            if detailMode == .developer {
                Divider()

                Button("Anonymized Sample…") {
                    isConfirmingSampleExport = true
                }
                .help("A copy without personal values, for contributing a test sample to the project")
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .fixedSize()
        .accessibilityIdentifier("share-report")
        .confirmationDialog("Export an anonymized sample?", isPresented: $isConfirmingSampleExport) {
            Button("Export…", action: prepareSampleExport)
        } message: {
            Text("The sample keeps field names, numbers, on/off values, and the values the app explains, so it shows how this Mac reports them. Names, serial numbers, addresses, paths, and log text are removed. Open the file and check it before you share it.")
        }
        .fileExporter(
            isPresented: $isShowingSampleExporter,
            document: sampleDocument,
            contentType: ReportExportFileDocument.contentType,
            defaultFilename: sampleFilename
        ) { _ in
            sampleDocument = nil
        }
        .alert("Export Failed", isPresented: sampleExportErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sampleExportErrorMessage ?? "The sample could not be created.")
        }
    }

    private var sampleExportErrorBinding: Binding<Bool> {
        Binding(
            get: { sampleExportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    sampleExportErrorMessage = nil
                }
            }
        )
    }

    private func prepareSampleExport() {
        let reportToExport: SystemProfilerReport = report

        Task {
            do {
                let prepared: (data: Data, filename: String) = try await Task.detached(priority: .userInitiated) {
                    let data: Data = try encodeAnonymizedSample(makeAnonymizedSample(reportToExport))
                    return (data: data, filename: anonymizedSampleFilename(reportToExport))
                }.value

                sampleDocument = ReportExportFileDocument(data: prepared.data)
                sampleFilename = prepared.filename
                isShowingSampleExporter = true
            } catch {
                sampleExportErrorMessage = "The sample could not be created. \(error.localizedDescription)"
            }
        }
    }

    /// Shows only the values worth a look, with the chosen one highlighted.
    private func showWorthReviewingItem(_ item: WorthReviewingItem) {
        searchText = ""
        selectedFilter = .worthALook
        highlightedLocation = item.location
    }

    private func showAllWorthReviewing() {
        searchText = ""
        selectedFilter = .worthALook
        highlightedLocation = nil
    }

    private var query: FindingQuery {
        FindingQuery(text: searchText, filter: selectedFilter)
    }

    private func preparePresentationIndex() async {
        let currentReport: SystemProfilerReport = report
        let currentQuery: FindingQuery = query
        let existingIndex: ReportPresentationIndex? = preparedIndex

        queryTask?.cancel()
        isSearching = false
        indexingErrorMessage = nil

        // With no search or filter, a prepared index shows the report immediately.
        if let existingIndex, !currentQuery.isActive,
           let result = try? existingIndex.queryResult(for: currentQuery) {
            presentationIndex = existingIndex
            displayedQueryResult = result
            isPreparingIndex = false
            return
        }

        isPreparingIndex = true
        presentationIndex = nil
        displayedQueryResult = nil

        do {
            let indexTask: Task<(ReportPresentationIndex, ReportQueryResult), any Error> = Task.detached(
                priority: .userInitiated
            ) {
                let index: ReportPresentationIndex = try existingIndex ?? makeReportPresentationIndex(currentReport)
                let result: ReportQueryResult = try index.queryResult(for: currentQuery)
                return (index, result)
            }
            let prepared: (ReportPresentationIndex, ReportQueryResult) = try await withTaskCancellationHandler {
                try await indexTask.value
            } onCancel: {
                indexTask.cancel()
            }

            try Task.checkCancellation()
            presentationIndex = prepared.0
            displayedQueryResult = prepared.1
        } catch is CancellationError {
            return
        } catch {
            indexingErrorMessage = "The report could not be prepared for display. \(error.localizedDescription)"
        }

        isPreparingIndex = false

        // The search or filter may have changed while the index was being built.
        if presentationIndex != nil, query != currentQuery {
            scheduleQuery(query)
        }
    }

    private func retryIndexing() {
        Task {
            await preparePresentationIndex()
        }
    }

    private func scheduleQuery(_ newQuery: FindingQuery) {
        guard !isPreparingIndex, let presentationIndex else {
            return
        }

        queryTask?.cancel()
        isSearching = true

        queryTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(250))
                let searchTask: Task<ReportQueryResult, any Error> = Task.detached(priority: .userInitiated) {
                    try presentationIndex.queryResult(for: newQuery)
                }
                let result: ReportQueryResult = try await withTaskCancellationHandler {
                    try await searchTask.value
                } onCancel: {
                    searchTask.cancel()
                }

                try Task.checkCancellation()
                displayedQueryResult = result
                isSearching = false
                queryTask = nil
                scheduleRecentSearchRecording(newQuery)
            } catch is CancellationError {
                return
            } catch {
                indexingErrorMessage = "The report search failed. \(error.localizedDescription)"
                isSearching = false
                queryTask = nil
            }
        }
    }

    private func resultDescription(
        matchCount: Int,
        totalCount: Int,
        query: FindingQuery
    ) -> String {
        if query.isActive {
            return "Showing \(matchCount.formatted()) of \(totalCount.formatted()) \(findingNoun(totalCount, mode: detailMode))"
        }

        return "\(totalCount.formatted()) \(findingNoun(totalCount, mode: detailMode))"
    }

    private func clearQuery() {
        searchText = ""
        selectedFilter = .all
        highlightedLocation = nil
    }

    private var bookmarkedSourcePaths: Set<String> {
        Set(storedBookmarks.split(separator: "\n").map(String.init))
    }

    private var recentSearches: [String] {
        storedRecentSearches
            .split(separator: "\n")
            .map(String.init)
    }

    /// Bookmarks store a value's location. A bookmark saved before locations existed holds
    /// the field's source path; toggling that value removes it.
    private func toggleBookmark(_ location: String) {
        var bookmarks: Set<String> = bookmarkedSourcePaths
        let legacySourcePath: String = sourcePath(fromLocation: location)

        if bookmarks.contains(location) {
            bookmarks.remove(location)
        } else if bookmarks.contains(legacySourcePath) {
            bookmarks.remove(legacySourcePath)
        } else {
            bookmarks.insert(location)
        }

        storedBookmarks = bookmarks.sorted().joined(separator: "\n")
    }

    /// Shows a value: searches for its field and highlights the exact row.
    private func openSourceLocation(_ location: String) {
        selectedFilter = .all
        highlightedLocation = location
        searchText = sourcePath(fromLocation: location)
    }

    private func applyRecentSearch(_ search: String) {
        highlightedLocation = nil
        searchText = search
    }

    /// Saves a search once it has been left unchanged for a moment, so partly typed
    /// words don't fill the Recent menu. Pressing Return saves it immediately.
    private func scheduleRecentSearchRecording(_ findingQuery: FindingQuery) {
        recentSearchTask?.cancel()
        recentSearchTask = Task {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            if query == findingQuery {
                recordRecentSearch(findingQuery)
            }
        }
    }

    private func submitSearch() {
        recentSearchTask?.cancel()
        recordRecentSearch(query)
    }

    private func recordRecentSearch(_ findingQuery: FindingQuery) {
        let search: String = findingQuery.normalizedText
        guard !search.isEmpty else {
            return
        }

        let updatedSearches: [String] = ([search] + recentSearches.filter { $0 != search })
            .prefix(8)
            .map { $0 }
        storedRecentSearches = updatedSearches.joined(separator: "\n")
    }
}

private struct LargeReportNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("Large report mode")
                    .font(.subheadline.weight(.semibold))
                Text("Records are presented in pages of 100 to keep navigation responsive. Search and filters still evaluate the complete collected report, and every record remains available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("large-report-notice")
    }
}

/// One line when every requested data type was collected; the full breakdown when
/// something is incomplete or the user asks for details.
private struct CollectionCoverageSummary: View {
    let coverage: CollectionCoverage
    @Binding var isShowingDetails: Bool
    let showSkippedCollection: () -> Void

    var body: some View {
        if !coverage.incompleteEntries.isEmpty || isShowingDetails {
            VStack(alignment: .leading, spacing: 6) {
                CollectionCoverageCard(coverage: coverage, showSkippedCollection: showSkippedCollection)

                if coverage.incompleteEntries.isEmpty {
                    Button("Hide collection details") { isShowingDetails = false }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        } else {
            HStack(spacing: 8) {
                Label {
                    Text(completeDescription)
                } icon: {
                    Image(systemName: ValueStatus.normal.symbolName)
                        .foregroundStyle(ValueStatus.normal.tint)
                }

                Button("Details") { isShowingDetails = true }
                    .buttonStyle(.link)

                Spacer()
            }
            .font(.callout)
            .accessibilityIdentifier("collection-coverage-summary")
        }
    }

    private var completeDescription: String {
        let count: Int = coverage.entries.count
        let noun: String = count == 1 ? "data type" : "data types"

        return switch coverage.source {
        case .liveScan: "All \(count) requested \(noun) were collected."
        case .importedReport: "Imported report with \(count) \(noun)."
        }
    }
}

private struct CollectionCoverageCard: View {
    let coverage: CollectionCoverage
    let showSkippedCollection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Label("Collection coverage", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Text(coverage.source.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                CollectionCoverageMetric(
                    title: "Collected",
                    count: coverage.collectedCount,
                    symbolName: CollectionDataTypeStatus.collected.symbolName,
                    tint: .green
                )
                CollectionCoverageMetric(
                    title: "No records",
                    count: coverage.emptyCount,
                    symbolName: CollectionDataTypeStatus.empty.symbolName,
                    tint: .secondary
                )
                CollectionCoverageMetric(
                    title: "Skipped",
                    count: coverage.skippedCount,
                    symbolName: CollectionDataTypeStatus.skipped.symbolName,
                    tint: .orange
                )
            }

            HStack(spacing: 10) {
                CollectionCoverageMetric(
                    title: "Unavailable",
                    count: coverage.unavailableCount,
                    symbolName: CollectionDataTypeStatus.unavailable.symbolName,
                    tint: .orange
                )
                CollectionCoverageMetric(
                    title: "Timed out",
                    count: coverage.timedOutCount,
                    symbolName: CollectionDataTypeStatus.timedOut.symbolName,
                    tint: .orange
                )
                CollectionCoverageMetric(
                    title: "Permission",
                    count: coverage.permissionLimitedCount,
                    symbolName: CollectionDataTypeStatus.permissionLimited.symbolName,
                    tint: .orange
                )
            }

            Text(coverageExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !coverage.incompleteEntries.isEmpty {
                Button(action: showSkippedCollection) {
                    Label(
                        "View Incomplete Collection (\(coverage.incompleteEntries.count))",
                        systemImage: "list.bullet.rectangle"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("view-incomplete-collection")
            }
        }
        .padding(16)
        .background(coverageTint.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(coverageTint.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("collection-coverage")
    }

    /// Orange only when something wasn't collected.
    private var coverageTint: Color {
        coverage.incompleteEntries.isEmpty ? .secondary : .orange
    }

    private var coverageExplanation: String {
        switch coverage.source {
        case .liveScan:
            if !coverage.incompleteEntries.isEmpty {
                return "Incomplete sections were requested but did not return JSON. Unavailable, timeout, and permission labels require matching diagnostic text; otherwise the app records them as skipped rather than inventing a cause."
            }

            return "Every requested data type returned JSON. No records means system_profiler returned an empty section, not that collection was skipped."

        case .importedReport:
            return "This imported JSON does not preserve the original command scope. Coverage reflects only the data types included by the source file."
        }
    }
}

private struct CollectionCoverageMetric: View {
    let title: String
    let count: Int
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
            Text("\(count) \(title)")
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct SkippedCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    let coverage: CollectionCoverage
    let standardError: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Incomplete Collection")
                    .font(.title2.weight(.semibold))
                Text("These data types were requested during the live scan but system_profiler did not return JSON for them.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            List {
                Section("Incomplete data types") {
                    ForEach(coverage.incompleteEntries) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(entry.dataType.title, systemImage: entry.status.symbolName)
                                .foregroundStyle(entry.status == .skipped ? .orange : .red)
                            Text(entry.dataType.rawValue)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }

                Section("Interpretation") {
                    Text("A missing section is not evidence that the associated hardware, service, or setting is absent. When a timeout, permission, or unavailable label appears, it is derived from system_profiler diagnostic text for the scan and may not identify an individual data type. Otherwise the app records the section as skipped rather than assigning a cause without evidence.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !standardError.isEmpty {
                    Section("system_profiler diagnostic output") {
                        Text(standardError)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done", action: dismiss.callAsFunction)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(minWidth: 580, minHeight: 460)
        .accessibilityIdentifier("skipped-collection-sheet")
    }
}

private struct ReportIndexingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Preparing Report")
                .font(.headline)
            Text("Building a local search index so large reports remain responsive.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("report-index-progress")
    }
}

private struct ReportIndexingFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("Report Preparation Failed")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("Try Again", action: retry)
                .accessibilityIdentifier("retry-report-index")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("report-index-failure")
    }
}

private struct ReportSummaryStrip: View {
    let summary: ReportSummary

    var body: some View {
        HStack(spacing: 10) {
            SummaryCard(
                title: "Records",
                value: summary.recordCount,
                symbolName: "square.stack.3d.up",
                tint: .blue
            )
            SummaryCard(
                title: "Findings",
                value: summary.findingCount,
                symbolName: "list.bullet.rectangle",
                tint: .cyan
            )
            SummaryCard(
                title: "Explained",
                value: summary.explainedFindingCount,
                symbolName: "text.book.closed",
                tint: .green
            )
            SummaryCard(
                title: "Privacy",
                value: summary.privacyFindingCount,
                symbolName: "eye.slash",
                tint: .purple
            )
        }
        .accessibilityIdentifier("report-summary")
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Int
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text(value.formatted())
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
        }
    }
}

private struct FindingControls: View {
    @Binding var searchText: String
    @Binding var selectedFilter: FindingFilter
    let isSearching: Bool
    let recentSearches: [String]
    let applyRecentSearch: (String) -> Void
    let submitSearch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search values and explanations", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit(submitSearch)
                    .accessibilityIdentifier("finding-search")

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Searching report")
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .accessibilityIdentifier("clear-finding-search")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }

            Menu {
                if recentSearches.isEmpty {
                    Text("Recent searches appear here.")
                } else {
                    ForEach(recentSearches, id: \.self) { search in
                        Button(search) {
                            applyRecentSearch(search)
                        }
                    }
                }
            } label: {
                Label("Recent", systemImage: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton)
            .accessibilityIdentifier("recent-finding-searches")

            Picker("Finding filter", selection: $selectedFilter) {
                ForEach(FindingFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbolName)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 470)
            .accessibilityIdentifier("finding-filter")
        }
    }
}

private struct FindingBookmarkBar: View {
    let bookmarkCount: Int
    let bookmarkedSourcePaths: Set<String>
    let openSourceLocation: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label(
                "\(bookmarkCount) \(bookmarkCount == 1 ? "bookmark" : "bookmarks")",
                systemImage: bookmarkCount == 0 ? "bookmark" : "bookmark.fill"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(bookmarkCount == 0 ? .secondary : Color.accentColor)

            Text("Bookmark a finding to include it in a System Review Summary.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !bookmarkedSourcePaths.isEmpty {
                Menu("Open Bookmark") {
                    ForEach(bookmarkedSourcePaths.sorted(), id: \.self) { sourcePath in
                        Button(sourcePath) {
                            openSourceLocation(sourcePath)
                        }
                    }
                }
                .accessibilityIdentifier("open-bookmarked-finding")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("finding-bookmarks")
    }
}

private struct NoMatchingFindingsView: View {
    let clearQuery: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("No matching findings")
                .font(.headline)
            Text("Try a different term or show all finding types.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Clear Search and Filters", action: clearQuery)
                .accessibilityIdentifier("clear-finding-query")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ProfileSectionView: View {
    let section: SystemProfilerSection
    let queryResult: ReportQueryResult
    /// Worth-a-look findings per record index, shown on collapsed record rows.
    let worthReviewingCounts: [Int: Int]
    let automaticallyExpandResults: Bool
    let bookmarkedSourcePaths: Set<String>
    let toggleBookmark: (String) -> Void
    let openSourceLocation: (String) -> Void
    let highlightedLocation: String?

    @State private var visibleRecordLimit: Int = recordPageSize
    @Environment(\.explanationDetailMode) private var detailMode

    var body: some View {
        let selection: MatchingRecordSelection = queryResult.recordSelection(
            for: section.dataType,
            visibleLimit: visibleRecordLimit
        )
        let visibleRecords: [ProfileRecord] = profileRecords(selection)

        if selection.matchingCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(dataTypeTitle(section.dataType))
                        .font(.title3.weight(.semibold))
                    if detailMode == .developer {
                        FindingCountBadge(count: queryResult.findingCount(for: section.dataType))
                    }
                    Spacer()
                    Text(recordDescription(selection: selection))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: 0) {
                    ForEach(visibleRecords) { record in
                        ProfileValueDisclosure(
                            label: recordDisplayLabel(record.value, fallback: "Record \(record.index + 1)"),
                            value: record.value,
                            depth: 0,
                            dataType: section.dataType,
                            path: [],
                            query: queryResult.query,
                            automaticallyExpandResults: automaticallyExpandResults,
                            bookmarkedSourcePaths: bookmarkedSourcePaths,
                            toggleBookmark: toggleBookmark,
                            openSourceLocation: openSourceLocation,
                            highlightedLocation: highlightedLocation,
                            siblings: [:],
                            recordIndex: record.index,
                            arrayIndices: [],
                            worthReviewingCount: worthReviewingCounts[record.index] ?? 0,
                            expandsByDefault: visibleRecords.count == 1
                        )

                        if record.id != visibleRecords.last?.id {
                            Divider()
                        }
                    }

                    if visibleRecords.count < selection.matchingCount {
                        Divider()
                        Button {
                            visibleRecordLimit += recordPageSize
                        } label: {
                            Label(
                                showMoreTitle(selection: selection),
                                systemImage: "chevron.down.circle"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityIdentifier("show-more-records-\(section.dataType.rawValue)")
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                }
            }
            .onChange(of: queryResult.query) { _ in
                visibleRecordLimit = recordPageSize
            }
        }
    }

    private func profileRecords(_ selection: MatchingRecordSelection) -> [ProfileRecord] {
        selection.visibleIndices.map { index in
            ProfileRecord(index: index, value: section.items[index])
        }
    }

    private func recordDescription(selection: MatchingRecordSelection) -> String {
        if selection.visibleIndices.count == selection.matchingCount {
            let count: Int = selection.matchingCount
            return "\(count) \(count == 1 ? "record" : "records")"
        }

        return "Showing \(selection.visibleIndices.count) of \(selection.matchingCount) records"
    }

    private func showMoreTitle(selection: MatchingRecordSelection) -> String {
        let remainingCount: Int = selection.matchingCount - selection.visibleIndices.count
        let nextPageCount: Int = min(recordPageSize, remainingCount)
        return "Show \(nextPageCount) More \(nextPageCount == 1 ? "Record" : "Records")"
    }
}

private struct FindingCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count.formatted()) findings")
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.11), in: Capsule())
            .accessibilityLabel("\(count) findings in this section")
    }
}

private struct ProfileValueDisclosure: View {
    let label: String
    let value: ProfileValue
    let depth: Int
    let dataType: SystemProfilerDataType
    let path: [String]
    let query: FindingQuery
    let automaticallyExpandResults: Bool
    let bookmarkedSourcePaths: Set<String>
    let toggleBookmark: (String) -> Void
    let openSourceLocation: (String) -> Void
    let highlightedLocation: String?
    /// The other fields of the object containing this value, for context-aware value explanations.
    let siblings: [String: ProfileValue]
    /// Which record and array items this value is in, for its location.
    let recordIndex: Int
    let arrayIndices: [Int]
    /// Worth-a-look findings inside this group, shown while it's collapsed.
    var worthReviewingCount: Int = 0
    /// Open without a click, as for the only record in a section.
    var expandsByDefault: Bool = false

    @Environment(\.valueReportContext) private var valueReportContext
    /// The user's own expand or collapse choice, which overrides automatic expansion.
    @State private var manualExpansion: Bool?

    var body: some View {
        switch value {
        case let .object(object):
            let fields: [ProfileField] = filteredObjectFields(object)
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(spacing: 0) {
                    ForEach(fields) { field in
                        ProfileFieldRow(
                            label: displayName(for: field.key),
                            value: field.value,
                            depth: depth + 1,
                            dataType: dataType,
                            path: path + [field.key],
                            query: descendantQuery,
                            automaticallyExpandResults: automaticallyExpandResults,
                            bookmarkedSourcePaths: bookmarkedSourcePaths,
                            toggleBookmark: toggleBookmark,
                            openSourceLocation: openSourceLocation,
                            highlightedLocation: highlightedLocation,
                            siblings: object,
                            recordIndex: recordIndex,
                            arrayIndices: arrayIndices
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                ProfileGroupLabel(
                    label: friendlyReportGroupName(label),
                    count: fields.count,
                    depth: depth,
                    worthReviewingCount: worthReviewingCount
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .onChange(of: highlightedLocation) { _ in
                revealHighlightedLocation()
            }

        case let .array(values):
            let items: [ProfileArrayItem] = filteredArrayItems(values)
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ProfileFieldRow(
                            label: recordDisplayLabel(item.value, fallback: "Item \(item.index + 1)"),
                            value: item.value,
                            depth: depth + 1,
                            dataType: dataType,
                            path: path + ["[]"],
                            query: descendantQuery,
                            automaticallyExpandResults: automaticallyExpandResults,
                            bookmarkedSourcePaths: bookmarkedSourcePaths,
                            toggleBookmark: toggleBookmark,
                            openSourceLocation: openSourceLocation,
                            highlightedLocation: highlightedLocation,
                            siblings: [:],
                            recordIndex: recordIndex,
                            arrayIndices: arrayIndices + [item.index]
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                ProfileGroupLabel(
                    label: friendlyReportGroupName(label),
                    count: items.count,
                    depth: depth,
                    worthReviewingCount: worthReviewingCount
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .onChange(of: highlightedLocation) { _ in
                revealHighlightedLocation()
            }

        case let .string(value):
            scalarRow(scalar: .string(value))
        case let .integer(value):
            scalarRow(scalar: .integer(value))
        case let .decimal(value):
            scalarRow(scalar: .decimal(value))
        case let .boolean(value):
            scalarRow(scalar: .boolean(value))
        case .null:
            scalarRow(scalar: .null)
        }
    }

    /// A group the user collapsed opens again when a value inside it is shown.
    private func revealHighlightedLocation() {
        if containsHighlightedLocation {
            manualExpansion = nil
        }
    }

    private var descendantQuery: FindingQuery {
        queryForDescendants(parentLabel: label, query: query)
    }

    private func scalarRow(scalar: ProfileScalar) -> ScalarProfileRow {
        let presentation: FieldPresentation = fieldPresentation(
            dataType: dataType,
            path: path,
            scalar: scalar
        )

        let location: String = findingLocation(
            dataType: dataType,
            recordIndex: recordIndex,
            path: path,
            arrayIndices: arrayIndices
        )

        return ScalarProfileRow(
            presentation: presentation,
            location: location,
            valueExplanation: presentation.isLogContent ? nil : valueExplanation(
                dataType: dataType,
                path: path,
                scalar: scalar,
                siblings: siblings,
                report: valueReportContext
            ),
            depth: depth,
            isBookmarked: bookmarkMatches(bookmarkedSourcePaths, location: location, sourcePath: presentation.sourcePath),
            toggleBookmark: toggleBookmark,
            openSourceLocation: openSourceLocation,
            isHighlighted: highlightedLocation == location || highlightedLocation == presentation.sourcePath
        )
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { manualExpansion ?? (automaticallyExpandResults || expandsByDefault || containsHighlightedLocation) },
            set: { manualExpansion = $0 }
        )
    }

    /// Whether the highlighted value is inside this group, so it opens to show it.
    private var containsHighlightedLocation: Bool {
        guard let highlightedLocation else {
            return false
        }

        return locationIsInsideGroup(
            highlightedLocation,
            groupLocation: findingLocation(
                dataType: dataType,
                recordIndex: recordIndex,
                path: path,
                arrayIndices: arrayIndices
            )
        )
    }

    private func filteredObjectFields(_ object: [String: ProfileValue]) -> [ProfileField] {
        let fields: [ProfileField] = visibleObjectFields(object)

        guard descendantQuery.isActive else {
            return fields
        }

        return fields.filter { field in
            profileValueMatches(
                field.value,
                label: displayName(for: field.key),
                dataType: dataType,
                path: path + [field.key],
                query: descendantQuery,
                siblings: object,
                report: valueReportContext
            )
        }
    }

    private func filteredArrayItems(_ values: [ProfileValue]) -> [ProfileArrayItem] {
        guard descendantQuery.isActive else {
            return values.enumerated().map { index, value in
                ProfileArrayItem(index: index, value: value)
            }
        }

        return values.enumerated().compactMap { index, value in
            let itemLabel: String = recordDisplayLabel(value, fallback: "Item \(index + 1)")

            guard profileValueMatches(
                value,
                label: itemLabel,
                dataType: dataType,
                path: path + ["[]"],
                query: descendantQuery,
                report: valueReportContext
            ) else {
                return nil
            }

            return ProfileArrayItem(index: index, value: value)
        }
    }
}

private struct ProfileFieldRow: View {
    let label: String
    let value: ProfileValue
    let depth: Int
    let dataType: SystemProfilerDataType
    let path: [String]
    let query: FindingQuery
    let automaticallyExpandResults: Bool
    let bookmarkedSourcePaths: Set<String>
    let toggleBookmark: (String) -> Void
    let openSourceLocation: (String) -> Void
    let highlightedLocation: String?
    let siblings: [String: ProfileValue]
    let recordIndex: Int
    let arrayIndices: [Int]

    var body: some View {
        ProfileValueDisclosure(
            label: label,
            value: value,
            depth: depth,
            dataType: dataType,
            path: path,
            query: query,
            automaticallyExpandResults: automaticallyExpandResults,
            bookmarkedSourcePaths: bookmarkedSourcePaths,
            toggleBookmark: toggleBookmark,
            openSourceLocation: openSourceLocation,
            highlightedLocation: highlightedLocation,
            siblings: siblings,
            recordIndex: recordIndex,
            arrayIndices: arrayIndices
        )

        if shouldShowDivider(after: value) {
            Divider()
                .padding(.leading, CGFloat(depth * 14))
        }
    }
}

private struct ProfileGroupLabel: View {
    let label: String
    let count: Int
    let depth: Int
    let worthReviewingCount: Int

    @Environment(\.explanationDetailMode) private var detailMode

    var body: some View {
        HStack {
            Text(label)
                .font(depth == 0 ? .headline : .subheadline.weight(.medium))

            if worthReviewingCount > 0 {
                Label {
                    Text("\(worthReviewingCount) worth a look")
                } icon: {
                    Image(systemName: ValueStatus.worthReviewing.symbolName)
                        .foregroundStyle(ValueStatus.worthReviewing.tint)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(ValueStatus.worthReviewing.tint.opacity(0.13), in: Capsule())
                .accessibilityIdentifier("record-worth-a-look")
            }

            Spacer()

            // Field counts are a developer detail.
            if detailMode == .developer {
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                    .help("\(count) fields")
            }
        }
    }
}

private struct ScalarProfileRow: View {
    let presentation: FieldPresentation
    /// This value's exact position, used for its bookmark and "show source" link.
    let location: String
    let valueExplanation: ValueExplanation?
    let depth: Int
    let isBookmarked: Bool
    let toggleBookmark: (String) -> Void
    let openSourceLocation: (String) -> Void
    let isHighlighted: Bool

    @Environment(\.explanationDetailMode) private var detailMode

    var body: some View {
        DisclosureGroup {
            // The value comes first; text about the field in general sits in one small
            // collapsed area below it, so it isn't repeated at full size on every row.
            if let valueExplanation {
                ValueMeaningView(explanation: valueExplanation)
            }

            if presentation.isLogContent {
                DiagnosticLogView(presentation: presentation, openSourceLocation: openThisLocation)
            } else {
                AboutThisFieldView(
                    presentation: presentation,
                    startsExpanded: aboutThisFieldStartsExpanded(valueExplanation: valueExplanation),
                    openSourceLocation: openThisLocation
                )

                GlossaryTermsRow(texts: explanationTexts)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                scalarHeader

                if let valueExplanation {
                    ValueSummaryLine(explanation: valueExplanation)
                }

                if detailMode == .developer {
                    ScalarDeveloperDetails(presentation: presentation)
                }
            }
        }
        .padding(.leading, CGFloat(depth * 14))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isHighlighted ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .contextMenu {
            Button("Copy Value") {
                copyToPasteboard(presentation.rawValue)
            }
            Button("Copy Source Path") {
                copyToPasteboard(presentation.sourcePath)
            }
            Button("Copy as Markdown") {
                copyToPasteboard(findingMarkdown(presentation: presentation, valueExplanation: valueExplanation))
            }
        }
        .accessibilityIdentifier("finding-\(presentation.sourcePath)")
    }

    /// "Show Raw Source Location" in this row opens this exact value, not every record.
    private var openThisLocation: (String) -> Void {
        { _ in openSourceLocation(location) }
    }

    private var explanationTexts: [String] {
        var texts: [String] = []

        if let valueExplanation {
            texts += [
                valueExplanation.summary,
                valueExplanation.detail,
                valueExplanation.significance,
                valueExplanation.suggestedAction
            ].compactMap { $0 }
            texts += valueExplanation.confidence?.reasons ?? []
        }

        if let explanation = presentation.explanation {
            texts += [explanation.meaning, explanation.significance, explanation.interpretation, explanation.privacy].compactMap { $0 }
        }

        return texts
    }

    private var scalarHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(presentation.title)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 280, alignment: .leading)

            Spacer(minLength: 12)

            Text(presentation.isLogContent ? "Log excerpt • expand to review" : presentation.displayedValue)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)

            Button {
                toggleBookmark(location)
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isBookmarked ? Color.accentColor : .secondary)
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark finding")
            .accessibilityIdentifier("bookmark-\(presentation.sourcePath)")
        }
    }
}

/// Raw details shown under a finding in Developer mode.
private struct ScalarDeveloperDetails: View {
    let presentation: FieldPresentation

    var body: some View {
        HStack(spacing: 14) {
            Text(presentation.sourcePath)
                .lineLimit(1)
                .truncationMode(.middle)

            if presentation.displayedValue != presentation.rawValue {
                Text("raw: \(presentation.rawValue)")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(.tertiary)
        .textSelection(.enabled)
        .accessibilityIdentifier("developer-details")
    }
}

private struct ScanProvenanceView: View {
    let report: SystemProfilerReport

    var body: some View {
        DisclosureGroup("Collection details") {
            VStack(alignment: .leading, spacing: 8) {
                if report.commandArguments.isEmpty {
                    LabeledContent("Source", value: "Imported system_profiler JSON")
                    LabeledContent("Imported", value: report.completedAt.formatted(date: .abbreviated, time: .standard))
                } else {
                    LabeledContent("Command", value: "/usr/sbin/system_profiler \(report.commandArguments.joined(separator: " "))")
                    LabeledContent("Started", value: report.startedAt.formatted(date: .abbreviated, time: .standard))
                    LabeledContent("Duration", value: durationDescription(report))
                }

                if !report.standardError.isEmpty {
                    LabeledContent("Standard error", value: report.standardError)
                }
            }
            .font(.caption)
            .textSelection(.enabled)
            .padding(.top, 8)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProfileField: Identifiable {
    let key: String
    let value: ProfileValue

    var id: String { key }
}

private struct ProfileRecord: Identifiable {
    let index: Int
    let value: ProfileValue

    var id: Int { index }
}

private struct ProfileArrayItem: Identifiable {
    let index: Int
    let value: ProfileValue

    var id: Int { index }
}

private func visibleObjectFields(_ object: [String: ProfileValue]) -> [ProfileField] {
    object
        .filter { $0.key != "_name" }
        .map { ProfileField(key: $0.key, value: $0.value) }
        .sorted {
            displayName(for: $0.key).localizedStandardCompare(displayName(for: $1.key)) == .orderedAscending
        }
}

private func dataTypeTitle(_ dataType: SystemProfilerDataType) -> String {
    dataType.title
}

private func durationDescription(_ report: SystemProfilerReport) -> String {
    let duration: TimeInterval = report.completedAt.timeIntervalSince(report.startedAt)
    return duration.formatted(.number.precision(.fractionLength(2))) + " seconds"
}

private func shouldShowDivider(after value: ProfileValue) -> Bool {
    switch value {
    case .object, .array: false
    case .string, .integer, .decimal, .boolean, .null: true
    }
}

private func copyToPasteboard(_ text: String) {
    let pasteboard: NSPasteboard = .general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}
