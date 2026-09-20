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

    @State private var searchText: String = ""
    @State private var selectedFilter: FindingFilter = .all
    @State private var isShowingExportReview: Bool = false
    @State private var isShowingComparisonImporter: Bool = false
    @State private var isPreparingComparison: Bool = false
    @State private var reportComparison: ReportComparison?
    @State private var comparisonErrorMessage: String?
    @State private var comparisonTask: Task<Void, Never>?
    @State private var presentationIndex: ReportPresentationIndex?
    @State private var displayedQueryResult: ReportQueryResult?
    @State private var isPreparingIndex: Bool = true
    @State private var isSearching: Bool = false
    @State private var indexingErrorMessage: String?
    @State private var queryTask: Task<Void, Never>?
    @State private var isShowingSkippedCollection: Bool = false
    @State private var isShowingSnapshotTimeline: Bool = false
    @State private var isShowingSystemReview: Bool = false
    @State private var highlightedSourcePath: String?
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
        .task(id: report.completedAt) {
            await preparePresentationIndex()
        }
        .onChange(of: query) { newQuery in
            scheduleQuery(newQuery)
        }
        .onDisappear {
            queryTask?.cancel()
            comparisonTask?.cancel()
        }
        .sheet(isPresented: $isShowingExportReview) {
            ReportExportReviewView(report: report)
        }
        .sheet(item: $reportComparison) { comparison in
            ReportComparisonView(comparison: comparison)
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
                selectedSourcePaths: bookmarkedSourcePaths
            )
        }
        .fileImporter(
            isPresented: $isShowingComparisonImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importComparisonBaseline
        )
        .alert("Comparison Failed", isPresented: comparisonErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(comparisonErrorMessage ?? "The reports could not be compared.")
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

        VStack(alignment: .leading, spacing: 16) {
            CollectionCoverageCard(
                coverage: collectionCoverage(for: report),
                showSkippedCollection: { isShowingSkippedCollection = true }
            )

            ReportSummaryStrip(summary: summary)

            if summary.findingCount >= largeReportFindingThreshold {
                LargeReportNotice()
            }

            FindingControls(
                searchText: $searchText,
                selectedFilter: $selectedFilter,
                isSearching: isSearching,
                recentSearches: recentSearches,
                applyRecentSearch: applyRecentSearch
            )

            FindingBookmarkBar(
                bookmarkCount: bookmarkedSourcePaths.count,
                bookmarkedSourcePaths: bookmarkedSourcePaths,
                openSourceLocation: openSourceLocation
            )

            HStack {
                Text("Raw JSON export stays separate from local review summaries and snapshots.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isShowingComparisonImporter = true
                } label: {
                    HStack(spacing: 7) {
                        if isPreparingComparison {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.left.arrow.right")
                        }

                        Text(isPreparingComparison ? "Comparing…" : "Compare with Saved Report…")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isPreparingComparison)
                .accessibilityIdentifier("compare-report")

                Button {
                    isShowingSnapshotTimeline = true
                } label: {
                    Label("Snapshots", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("open-snapshots")

                Button {
                    isShowingSystemReview = true
                } label: {
                    Label("Review Summary", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("open-system-review")

                Button {
                    isShowingExportReview = true
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("export-report")
            }

            if matchCount == 0 {
                NoMatchingFindingsView(clearQuery: clearQuery)
            } else {
                HStack {
                    Text(resultDescription(
                        matchCount: matchCount,
                        totalCount: summary.findingCount,
                        query: displayedQuery
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(report.sections) { section in
                    ProfileSectionView(
                        section: section,
                        queryResult: queryResult,
                        automaticallyExpandResults: automaticallyExpandResults,
                        bookmarkedSourcePaths: bookmarkedSourcePaths,
                        toggleBookmark: toggleBookmark,
                        openSourceLocation: openSourceLocation,
                        highlightedSourcePath: highlightedSourcePath
                    )
                }
            }

            ScanProvenanceView(report: report)
        }
    }

    private var query: FindingQuery {
        FindingQuery(text: searchText, filter: selectedFilter)
    }

    private var comparisonErrorBinding: Binding<Bool> {
        Binding(
            get: { comparisonErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    comparisonErrorMessage = nil
                }
            }
        )
    }

    private func preparePresentationIndex() async {
        let currentReport: SystemProfilerReport = report
        let currentQuery: FindingQuery = query

        queryTask?.cancel()
        isPreparingIndex = true
        isSearching = false
        indexingErrorMessage = nil
        presentationIndex = nil
        displayedQueryResult = nil

        do {
            let indexTask: Task<(ReportPresentationIndex, ReportQueryResult), any Error> = Task.detached(
                priority: .userInitiated
            ) {
                let index: ReportPresentationIndex = try makeReportPresentationIndex(currentReport)
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
            indexingErrorMessage = "The report could not be prepared for display. \(String(reflecting: error))"
        }

        isPreparingIndex = false
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
                recordRecentSearch(newQuery)
            } catch is CancellationError {
                return
            } catch {
                indexingErrorMessage = "The report search failed. \(String(reflecting: error))"
                isSearching = false
                queryTask = nil
            }
        }
    }

    private func importComparisonBaseline(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard urls.count == 1, let reportURL = urls.first else {
                comparisonErrorMessage = ReportComparisonError
                    .expectedSingleFile(count: urls.count)
                    .localizedDescription
                return
            }

            prepareComparison(reportURL: reportURL)

        case let .failure(error):
            let cocoaError: NSError = error as NSError

            if cocoaError.domain == NSCocoaErrorDomain,
               cocoaError.code == NSUserCancelledError {
                return
            }

            comparisonErrorMessage = "The report picker failed. \(String(reflecting: error))"
        }
    }

    private func prepareComparison(reportURL: URL) {
        let currentReport: SystemProfilerReport = report

        comparisonTask?.cancel()
        isPreparingComparison = true

        comparisonTask = Task {
            do {
                let comparison: ReportComparison = try await Task.detached(priority: .userInitiated) {
                    let data: Data = try Data(contentsOf: reportURL, options: .mappedIfSafe)
                    let export: ReportExportEnvelope = try decodeReportExport(data)
                    let baselineReport: SystemProfilerReport = try comparisonBaselineReport(from: export)
                    return try compareReports(baseline: baselineReport, current: currentReport)
                }.value

                try Task.checkCancellation()
                reportComparison = comparison
            } catch is CancellationError {
                isPreparingComparison = false
                comparisonTask = nil
                return
            } catch {
                comparisonErrorMessage = "The selected report could not be compared. \(String(reflecting: error))"
            }

            isPreparingComparison = false
            comparisonTask = nil
        }
    }

    private func resultDescription(
        matchCount: Int,
        totalCount: Int,
        query: FindingQuery
    ) -> String {
        if query.isActive {
            return "Showing \(matchCount) of \(totalCount) findings"
        }

        return "\(totalCount) findings"
    }

    private func clearQuery() {
        searchText = ""
        selectedFilter = .all
        highlightedSourcePath = nil
    }

    private var bookmarkedSourcePaths: Set<String> {
        Set(storedBookmarks.split(separator: "\n").map(String.init))
    }

    private var recentSearches: [String] {
        storedRecentSearches
            .split(separator: "\n")
            .map(String.init)
    }

    private func toggleBookmark(_ sourcePath: String) {
        var paths: Set<String> = bookmarkedSourcePaths

        if paths.contains(sourcePath) {
            paths.remove(sourcePath)
        } else {
            paths.insert(sourcePath)
        }

        storedBookmarks = paths.sorted().joined(separator: "\n")
    }

    private func openSourceLocation(_ sourcePath: String) {
        selectedFilter = .all
        highlightedSourcePath = sourcePath
        searchText = sourcePath
    }

    private func applyRecentSearch(_ search: String) {
        highlightedSourcePath = nil
        searchText = search
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
        .background(Color.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("collection-coverage")
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
                tint: .orange
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

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search values and explanations", text: $searchText)
                    .textFieldStyle(.plain)
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
            .frame(width: 330)
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
    let automaticallyExpandResults: Bool
    let bookmarkedSourcePaths: Set<String>
    let toggleBookmark: (String) -> Void
    let openSourceLocation: (String) -> Void
    let highlightedSourcePath: String?

    @State private var visibleRecordLimit: Int = recordPageSize

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
                    FindingCountBadge(count: queryResult.findingCount(for: section.dataType))
                    Spacer()
                    Text(recordDescription(selection: selection))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: 0) {
                    ForEach(visibleRecords) { record in
                        ProfileValueDisclosure(
                            label: record.value.preferredName ?? "Record \(record.index + 1)",
                            value: record.value,
                            depth: 0,
                            dataType: section.dataType,
                            path: [],
                            query: queryResult.query,
                            automaticallyExpandResults: automaticallyExpandResults,
                            bookmarkedSourcePaths: bookmarkedSourcePaths,
                            toggleBookmark: toggleBookmark,
                            openSourceLocation: openSourceLocation,
                            highlightedSourcePath: highlightedSourcePath
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
    let highlightedSourcePath: String?

    @State private var isManuallyExpanded: Bool = false

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
                            highlightedSourcePath: highlightedSourcePath
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                ProfileGroupLabel(label: friendlyReportGroupName(label), count: fields.count, depth: depth)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

        case let .array(values):
            let items: [ProfileArrayItem] = filteredArrayItems(values)
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ProfileFieldRow(
                            label: item.value.preferredName ?? "Item \(item.index + 1)",
                            value: item.value,
                            depth: depth + 1,
                            dataType: dataType,
                            path: path + ["[]"],
                            query: descendantQuery,
                            automaticallyExpandResults: automaticallyExpandResults,
                            bookmarkedSourcePaths: bookmarkedSourcePaths,
                            toggleBookmark: toggleBookmark,
                            openSourceLocation: openSourceLocation,
                            highlightedSourcePath: highlightedSourcePath
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                ProfileGroupLabel(label: friendlyReportGroupName(label), count: items.count, depth: depth)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

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

    private var descendantQuery: FindingQuery {
        queryForDescendants(parentLabel: label, query: query)
    }

    private func scalarRow(scalar: ProfileScalar) -> ScalarProfileRow {
        let presentation: FieldPresentation = fieldPresentation(
            dataType: dataType,
            path: path,
            scalar: scalar
        )

        return ScalarProfileRow(
            presentation: presentation,
            depth: depth,
            isBookmarked: bookmarkedSourcePaths.contains(presentation.sourcePath),
            toggleBookmark: toggleBookmark,
            openSourceLocation: openSourceLocation,
            isHighlighted: highlightedSourcePath == presentation.sourcePath
        )
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { automaticallyExpandResults || isManuallyExpanded },
            set: { isManuallyExpanded = $0 }
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
                query: descendantQuery
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
            let itemLabel: String = value.preferredName ?? "Item \(index + 1)"

            guard profileValueMatches(
                value,
                label: itemLabel,
                dataType: dataType,
                path: path + ["[]"],
                query: descendantQuery
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
    let highlightedSourcePath: String?

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
            highlightedSourcePath: highlightedSourcePath
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

    var body: some View {
        HStack {
            Text(label)
                .font(depth == 0 ? .headline : .subheadline.weight(.medium))
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
    }
}

private struct ScalarProfileRow: View {
    let presentation: FieldPresentation
    let depth: Int
    let isBookmarked: Bool
    let toggleBookmark: (String) -> Void
    let openSourceLocation: (String) -> Void
    let isHighlighted: Bool

    var body: some View {
        DisclosureGroup {
            if presentation.isLogContent {
                DiagnosticLogView(presentation: presentation, openSourceLocation: openSourceLocation)
            } else if let explanation = presentation.explanation {
                FieldExplanationView(
                    presentation: presentation,
                    explanation: explanation,
                    openSourceLocation: openSourceLocation
                )
            } else {
                MissingExplanationView(
                    presentation: presentation,
                    openSourceLocation: openSourceLocation
                )
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .foregroundStyle(.secondary)
                    ExplanationCoverageBadge(coverage: explanationCoverage(for: presentation))
                }
                .frame(maxWidth: 280, alignment: .leading)

                Spacer(minLength: 12)

                Text(presentation.isLogContent ? "Log excerpt • expand to review" : presentation.displayedValue)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)

                Button {
                    toggleBookmark(presentation.sourcePath)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isBookmarked ? Color.accentColor : .secondary)
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark finding")
                .accessibilityIdentifier("bookmark-\(presentation.sourcePath)")
            }
        }
        .padding(.leading, CGFloat(depth * 14))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isHighlighted ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("finding-\(presentation.sourcePath)")
    }
}

private struct ExplanationCoverageBadge: View {
    let coverage: ExplanationCoverage

    var body: some View {
        Label(coverage.title, systemImage: coverage.symbolName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(coverageColor)
            .lineLimit(1)
    }

    private var coverageColor: Color {
        switch coverage {
        case .curatedField: .blue
        case .generalDataTypeContext: .blue
        case .unrecognizedField: .secondary
        }
    }
}

private struct FieldExplanationView: View {
    let presentation: FieldPresentation
    let explanation: FieldExplanation
    let openSourceLocation: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExplanationCoverageDetail(coverage: explanationCoverage(for: presentation))

            ExplanationSection(
                title: "What it means",
                symbolName: "text.book.closed",
                text: explanation.meaning
            )
            ExplanationSection(
                title: "Why it matters",
                symbolName: "scope",
                text: explanation.significance
            )
            ExplanationSection(
                title: "Interpret carefully",
                symbolName: "exclamationmark.bubble",
                text: explanation.interpretation
            )

            if let privacy = explanation.privacy {
                ExplanationSection(
                    title: "Privacy",
                    symbolName: "eye.slash",
                    text: privacy
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                LabeledContent("Source field", value: presentation.sourcePath)

                if presentation.displayedValue != presentation.rawValue {
                    LabeledContent("Raw value", value: presentation.rawValue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)

            Button {
                openSourceLocation(presentation.sourcePath)
            } label: {
                Label("Show Raw Source Location", systemImage: "arrow.turn.down.right")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("open-raw-source-\(presentation.sourcePath)")
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        .padding(.top, 8)
    }
}

private struct ExplanationCoverageDetail: View {
    let coverage: ExplanationCoverage

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: coverage.symbolName)
            VStack(alignment: .leading, spacing: 1) {
                Text(coverage.title)
                    .font(.caption.weight(.semibold))
                Text(coverage.detail)
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
        .padding(9)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExplanationSection: View {
    let title: String
    let symbolName: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct MissingExplanationView: View {
    let presentation: FieldPresentation
    let openSourceLocation: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unrecognized field", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
            Text("The value is preserved exactly as system_profiler reported it. The app does not infer a meaning for an unrecognized field.")
                .font(.callout)
                .foregroundStyle(.secondary)
            LabeledContent("Source field", value: presentation.sourcePath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Button {
                openSourceLocation(presentation.sourcePath)
            } label: {
                Label("Show Raw Source Location", systemImage: "arrow.turn.down.right")
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
        .padding(.top, 8)
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
