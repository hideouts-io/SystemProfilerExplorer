import SwiftUI
import UniformTypeIdentifiers

struct AppShellView: View {
    private let collector: any SystemProfilerCollecting
    private let parser: SystemProfilerParser

    @State private var selectedWorkspace: AppWorkspace = .subject(.overview)
    @State private var reports: [ProfilerSubject: SystemProfilerReport] = [:]
    /// Each report's search index, built once when the report arrives so switching
    /// between sidebar items doesn't rebuild it.
    @State private var presentationIndexes: [ProfilerSubject: ReportPresentationIndex] = [:]
    @State private var collectionHealth: [ProfilerSubject: CollectionAttemptHealth] = [:]
    @State private var scanState: ScanState = .idle
    @State private var scanTask: Task<Void, Never>?
    @State private var isShowingRawReportImporter: Bool = false
    @State private var isShowingGlossary: Bool = false
    @State private var activityStartedAt: Date = .now
    @AppStorage(explanationDetailModeStorageKey) private var explanationDetailMode: ExplanationDetailMode = .beginner

    init(collector: any SystemProfilerCollecting, parser: SystemProfilerParser) {
        self.collector = collector
        self.parser = parser
    }

    var body: some View {
        NavigationSplitView {
            AppSidebar(
                selection: sidebarSelection,
                findingCounts: presentationIndexes.mapValues(\.summary.findingCount),
                worthReviewingCounts: presentationIndexes.mapValues(\.worthReviewingFindingCount),
                collectionHealth: collectionHealth
            )
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 280)
        } detail: {
            VStack(spacing: 0) {
                AppHeader(
                    scanState: scanState,
                    selectedSubject: selectedSubject,
                    selectedCollectionHealth: selectedSubject.flatMap { collectionHealth[$0] } ?? .notCollected,
                    canScan: selectedSubject.flatMap(scanConfiguration(for:)) != nil,
                    canImport: selectedSubject == .reports,
                    startScan: startScan,
                    importReport: showRawReportImporter,
                    cancelScan: cancelScan,
                    showGlossary: { isShowingGlossary = true },
                    explanationDetailMode: $explanationDetailMode
                )
                Divider()
                workspaceContent
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .environment(\.explanationDetailMode, explanationDetailMode)
        .sheet(isPresented: $isShowingGlossary) {
            GlossarySheet()
        }
        .focusedSceneValue(
            \.appCommandActions,
            AppCommandActions(
                scanTitle: selectedSubject.map { "Scan \($0.title)" } ?? "Scan",
                canScan: !scanState.isRunning && selectedSubject.flatMap(scanConfiguration(for:)) != nil,
                isScanning: scanState.isRunning,
                scan: startScan,
                cancel: cancelScan,
                importReport: showRawReportImporter,
                showGlossary: { isShowingGlossary = true }
            )
        )
        .fileImporter(
            isPresented: $isShowingRawReportImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleRawReportSelection
        )
    }

    /// The sidebar's selection. A sidebar list can report no selection; that's ignored so
    /// a workspace is always shown.
    private var sidebarSelection: Binding<AppWorkspace?> {
        Binding(
            get: { selectedWorkspace },
            set: { newValue in
                if let newValue {
                    selectedWorkspace = newValue
                }
            }
        )
    }

    private func startScan() {
        // One collection at a time: a new scan must not race the previous process or
        // let the previous task overwrite this scan's state when it finishes.
        guard !scanState.isRunning,
              case let .subject(subject) = selectedWorkspace,
              let configuration = scanConfiguration(for: subject) else {
            return
        }

        let reportParser: SystemProfilerParser = parser
        // A cancelled rescan leaves the previous report, so it keeps that report's status.
        let previousHealth: CollectionAttemptHealth = collectionHealth[subject] ?? .notCollected

        activityStartedAt = .now
        scanState = .running(subject: subject)
        collectionHealth[subject] = .running

        scanTask = Task {
            do {
                let execution: SystemProfilerExecution = try await collector.collect(configuration.request)
                let prepared: PreparedReport = try await Task.detached(priority: .userInitiated) {
                    try PreparedReport(report: reportParser.parse(execution))
                }.value
                try Task.checkCancellation()

                let report: SystemProfilerReport = prepared.report
                reports[subject] = report
                presentationIndexes[subject] = prepared.index
                scanState = .completed(subject: subject, date: report.completedAt)
                collectionHealth[subject] = .completed
            } catch is CancellationError {
                scanState = .cancelled(subject: subject)
                collectionHealth[subject] = previousHealth
            } catch let error as SystemProfilerRequestError {
                scanState = .failed(subject: subject, message: error.localizedDescription)
                collectionHealth[subject] = .failed
            } catch let error as SystemProfilerCollectorError {
                scanState = .failed(subject: subject, message: error.localizedDescription)
                collectionHealth[subject] = collectionAttemptHealth(for: error)
            } catch let error as SystemProfilerParsingError {
                scanState = .failed(subject: subject, message: error.localizedDescription)
                collectionHealth[subject] = .failed
            } catch {
                scanState = .failed(
                    subject: subject,
                    message: "The scan failed with an unexpected error: \(error.localizedDescription)"
                )
                collectionHealth[subject] = .failed
            }

            scanTask = nil
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        Task {
            await collector.cancel()
        }
    }

    private func showRawReportImporter() {
        guard !scanState.isRunning else {
            return
        }

        isShowingRawReportImporter = true
    }

    private func handleRawReportSelection(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard urls.count == 1, let reportURL = urls.first else {
                scanState = .failed(
                    subject: .reports,
                    message: "Expected one system_profiler JSON file, but the picker returned \(urls.count)."
                )
                collectionHealth[.reports] = .failed
                return
            }

            importRawReport(reportURL)

        case let .failure(error):
            let cocoaError: NSError = error as NSError

            if cocoaError.domain == NSCocoaErrorDomain,
               cocoaError.code == NSUserCancelledError {
                return
            }

            scanState = .failed(
                subject: .reports,
                message: "The report picker failed. \(error.localizedDescription)"
            )
            collectionHealth[.reports] = .failed
        }
    }

    private func importRawReport(_ reportURL: URL) {
        guard !scanState.isRunning else {
            return
        }

        let reportParser: SystemProfilerParser = parser
        let previousHealth: CollectionAttemptHealth = collectionHealth[.reports] ?? .notCollected

        selectedWorkspace = .subject(.reports)
        activityStartedAt = .now
        scanState = .importing(subject: .reports)
        collectionHealth[.reports] = .running

        scanTask = Task {
            do {
                let prepared: PreparedReport = try await Task.detached(priority: .userInitiated) {
                    let data: Data = try readSecurityScopedData(reportURL)
                    return try PreparedReport(
                        report: loadViewableReport(from: data, importedAt: Date(), parser: reportParser)
                    )
                }.value

                try Task.checkCancellation()
                let report: SystemProfilerReport = prepared.report
                reports[.reports] = report
                presentationIndexes[.reports] = prepared.index
                scanState = .completed(subject: .reports, date: report.completedAt)
                collectionHealth[.reports] = .imported
            } catch is CancellationError {
                scanState = .cancelled(subject: .reports)
                collectionHealth[.reports] = previousHealth
            } catch let error as SystemProfilerParsingError {
                scanState = .failed(subject: .reports, message: error.localizedDescription)
                collectionHealth[.reports] = .failed
            } catch let error as CocoaError {
                scanState = .failed(
                    subject: .reports,
                    message: "The selected report could not be read. \(error.localizedDescription)"
                )
                collectionHealth[.reports] = .failed
            } catch {
                scanState = .failed(
                    subject: .reports,
                    message: "The selected report could not be imported. \(error.localizedDescription)"
                )
                collectionHealth[.reports] = .failed
            }

            scanTask = nil
        }
    }

    private var selectedSubject: ProfilerSubject? {
        guard case let .subject(subject) = selectedWorkspace else {
            return nil
        }

        return subject
    }

    @ViewBuilder
    private var workspaceContent: some View {
        switch selectedWorkspace {
        case let .subject(subject):
            SubjectWorkspace(
                subject: subject,
                report: reports[subject],
                presentationIndex: presentationIndexes[subject],
                scanState: scanState,
                activityStartedAt: activityStartedAt,
                collectionHealth: collectionHealth[subject] ?? .notCollected,
                startScan: startScan,
                importReport: showRawReportImporter
            )
        case .changes:
            WorkspaceScrollContainer {
                WhatChangedDashboardView(reports: reports)
            }
        }
    }
}

/// A parsed report plus its search index, built off the main actor. The index also
/// holds the counts shown in the sidebar, so the report is walked only once.
private struct PreparedReport: Sendable {
    let report: SystemProfilerReport
    let index: ReportPresentationIndex

    init(report: SystemProfilerReport) throws {
        self.report = report
        index = try makeReportPresentationIndex(report)
    }
}

private func readSecurityScopedData(_ url: URL) throws -> Data {
    let isAccessingSecurityScopedResource: Bool = url.startAccessingSecurityScopedResource()
    defer {
        if isAccessingSecurityScopedResource {
            url.stopAccessingSecurityScopedResource()
        }
    }

    return try Data(contentsOf: url, options: .mappedIfSafe)
}

private struct AppHeader: View {
    let scanState: ScanState
    let selectedSubject: ProfilerSubject?
    let selectedCollectionHealth: CollectionAttemptHealth
    let canScan: Bool
    let canImport: Bool
    let startScan: () -> Void
    let importReport: () -> Void
    let cancelScan: () -> Void
    let showGlossary: () -> Void
    @Binding var explanationDetailMode: ExplanationDetailMode

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            Button(action: showGlossary) {
                Label("Glossary", systemImage: "character.book.closed")
            }
            .buttonStyle(.borderless)
            .help("Glossary of terms used in explanations")
            .accessibilityLabel("Glossary")
            .accessibilityIdentifier("open-glossary")

            Picker("Explanation detail", selection: $explanationDetailMode) {
                ForEach(ExplanationDetailMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(explanationDetailMode.help)
            .accessibilityLabel("Explanation detail")
            .accessibilityIdentifier("explanation-detail-mode")

            Label(statusTitle, systemImage: statusSymbolName)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
                .accessibilityIdentifier("scan-status")

            if scanState.isRunning {
                Button("Cancel", role: .cancel, action: cancelScan)
                    .accessibilityIdentifier("cancel-scan")
            } else {
                if canImport {
                    Button(action: importReport) {
                        Label("Import JSON…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("import-raw-report")
                }

                if canScan, let selectedSubject {
                    Button(action: startScan) {
                        Label("Scan \(selectedSubject.title)", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("start-scan")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// The pill follows the running scan, or the last scan when it was for this tab.
    /// Otherwise it describes the selected tab rather than another tab's scan.
    private var describesScanState: Bool {
        scanState.isRunning
            || selectedSubject == nil
            || scanState.subject == nil
            || scanState.subject == selectedSubject
    }

    private var statusTitle: String {
        describesScanState ? scanState.statusTitle : selectedCollectionHealth.title
    }

    private var statusSymbolName: String {
        describesScanState ? scanState.statusSymbolName : selectedCollectionHealth.symbolName
    }

    private var statusColor: Color {
        if describesScanState {
            return switch scanState {
            case .failed: .red
            case .completed: .green
            case .idle, .running, .importing, .cancelled: .secondary
            }
        }

        return switch selectedCollectionHealth {
        case .completed, .imported: .green
        case .timedOut, .permissionLimited, .unavailable, .failed: .orange
        case .notCollected, .running: .secondary
        }
    }
}

private struct AppSidebar: View {
    @Binding var selection: AppWorkspace?
    let findingCounts: [ProfilerSubject: Int]
    let worthReviewingCounts: [ProfilerSubject: Int]
    let collectionHealth: [ProfilerSubject: CollectionAttemptHealth]

    var body: some View {
        List(selection: $selection) {
            Section("This Mac") {
                ForEach(ProfilerSubject.allCases) { subject in
                    SubjectSidebarRow(
                        subject: subject,
                        findingCount: findingCounts[subject],
                        worthReviewingCount: worthReviewingCounts[subject] ?? 0,
                        collectionHealth: collectionHealth[subject] ?? .notCollected
                    )
                    .tag(AppWorkspace.subject(subject))
                    .accessibilityIdentifier("subject-tab-\(subject.rawValue)")
                }
            }

            Section("Tools") {
                Label(AppWorkspace.changes.title, systemImage: AppWorkspace.changes.symbolName)
                    .tag(AppWorkspace.changes)
                    .accessibilityIdentifier("workspace-tab-\(AppWorkspace.changes.id)")
            }
        }
        .listStyle(.sidebar)
    }
}

private struct SubjectSidebarRow: View {
    let subject: ProfilerSubject
    let findingCount: Int?
    let worthReviewingCount: Int
    let collectionHealth: CollectionAttemptHealth

    @Environment(\.explanationDetailMode) private var detailMode

    var body: some View {
        HStack(spacing: 6) {
            Label(subject.title, systemImage: subject.symbolName)

            Spacer(minLength: 4)

            if let findingCount {
                if worthReviewingCount > 0 {
                    Label {
                        Text(worthReviewingCount.formatted())
                    } icon: {
                        Image(systemName: ValueStatus.worthReviewing.symbolName)
                            .foregroundStyle(ValueStatus.worthReviewing.tint)
                    }
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .help("\(worthReviewingCount) worth a look")
                    .accessibilityLabel("\(worthReviewingCount) worth a look")
                } else if detailMode == .beginner {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .help("Scanned; nothing needs a look")
                        .accessibilityLabel("Scanned, nothing needs a look")
                }

                // The total is a developer detail.
                if detailMode == .developer {
                    Text(findingCount.formatted())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(findingCount) findings")
                }
            } else if collectionHealth != .notCollected {
                Image(systemName: collectionHealth.symbolName)
                    .font(.caption)
                    .foregroundStyle(collectionHealthTint)
                    .help(collectionHealth.title)
                    .accessibilityLabel(collectionHealth.title)
            }
        }
    }

    private var collectionHealthTint: Color {
        switch collectionHealth {
        case .completed, .imported: .green
        case .running, .notCollected: .secondary
        case .timedOut, .permissionLimited, .unavailable, .failed: .orange
        }
    }
}

private struct SubjectWorkspace: View {
    let subject: ProfilerSubject
    let report: SystemProfilerReport?
    let presentationIndex: ReportPresentationIndex?
    let scanState: ScanState
    let activityStartedAt: Date
    let collectionHealth: CollectionAttemptHealth
    let startScan: () -> Void
    let importReport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SubjectHeading(subject: subject)

                if isScanning(subject, scanState: scanState) {
                    ScanningCard(subject: subject, scanState: scanState, startedAt: activityStartedAt)
                } else if let failureMessage = failureMessage(subject, scanState: scanState) {
                    ScanFailureCard(
                        message: failureMessage,
                        collectionHealth: collectionHealth,
                        showsPreviousReport: report != nil,
                        retryScan: startScan
                    )

                    // A failed rescan doesn't hide the report from the last one that worked.
                    if let report {
                        ProfileReportView(report: report, preparedIndex: presentationIndex)
                    }
                } else if let report {
                    ProfileReportView(report: report, preparedIndex: presentationIndex)
                } else {
                    ReadinessCard(
                        subject: subject,
                        canScan: scanConfiguration(for: subject) != nil,
                        isAnotherScanRunning: scanState.isRunning,
                        startScan: startScan,
                        importReport: importReport
                    )
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("subject-workspace-\(subject.rawValue)")
    }
}

private struct WorkspaceScrollContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: 980, alignment: .leading)
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

private struct SubjectHeading: View {
    let subject: ProfilerSubject

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: subject.symbolName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(subject.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subject.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ReadinessCard: View {
    let subject: ProfilerSubject
    let canScan: Bool
    let isAnotherScanRunning: Bool
    let startScan: () -> Void
    let importReport: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 7) {
                Text("Ready to inspect this Mac")
                    .font(.title3.weight(.semibold))
                Text(readinessMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)

                if canScan || subject == .reports {
                    HStack(spacing: 10) {
                        if subject == .reports {
                            Button(action: importReport) {
                                Label("Import JSON…", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("empty-state-import-raw-report")
                        }

                        if canScan {
                            Button(action: startScan) {
                                Label("Scan \(subject.title)", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("empty-state-start-scan")
                        }
                    }
                    .disabled(isAnotherScanRunning)
                    .padding(.top, 8)

                    if isAnotherScanRunning {
                        Text("Another scan is running. Wait for it to finish or cancel it first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Label("Read-only · everything stays on this Mac", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .padding(.horizontal, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
    }

    private var readinessMessage: String {
        if canScan {
            if subject == .reports {
                return "Run a complete read-only scan of this Mac, or import a system_profiler -json file or a report exported from this app."
            }

            return "Run a read-only scan to organize \(subject.title.lowercased()) data into structured, collapsible findings."
        } else {
            return "\(subject.title) can't be scanned yet."
        }
    }
}

private struct ScanningCard: View {
    let subject: ProfilerSubject
    let scanState: ScanState
    let startedAt: Date

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(activityTitle)
                .font(.title3.weight(.semibold))

            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text("Elapsed \(elapsedDescription(until: context.date))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("scan-elapsed")

            Text(activityDetail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 600)

            if !isImporting {
                Text("Press Command-Period to cancel.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("scan-progress")
    }

    private var isImporting: Bool {
        if case .importing = scanState {
            return true
        }

        return false
    }

    private var activityTitle: String {
        isImporting ? "Importing \(subject.title)" : "Scanning \(subject.title)"
    }

    private var activityDetail: String {
        guard !isImporting else {
            return "The selected report is being checked and organized on this Mac."
        }

        guard let request = scanConfiguration(for: subject)?.request else {
            return "system_profiler is collecting information on this Mac."
        }

        let titles: [String] = request.dataTypes.map(\.title)
        let collecting: String = titles.count <= 6
            ? titles.formatted(.list(type: .and))
            : "\(titles.count) kinds of information about this Mac"
        let limit: String = Duration.seconds(request.collectorDeadlineSeconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))

        return "Collecting \(collecting). This can take up to \(limit)."
    }

    private func elapsedDescription(until date: Date) -> String {
        Duration.seconds(max(0, Int(date.timeIntervalSince(startedAt)))).formatted(.time(pattern: .minuteSecond))
    }
}

private struct ScanFailureCard: View {
    let message: String
    let collectionHealth: CollectionAttemptHealth
    /// Whether the report from an earlier scan is shown below this card.
    let showsPreviousReport: Bool
    let retryScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("The scan could not be completed")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
                .font(.headline)

            Label {
                Text(collectionHealth.title)
            } icon: {
                Image(systemName: collectionHealth.symbolName)
                    .foregroundStyle(.orange)
            }
                .font(.subheadline.weight(.medium))

            Text(collectionHealthDetail)
                .font(.callout)
                .foregroundStyle(.secondary)

            if showsPreviousReport {
                Text("The report below is from the previous scan, which completed.")
                    .font(.callout.weight(.medium))
            }

            Text(message)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Button("Try Again", action: retryScan)
                .accessibilityIdentifier("retry-scan")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        }
    }

    private var collectionHealthDetail: String {
        switch collectionHealth {
        case .timedOut:
            "Collection reached its deadline and was terminated. No partial JSON report is presented as complete."
        case .permissionLimited:
            "The command reported a permission-related failure. This scan has no complete collection result."
        case .unavailable:
            "The requested collection did not return usable JSON. This does not prove the related hardware or service is absent."
        case .failed, .notCollected, .running, .completed, .imported:
            "This scan has no complete collection result. Review the error details before interpreting absent findings."
        }
    }
}

private func isScanning(_ subject: ProfilerSubject, scanState: ScanState) -> Bool {
    switch scanState {
    case let .running(activeSubject), let .importing(activeSubject):
        activeSubject == subject
    case .idle, .completed, .cancelled, .failed:
        false
    }
}

private func failureMessage(_ subject: ProfilerSubject, scanState: ScanState) -> String? {
    guard case let .failed(failedSubject, message) = scanState,
          failedSubject == subject else {
        return nil
    }

    return message
}
