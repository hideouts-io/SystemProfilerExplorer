import SwiftUI
import UniformTypeIdentifiers

struct AppShellView: View {
    private let collector: any SystemProfilerCollecting
    private let parser: SystemProfilerParser

    @State private var selectedSubject: ProfilerSubject = .overview
    @State private var reports: [ProfilerSubject: SystemProfilerReport] = [:]
    @State private var scanState: ScanState = .idle
    @State private var scanTask: Task<Void, Never>?
    @State private var isShowingRawReportImporter: Bool = false

    init(collector: any SystemProfilerCollecting, parser: SystemProfilerParser) {
        self.collector = collector
        self.parser = parser
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(
                scanState: scanState,
                selectedSubject: selectedSubject,
                canScan: scanConfiguration(for: selectedSubject) != nil,
                canImport: selectedSubject == .reports,
                startScan: startScan,
                importReport: showRawReportImporter,
                cancelScan: cancelScan
            )
            Divider()
            SubjectTabBar(
                selectedSubject: $selectedSubject,
                scannedSubjects: Set(reports.keys)
            )
            Divider()
            SubjectWorkspace(
                subject: selectedSubject,
                report: reports[selectedSubject],
                scanState: scanState,
                startScan: startScan,
                importReport: showRawReportImporter
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $isShowingRawReportImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleRawReportSelection
        )
    }

    private func startScan() {
        let subject: ProfilerSubject = selectedSubject

        guard let configuration = scanConfiguration(for: subject) else {
            return
        }

        scanTask?.cancel()
        scanState = .running(subject: subject)

        scanTask = Task {
            do {
                let execution: SystemProfilerExecution = try await collector.collect(configuration.request)
                let report: SystemProfilerReport = try parser.parse(execution)
                try Task.checkCancellation()

                reports[subject] = report
                scanState = .completed(subject: subject, date: report.completedAt)
            } catch is CancellationError {
                scanState = .cancelled(subject: subject)
            } catch let error as SystemProfilerRequestError {
                scanState = .failed(subject: subject, message: error.localizedDescription)
            } catch let error as SystemProfilerCollectorError {
                scanState = .failed(subject: subject, message: error.localizedDescription)
            } catch let error as SystemProfilerParsingError {
                scanState = .failed(subject: subject, message: error.localizedDescription)
            } catch {
                scanState = .failed(
                    subject: subject,
                    message: "The scan failed with an unexpected error: \(String(reflecting: error))"
                )
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
        }
    }

    private func importRawReport(_ reportURL: URL) {
        let reportParser: SystemProfilerParser = parser

        scanTask?.cancel()
        selectedSubject = .reports
        scanState = .importing(subject: .reports)

        scanTask = Task {
            do {
                let report: SystemProfilerReport = try await Task.detached(priority: .userInitiated) {
                    let data: Data = try readSecurityScopedData(reportURL)
                    return try reportParser.parseImportedReport(data, importedAt: Date())
                }.value

                try Task.checkCancellation()
                reports[.reports] = report
                scanState = .completed(subject: .reports, date: report.completedAt)
            } catch is CancellationError {
                scanState = .cancelled(subject: .reports)
            } catch let error as SystemProfilerParsingError {
                scanState = .failed(subject: .reports, message: error.localizedDescription)
            } catch let error as CocoaError {
                scanState = .failed(
                    subject: .reports,
                    message: "The selected report could not be read. \(error.localizedDescription)"
                )
            } catch {
                scanState = .failed(
                    subject: .reports,
                    message: "The selected report could not be imported. \(String(reflecting: error))"
                )
            }

            scanTask = nil
        }
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
    let selectedSubject: ProfilerSubject
    let canScan: Bool
    let canImport: Bool
    let startScan: () -> Void
    let importReport: () -> Void
    let cancelScan: () -> Void

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

            Label(scanState.statusTitle, systemImage: scanState.statusSymbolName)
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

                if canScan {
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

    private var statusColor: Color {
        switch scanState {
        case .failed: .red
        case .completed: .green
        case .idle, .running, .importing, .cancelled: .secondary
        }
    }
}

private struct SubjectTabBar: View {
    @Binding var selectedSubject: ProfilerSubject
    let scannedSubjects: Set<ProfilerSubject>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ProfilerSubject.allCases) { subject in
                    SubjectTab(
                        subject: subject,
                        isSelected: selectedSubject == subject,
                        hasReport: scannedSubjects.contains(subject),
                        select: { selectedSubject = subject }
                    )
                }
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
    let hasReport: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Label(subject.title, systemImage: subject.symbolName)

                if hasReport {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Scan available")
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
}

private struct SubjectWorkspace: View {
    let subject: ProfilerSubject
    let report: SystemProfilerReport?
    let scanState: ScanState
    let startScan: () -> Void
    let importReport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SubjectHeading(subject: subject)

                if isScanning(subject, scanState: scanState) {
                    ScanningCard(subject: subject, scanState: scanState)
                } else if let failureMessage = failureMessage(subject, scanState: scanState) {
                    ScanFailureCard(message: failureMessage, retryScan: startScan)
                } else if let report {
                    ProfileReportView(report: report)
                } else {
                    ReadinessCard(
                        subject: subject,
                        canScan: scanConfiguration(for: subject) != nil,
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
                    .padding(.top, 8)
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
            return "Collection support for \(subject.title.lowercased()) will be added after the Hardware and Storage foundation is verified."
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
    let retryScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("The scan could not be completed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

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
