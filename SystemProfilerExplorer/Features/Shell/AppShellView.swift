import SwiftUI
import UniformTypeIdentifiers

struct AppShellView: View {
    private let collector: any SystemProfilerCollecting
    private let parser: SystemProfilerParser

    @State private var selectedWorkspace: AppWorkspace = .subject(.overview)
    @State private var reports: [ProfilerSubject: SystemProfilerReport] = [:]
    @State private var findingCounts: [ProfilerSubject: Int] = [:]
    @State private var worthReviewingCounts: [ProfilerSubject: Int] = [:]
    @State private var collectionHealth: [ProfilerSubject: CollectionAttemptHealth] = [:]
    @State private var scanState: ScanState = .idle
    @State private var scanTask: Task<Void, Never>?
    @State private var isShowingRawReportImporter: Bool = false
    @State private var isShowingGlossary: Bool = false
    @AppStorage(explanationDetailModeStorageKey) private var explanationDetailMode: ExplanationDetailMode = .beginner

    init(collector: any SystemProfilerCollecting, parser: SystemProfilerParser) {
        self.collector = collector
        self.parser = parser
    }

    var body: some View {
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
            WorkspaceTabBar(
                selectedWorkspace: $selectedWorkspace,
                findingCounts: findingCounts,
                worthReviewingCounts: worthReviewingCounts,
                collectionHealth: collectionHealth
            )
            Divider()
            workspaceContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private func startScan() {
        // One collection at a time: a new scan must not race the previous process or
        // let the previous task overwrite this scan's state when it finishes.
        guard !scanState.isRunning,
              case let .subject(subject) = selectedWorkspace,
              let configuration = scanConfiguration(for: subject) else {
            return
        }

        let reportParser: SystemProfilerParser = parser

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
                findingCounts[subject] = prepared.findingCount
                worthReviewingCounts[subject] = prepared.worthReviewingCount
                scanState = .completed(subject: subject, date: report.completedAt)
                collectionHealth[subject] = .completed
            } catch is CancellationError {
                scanState = .cancelled(subject: subject)
                collectionHealth[subject] = .notCollected
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
                    message: "The scan failed with an unexpected error: \(String(reflecting: error))"
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
                message: "The report picker failed. \(String(reflecting: error))"
            )
            collectionHealth[.reports] = .failed
        }
    }

    private func importRawReport(_ reportURL: URL) {
        guard !scanState.isRunning else {
            return
        }

        let reportParser: SystemProfilerParser = parser

        selectedWorkspace = .subject(.reports)
        scanState = .importing(subject: .reports)
        collectionHealth[.reports] = .running

        scanTask = Task {
            do {
                let prepared: PreparedReport = try await Task.detached(priority: .userInitiated) {
                    let data: Data = try readSecurityScopedData(reportURL)
                    return try PreparedReport(
                        report: reportParser.parseImportedReport(data, importedAt: Date())
                    )
                }.value

                try Task.checkCancellation()
                let report: SystemProfilerReport = prepared.report
                reports[.reports] = report
                findingCounts[.reports] = prepared.findingCount
                worthReviewingCounts[.reports] = prepared.worthReviewingCount
                scanState = .completed(subject: .reports, date: report.completedAt)
                collectionHealth[.reports] = .imported
            } catch is CancellationError {
                scanState = .cancelled(subject: .reports)
                collectionHealth[.reports] = .notCollected
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
                    message: "The selected report could not be imported. \(String(reflecting: error))"
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
                scanState: scanState,
                collectionHealth: collectionHealth[subject] ?? .notCollected,
                startScan: startScan,
                importReport: showRawReportImporter
            )
        case .highlights:
            WorkspaceScrollContainer {
                SystemHighlightsWorkspaceView(reports: reports)
            }
        case .changes:
            WorkspaceScrollContainer {
                WhatChangedDashboardView(reports: reports)
            }
        }
    }
}

/// A parsed report plus the counts shown in its tab, computed off the main actor
/// so the tab bar never walks the whole report while rendering.
private struct PreparedReport: Sendable {
    let report: SystemProfilerReport
    let findingCount: Int
    let worthReviewingCount: Int

    init(report: SystemProfilerReport) {
        self.report = report
        findingCount = reportSummary(report).findingCount
        worthReviewingCount = worthReviewingFindingCount(report)
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
            Image(systemName: "cpu.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text("System Profiler Explorer")
                    .font(.headline)
                Text("Understand what macOS reports about this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: showGlossary) {
                Image(systemName: "character.book.closed")
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
        .padding(.vertical, 12)
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

private struct WorkspaceTabBar: View {
    @Binding var selectedWorkspace: AppWorkspace
    let findingCounts: [ProfilerSubject: Int]
    let worthReviewingCounts: [ProfilerSubject: Int]
    let collectionHealth: [ProfilerSubject: CollectionAttemptHealth]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ProfilerSubject.allCases) { subject in
                    SubjectTab(
                        subject: subject,
                        isSelected: selectedWorkspace == .subject(subject),
                        findingCount: findingCounts[subject],
                        worthReviewingCount: worthReviewingCounts[subject] ?? 0,
                        collectionHealth: collectionHealth[subject] ?? .notCollected,
                        select: { selectedWorkspace = .subject(subject) }
                    )
                }

                Divider()
                    .frame(height: 22)

                WorkspaceTab(
                    workspace: .highlights,
                    isSelected: selectedWorkspace == .highlights,
                    select: { selectedWorkspace = .highlights }
                )
                WorkspaceTab(
                    workspace: .changes,
                    isSelected: selectedWorkspace == .changes,
                    select: { selectedWorkspace = .changes }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .background(.bar)
    }
}

private struct SubjectTab: View {
    let subject: ProfilerSubject
    let isSelected: Bool
    let findingCount: Int?
    let worthReviewingCount: Int
    let collectionHealth: CollectionAttemptHealth
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Label(subject.title, systemImage: subject.symbolName)

                if let findingCount {
                    Text(findingCount.formatted())
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .accessibilityLabel("\(findingCount) findings")

                    if worthReviewingCount > 0 {
                        Label(worthReviewingCount.formatted(), systemImage: ValueStatus.worthReviewing.symbolName)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(ValueStatus.worthReviewing.tint)
                            .help("\(worthReviewingCount) worth a look")
                            .accessibilityLabel("\(worthReviewingCount) worth a look")
                    }

                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Scan available")
                } else if collectionHealth != .notCollected {
                    Image(systemName: collectionHealth.symbolName)
                        .font(.caption2)
                        .foregroundStyle(collectionHealthTint)
                        .accessibilityLabel(collectionHealth.title)
                }
            }
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tabBackground)
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("subject-tab-\(subject.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tabBackground: some ShapeStyle {
        isSelected ? Color.accentColor.opacity(0.14) : Color.clear
    }

    private var collectionHealthTint: Color {
        switch collectionHealth {
        case .completed, .imported: .green
        case .running: .secondary
        case .timedOut, .permissionLimited, .unavailable, .failed: .orange
        case .notCollected: .secondary
        }
    }
}

private struct WorkspaceTab: View {
    let workspace: AppWorkspace
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(workspace.title, systemImage: workspace.symbolName)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace-tab-\(workspace.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SubjectWorkspace: View {
    let subject: ProfilerSubject
    let report: SystemProfilerReport?
    let scanState: ScanState
    let collectionHealth: CollectionAttemptHealth
    let startScan: () -> Void
    let importReport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SubjectHeading(subject: subject)

                if isScanning(subject, scanState: scanState) {
                    ScanningCard(subject: subject, scanState: scanState)
                } else if let failureMessage = failureMessage(subject, scanState: scanState) {
                    ScanFailureCard(
                        message: failureMessage,
                        collectionHealth: collectionHealth,
                        retryScan: startScan
                    )
                } else if let report {
                    ProfileReportView(report: report)
                } else {
                    ReadinessCard(
                        subject: subject,
                        canScan: scanConfiguration(for: subject) != nil,
                        isAnotherScanRunning: scanState.isRunning,
                        startScan: startScan,
                        importReport: importReport
                    )
                    CapabilityStrip()
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
                return "Run a complete read-only scan of this Mac, or import an existing system_profiler -json report for local analysis."
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

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(activityTitle)
                .font(.title3.weight(.semibold))
            Text(activityDetail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("scan-progress")
    }

    private var activityTitle: String {
        guard case .importing = scanState else {
            return "Scanning \(subject.title)"
        }

        return "Importing \(subject.title)"
    }

    private var activityDetail: String {
        guard case .importing = scanState else {
            return "system_profiler is collecting structured data locally. This can take a moment."
        }

        return "The selected JSON report is being validated and organized locally."
    }
}

private struct ScanFailureCard: View {
    let message: String
    let collectionHealth: CollectionAttemptHealth
    let retryScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("The scan could not be completed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Label(collectionHealth.title, systemImage: collectionHealth.symbolName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)

            Text(collectionHealthDetail)
                .font(.callout)
                .foregroundStyle(.secondary)

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
            "The command reported a permission-related failure. This tab has no complete collection result."
        case .unavailable:
            "The requested collection did not return usable JSON. This does not prove the related hardware or service is absent."
        case .failed, .notCollected, .running, .completed, .imported:
            "This tab has no complete collection result. Review the error details before interpreting absent findings."
        }
    }
}

private struct CapabilityStrip: View {
    var body: some View {
        HStack(spacing: 12) {
            CapabilityCard(
                title: "Structured",
                detail: "Preserves source data",
                symbolName: "list.bullet.indent"
            )
            CapabilityCard(
                title: "Private",
                detail: "Processed on this Mac",
                symbolName: "hand.raised"
            )
            CapabilityCard(
                title: "Explainable",
                detail: "Evidence linked to context",
                symbolName: "text.book.closed"
            )
        }
    }
}

private struct CapabilityCard: View {
    let title: String
    let detail: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
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
