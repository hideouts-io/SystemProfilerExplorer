import SwiftUI
import UniformTypeIdentifiers

struct WhatChangedDashboardView: View {
    let reports: [ProfilerSubject: SystemProfilerReport]

    @State private var selectedSubject: ProfilerSubject?
    @State private var comparison: ReportComparison?
    @State private var snapshotHistory: ComparisonSnapshotHistoryState = .loading
    @State private var snapshotRefreshID: Int = 0
    @State private var isShowingBaselineImporter: Bool = false
    @State private var isPreparingComparison: Bool = false
    @State private var errorMessage: String?
    @State private var pendingComparison: PendingComparisonPair?
    @State private var comparisonRequestID: UUID = UUID()
    @State private var comparisonTask: Task<Void, Never>?

    private var availableSubjects: [ProfilerSubject] {
        reports.keys.sorted { $0.title < $1.title }
    }

    /// Full snapshots covering the same data types as the selected report, newest first.
    private var comparableSnapshots: [SnapshotSummary] {
        guard let selectedSubject, let report = reports[selectedSubject] else {
            return []
        }

        return snapshotHistory.comparableSnapshots(with: report)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            WorkspaceHeading(
                title: "What Changed?",
                detail: "Compare a report with a saved snapshot or report file, then review the differences without treating them as a diagnosis.",
                symbolName: "arrow.left.arrow.right.square"
            )

            if availableSubjects.isEmpty {
                NoAvailableComparisonReportView()
            } else {
                ComparisonSetupCard(
                    availableSubjects: availableSubjects,
                    selectedSubject: $selectedSubject,
                    snapshots: comparableSnapshots,
                    snapshotHistory: snapshotHistory,
                    isPreparingComparison: isPreparingComparison,
                    compareWithSnapshot: compare(with:),
                    importBaseline: { isShowingBaselineImporter = true },
                    refreshSnapshots: { snapshotRefreshID += 1 }
                )

                if let comparison {
                    WhatChangedResultsView(comparison: comparison)
                } else {
                    ComparisonStartGuidance()
                }
            }
        }
        .onAppear(perform: selectInitialSubjectIfNeeded)
        .onChange(of: availableSubjects) { _ in
            selectInitialSubjectIfNeeded()
        }
        .onChange(of: selectedSubject) { _ in
            invalidateComparison()
        }
        // Imports can share a file timestamp while containing different evidence.
        .onChange(of: selectedReport) { _ in
            invalidateComparison()
        }
        .onChange(of: selectedReport?.originalSource?.id) { _ in
            invalidateComparison()
        }
        .onDisappear(perform: invalidateComparison)
        .task(id: snapshotRefreshID) {
            await loadSnapshots()
        }
        .fileImporter(
            isPresented: $isShowingBaselineImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importBaseline
        )
        .alert("Comparison Failed", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The reports could not be compared.")
        }
        .alert("Same Mac not verified", isPresented: confirmationBinding, presenting: pendingComparison) { pair in
            Button("Compare with warning") { completeComparison(pair) }
                .accessibilityIdentifier("confirm-unverified-comparison")
            Button("Cancel", role: .cancel) { pendingComparison = nil }
                .accessibilityIdentifier("cancel-unverified-comparison")
        } message: { _ in
            Text("The selected reports do not contain matching machine-identifying metadata. Confirm that they describe the same Mac to continue. A persistent warning will remain visible; no additional identifiers will be collected.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("what-changed-workspace")
    }

    private var selectedReport: SystemProfilerReport? {
        selectedSubject.flatMap { reports[$0] }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { pendingComparison != nil }, set: { presented in
            if !presented { pendingComparison = nil }
        })
    }

    private func invalidateComparison() {
        comparisonRequestID = UUID()
        comparisonTask?.cancel()
        comparisonTask = nil
        pendingComparison = nil
        comparison = nil
        isPreparingComparison = false
    }

    private func isCurrentComparison(_ pair: PendingComparisonPair) -> Bool {
        comparisonRequestID == pair.id && selectedSubject == pair.subject
            && reports[pair.subject] == pair.current
            && reports[pair.subject]?.originalSource?.id == pair.current.originalSource?.id
    }

    private func selectInitialSubjectIfNeeded() {
        if let selectedSubject, reports[selectedSubject] != nil {
            return
        }

        selectedSubject = availableSubjects.first
    }

    private func loadSnapshots() async {
        guard !Task.isCancelled else {
            return
        }

        snapshotHistory = .loading

        let loaded: ComparisonSnapshotHistoryState = await Task.detached(priority: .userInitiated) {
            do {
                return ComparisonSnapshotHistoryState.load(from: try snapshotStore())
            } catch {
                return .unavailable(message: error.localizedDescription)
            }
        }.value

        guard !Task.isCancelled else {
            return
        }

        snapshotHistory = loaded
    }

    private func compare(with snapshot: SnapshotSummary) {
        let snapshotID: UUID = snapshot.id

        runComparison {
            try comparisonBaselineReport(from: snapshotStore().loadSnapshot(id: snapshotID).report)
        }
    }

    private func importBaseline(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard urls.count == 1, let reportURL = urls.first else {
                errorMessage = ReportComparisonError.expectedSingleFile(count: urls.count).localizedDescription
                return
            }

            runComparison {
                let isAccessingSecurityScopedResource: Bool = reportURL.startAccessingSecurityScopedResource()
                defer {
                    if isAccessingSecurityScopedResource {
                        reportURL.stopAccessingSecurityScopedResource()
                    }
                }

                let data: Data = try Data(contentsOf: reportURL, options: .mappedIfSafe)
                return try loadComparisonBaseline(from: data, importedAt: fileModificationDate(reportURL))
            }
        case let .failure(error):
            let cocoaError: NSError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain, cocoaError.code == NSUserCancelledError {
                return
            }

            errorMessage = "The file picker failed. \(error.localizedDescription)"
        }
    }

    private func runComparison(loadBaseline: @escaping @Sendable () throws -> SystemProfilerReport) {
        guard let selectedSubject, let currentReport = reports[selectedSubject] else {
            errorMessage = "Choose a collected report before selecting a baseline."
            return
        }

        invalidateComparison()
        let requestID: UUID = comparisonRequestID
        isPreparingComparison = true

        comparisonTask = Task {
            let work = Task.detached(priority: .userInitiated) { try loadBaseline() }
            do {
                let baseline: SystemProfilerReport = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: { work.cancel() }
                try Task.checkCancellation()
                let pair = PendingComparisonPair(id: requestID, subject: selectedSubject, baseline: baseline, current: currentReport)
                guard isCurrentComparison(pair) else { return }
                switch comparisonMachineIdentity(baseline: baseline, current: currentReport) {
                case .matched:
                    completeComparison(pair)
                case .unverified:
                    pendingComparison = pair
                    isPreparingComparison = false
                case .conflicting:
                    throw ReportComparisonError.conflictingMachineIdentifiers
                }
            } catch is CancellationError {
                // Replaced requests never publish a result or error.
            } catch {
                guard !Task.isCancelled, comparisonRequestID == requestID else { return }
                errorMessage = "The reports could not be compared. \(error.localizedDescription)"
                isPreparingComparison = false
            }
        }
    }

    private func completeComparison(_ pair: PendingComparisonPair) {
        guard isCurrentComparison(pair) else { return }
        pendingComparison = nil
        isPreparingComparison = true
        comparisonTask = Task {
            let work = Task.detached(priority: .userInitiated) {
                try compareReports(baseline: pair.baseline, current: pair.current)
            }
            do {
                let prepared: ReportComparison = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: { work.cancel() }
                try Task.checkCancellation()
                guard isCurrentComparison(pair) else { return }
                comparison = prepared
                isPreparingComparison = false
            } catch is CancellationError {
                // Cancelled comparisons cannot replace the active report pair.
            } catch {
                guard !Task.isCancelled, isCurrentComparison(pair) else { return }
                errorMessage = "The reports could not be compared. \(error.localizedDescription)"
                isPreparingComparison = false
            }
        }
    }
}

private struct PendingComparisonPair: Identifiable, Sendable {
    let id: UUID
    let subject: ProfilerSubject
    let baseline: SystemProfilerReport
    let current: SystemProfilerReport
}

/// Keeps unavailable or partly unreadable history distinct from a genuinely empty
/// history. Only readable, full snapshots of the current report can be baselines.
enum ComparisonSnapshotHistoryState: Sendable, Equatable {
    case loading
    case loaded(SnapshotHistory)
    case unavailable(message: String)

    static func load(from store: SnapshotStore) -> ComparisonSnapshotHistoryState {
        do {
            return .loaded(try store.loadSnapshotHistory())
        } catch {
            return .unavailable(message: error.localizedDescription)
        }
    }

    func comparableSnapshots(with report: SystemProfilerReport) -> [SnapshotSummary] {
        guard case let .loaded(history) = self else {
            return []
        }

        return history.snapshots.filter { snapshotCanBeCompared($0, with: report) }
    }

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

struct WorkspaceHeading: View {
    let title: String
    let detail: String
    let symbolName: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ComparisonSetupCard: View {
    let availableSubjects: [ProfilerSubject]
    @Binding var selectedSubject: ProfilerSubject?
    let snapshots: [SnapshotSummary]
    let snapshotHistory: ComparisonSnapshotHistoryState
    let isPreparingComparison: Bool
    let compareWithSnapshot: (SnapshotSummary) -> Void
    let importBaseline: () -> Void
    let refreshSnapshots: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Choose what to compare", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                Spacer()
                Button(action: refreshSnapshots) {
                    Label("Refresh Snapshots", systemImage: "arrow.clockwise")
                }
                .disabled(snapshotHistory.isLoading || isPreparingComparison)
                .accessibilityIdentifier("what-changed-refresh-snapshots")
            }

            ComparisonSnapshotHistoryNotice(history: snapshotHistory)

            if case .loaded = snapshotHistory, snapshots.isEmpty {
                Text("No readable, compatible full snapshots are available for this report.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("what-changed-no-snapshot-baselines")
            }

            HStack(spacing: 12) {
                Picker("Current report", selection: $selectedSubject) {
                    ForEach(availableSubjects) { subject in
                        Label(subject.title, systemImage: subject.symbolName)
                            .tag(Optional(subject))
                    }
                }
                .frame(maxWidth: 260)
                .accessibilityIdentifier("what-changed-current-report")

                Spacer()

                if let latest = snapshots.first {
                    Button {
                        compareWithSnapshot(latest)
                    } label: {
                        Label(
                            isPreparingComparison ? "Comparing…" : "Compare with “\(latest.name)”",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPreparingComparison)
                    .accessibilityIdentifier("what-changed-compare-latest-snapshot")
                }

                Group {
                    if snapshots.isEmpty {
                        Button(action: importBaseline) {
                            Label("Choose File…", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("what-changed-choose-file")
                    } else {
                        Menu {
                            Section("Snapshots") {
                                ForEach(snapshots) { snapshot in
                                    Button("\(snapshot.name) — \(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))") {
                                        compareWithSnapshot(snapshot)
                                    }
                                }
                            }

                            Divider()

                            Button("Choose File…", action: importBaseline)
                                .accessibilityIdentifier("what-changed-choose-file")
                        } label: {
                            Label("Other Baseline", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("what-changed-choose-baseline")
                    }
                }
                .fixedSize()
                .disabled(isPreparingComparison || selectedSubject == nil)
            }

            Text("Only readable, full snapshots covering the same data types are listed. Redacted snapshots cannot be compared. Save a baseline from a report's Snapshots button, or choose a full export or system_profiler -json file.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct ComparisonSnapshotHistoryNotice: View {
    let history: ComparisonSnapshotHistoryState

    var body: some View {
        switch history {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading local snapshots…")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("what-changed-snapshots-loading")
        case let .unavailable(message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Snapshot history could not be loaded", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(message)
                    .textSelection(.enabled)
                Text("Refresh Snapshots to try again. You can still choose a baseline file.")
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("what-changed-snapshots-unavailable")
        case let .loaded(history):
            if !history.unreadableFileNames.isEmpty {
                UnreadableSnapshotsNotice(fileNames: history.unreadableFileNames)
            }
        }
    }
}

private struct ComparisonStartGuidance: View {
    var body: some View {
        ContentCard(
            title: "Ready to compare",
            detail: "Changes are grouped as added, removed, and changed, sorted by review priority, and explained in plain language.",
            symbolName: "rectangle.3.group"
        )
    }
}

private struct NoAvailableComparisonReportView: View {
    var body: some View {
        ContentCard(
            title: "Collect a current report first",
            detail: "Scan a subject or import a report. Then return here to compare it with a saved snapshot or report file.",
            symbolName: "doc.badge.plus"
        )
    }
}

struct ContentCard: View {
    let title: String
    let detail: String
    let symbolName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WhatChangedResultsView: View {
    let comparison: ReportComparison

    @State private var isShowingDetails: Bool = false
    @State private var selectedChange: ReportChange?

    private var insights: [ReportChangeInsight] {
        reportChangeInsights(comparison)
    }

    var body: some View {
        HSplitView {
            changeList.frame(minWidth: 360)
            if let selectedChange {
                ComparisonEvidenceInspector(change: selectedChange, comparison: comparison, close: { self.selectedChange = nil })
                    .frame(minWidth: 550, idealWidth: 650)
            }
        }
        .frame(minHeight: 550)
    }

    private var changeList: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Comparison Results")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Baseline \(comparison.baselineCompletedAt.formatted(date: .abbreviated, time: .shortened)) → Current \(comparison.currentCompletedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Review Details") {
                    isShowingDetails = true
                }
                .accessibilityIdentifier("what-changed-review-details")
            }

            ChangeKindSummaryCards(summary: comparison.summary)
            ComparisonIdentityNotice(identity: comparison.machineIdentity)
            UnresolvedComparisonMatchesView(comparison: comparison)
            ChangeImportanceNotice()

            if insights.isEmpty {
                ContentCard(
                    title: comparison.unresolvedMatches.isEmpty ? "No finding changes detected" : "No confirmed finding changes",
                    detail: comparison.unresolvedMatches.isEmpty ? "Every comparable finding in the selected report matches the current collection." : "Unresolved record matches still require review. No pairing was guessed.",
                    symbolName: "checkmark.circle"
                )
            } else {
                ForEach(ChangeImportance.allCases) { importance in
                    let groupedInsights: [ReportChangeInsight] = insights.filter { $0.importance == importance }
                    if !groupedInsights.isEmpty {
                        ChangeImportanceGroup(importance: importance, insights: groupedInsights, comparison: comparison, inspect: { selectedChange = $0 })
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDetails) {
            ReportComparisonView(comparison: comparison)
        }
    }
}

private struct ChangeKindSummaryCards: View {
    let summary: ReportComparisonSummary

    var body: some View {
        HStack(spacing: 10) {
            ChangeKindSummaryCard(title: "Added", value: summary.addedCount, symbolName: "plus.circle.fill", tint: .green)
            ChangeKindSummaryCard(title: "Removed", value: summary.removedCount, symbolName: "minus.circle.fill", tint: .red)
            ChangeKindSummaryCard(title: "Changed", value: summary.changedCount, symbolName: "pencil.circle.fill", tint: .orange)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("what-changed-summary")
    }
}

private struct ChangeKindSummaryCard: View {
    let title: String
    let value: Int
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
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
    }
}

private struct ChangeImportanceNotice: View {
    var body: some View {
        Label(
            "Importance groups rank where to look first for triage. They do not rate danger, determine intent, or establish compromise.",
            systemImage: "info.circle"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(13)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct ChangeImportanceGroup: View {
    let importance: ChangeImportance
    let insights: [ReportChangeInsight]
    let comparison: ReportComparison
    let inspect: (ReportChange) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: importance.symbolName)
                    .foregroundStyle(importanceTint)
                Text(importance.title)
                    .font(.headline)
                Text("\(insights.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Text(importance.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 0) {
                ForEach(insights) { insight in
                    ChangeInsightRow(insight: insight, comparison: comparison, inspect: { inspect(insight.change) })
                    if insight.id != insights.last?.id {
                        Divider()
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            }
        }
    }

    private var importanceTint: Color {
        switch importance {
        case .reviewFirst: .orange
        case .review: .blue
        case .informational: .secondary
        }
    }
}

private struct ChangeInsightRow: View {
    let insight: ReportChangeInsight
    let comparison: ReportComparison
    let inspect: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text(insight.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ChangeInsightValueRows(change: insight.change)

                ComparisonSourceLocations(change: insight.change, inspect: inspect)
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 11) {
                Label(changeDashboardKindTitle(insight.change.kind), systemImage: changeDashboardKindSymbol(insight.change.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(changeDashboardKindColor(insight.change.kind))
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                    Text("\(insight.change.dataType.title) · \(insight.change.recordLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityIdentifier("what-changed-insight-\(insight.id)")
        .onChange(of: isExpanded) { expanded in
            if expanded { inspect() }
        }
    }
}

private struct ChangeInsightValueRows: View {
    let change: ReportChange

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let previousValue = change.previousValue {
                LabeledContent(
                    "Baseline value",
                    value: changeDashboardValueDescription(
                        previousValue,
                        dataType: change.dataType,
                        catalogPath: change.catalogPath
                    )
                )
            }
            if let currentValue = change.currentValue {
                LabeledContent(
                    "Current value",
                    value: changeDashboardValueDescription(
                        currentValue,
                        dataType: change.dataType,
                        catalogPath: change.catalogPath
                    )
                )
            }
        }
        .font(.caption)
        .textSelection(.enabled)
    }
}

private func changeDashboardKindTitle(_ kind: ReportChangeKind) -> String {
    switch kind {
    case .added: "Added"
    case .removed: "Removed"
    case .changed: "Changed"
    }
}

private func changeDashboardKindSymbol(_ kind: ReportChangeKind) -> String {
    switch kind {
    case .added: "plus"
    case .removed: "minus"
    case .changed: "pencil"
    }
}

private func changeDashboardKindColor(_ kind: ReportChangeKind) -> Color {
    switch kind {
    case .added: .green
    case .removed: .red
    case .changed: .orange
    }
}

private func changeDashboardValueDescription(
    _ value: ProfileScalar,
    dataType: SystemProfilerDataType,
    catalogPath: [String]
) -> String {
    fieldPresentation(dataType: dataType, path: catalogPath, scalar: value).displayedValue
}
