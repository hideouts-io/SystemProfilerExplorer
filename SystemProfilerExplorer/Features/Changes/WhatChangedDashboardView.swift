import SwiftUI
import UniformTypeIdentifiers

struct WhatChangedDashboardView: View {
    let reports: [ProfilerSubject: SystemProfilerReport]

    @State private var selectedSubject: ProfilerSubject?
    @State private var comparison: ReportComparison?
    @State private var isShowingBaselineImporter: Bool = false
    @State private var isPreparingComparison: Bool = false
    @State private var errorMessage: String?

    private var availableSubjects: [ProfilerSubject] {
        reports.keys.sorted { $0.title < $1.title }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            WorkspaceHeading(
                title: "What Changed?",
                detail: "Compare a saved private report with a current collected report, then triage the reported differences without treating them as a diagnosis.",
                symbolName: "arrow.left.arrow.right.square"
            )

            if availableSubjects.isEmpty {
                NoAvailableComparisonReportView()
            } else {
                ComparisonSetupCard(
                    availableSubjects: availableSubjects,
                    selectedSubject: $selectedSubject,
                    isPreparingComparison: isPreparingComparison,
                    importBaseline: { isShowingBaselineImporter = true }
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
        .accessibilityIdentifier("what-changed-workspace")
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

    private func selectInitialSubjectIfNeeded() {
        if let selectedSubject, reports[selectedSubject] != nil {
            return
        }

        selectedSubject = availableSubjects.first
    }

    private func importBaseline(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard urls.count == 1, let reportURL = urls.first else {
                errorMessage = ReportComparisonError.expectedSingleFile(count: urls.count).localizedDescription
                return
            }

            prepareComparison(reportURL: reportURL)
        case let .failure(error):
            let cocoaError: NSError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain, cocoaError.code == NSUserCancelledError {
                return
            }

            errorMessage = "The saved-report picker failed. \(String(reflecting: error))"
        }
    }

    private func prepareComparison(reportURL: URL) {
        guard let selectedSubject, let currentReport = reports[selectedSubject] else {
            errorMessage = "Choose a collected report before selecting a saved baseline."
            return
        }

        isPreparingComparison = true

        Task {
            do {
                let preparedComparison: ReportComparison = try await Task.detached(priority: .userInitiated) {
                    let isAccessingSecurityScopedResource: Bool = reportURL.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessingSecurityScopedResource {
                            reportURL.stopAccessingSecurityScopedResource()
                        }
                    }

                    let data: Data = try Data(contentsOf: reportURL, options: .mappedIfSafe)
                    let export: ReportExportEnvelope = try decodeReportExport(data)
                    let baseline: SystemProfilerReport = try comparisonBaselineReport(from: export)
                    return try compareReports(baseline: baseline, current: currentReport)
                }.value
                comparison = preparedComparison
            } catch is CancellationError {
                isPreparingComparison = false
                return
            } catch {
                errorMessage = "The saved report could not be compared. \(String(reflecting: error))"
            }

            isPreparingComparison = false
        }
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
    let isPreparingComparison: Bool
    let importBaseline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Compare a saved baseline", systemImage: "folder.badge.questionmark")
                .font(.headline)
            Text("Select a current subject report, then choose a full private JSON report exported by System Profiler Explorer. The two reports must cover the same data types.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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

                Button(action: importBaseline) {
                    Label(
                        isPreparingComparison ? "Comparing…" : "Choose Saved Report…",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPreparingComparison || selectedSubject == nil)
                .accessibilityIdentifier("what-changed-choose-baseline")
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct ComparisonStartGuidance: View {
    var body: some View {
        ContentCard(
            title: "Ready to compare",
            detail: "This workspace will group added, removed, and changed findings by review priority and explain each observed difference in plain language after you select a saved baseline.",
            symbolName: "rectangle.3.group"
        )
    }
}

private struct NoAvailableComparisonReportView: View {
    var body: some View {
        ContentCard(
            title: "Collect a current report first",
            detail: "Run a subject scan or import raw system_profiler JSON. Then return here to compare it with a full private saved report.",
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

    private var insights: [ReportChangeInsight] {
        reportChangeInsights(comparison)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Comparison Results")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Baseline \(comparison.baselineCompletedAt.formatted(date: .abbreviated, time: .shortened)) → Current \(comparison.currentCompletedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ChangeKindSummaryCards(summary: comparison.summary)
            ChangeImportanceNotice()

            if insights.isEmpty {
                ContentCard(
                    title: "No finding changes detected",
                    detail: "Every comparable finding in the selected report matches the current collection.",
                    symbolName: "checkmark.circle"
                )
            } else {
                ForEach(ChangeImportance.allCases) { importance in
                    let groupedInsights: [ReportChangeInsight] = insights.filter { $0.importance == importance }
                    if !groupedInsights.isEmpty {
                        ChangeImportanceGroup(importance: importance, insights: groupedInsights)
                    }
                }
            }
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
                    ChangeInsightRow(insight: insight)
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

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text(insight.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ChangeInsightValueRows(change: insight.change)

                LabeledContent("Raw source location", value: insight.change.sourcePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
