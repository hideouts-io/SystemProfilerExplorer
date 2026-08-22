import SwiftUI
import UniformTypeIdentifiers

struct ReportExportFileDocument: FileDocument {
    static let contentType: UTType = .json
    static var readableContentTypes: [UTType] { [contentType] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        throw ReportExportError.importNotSupported
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ReportExportReviewView: View {
    let report: SystemProfilerReport
    let summary: ReportSummary
    let scalarCount: Int

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrivacy: ReportExportPrivacy = .redacted
    @State private var exportDocument: ReportExportFileDocument?
    @State private var exportFilename: String = ""
    @State private var isShowingFileExporter: Bool = false
    @State private var isPreparingExport: Bool = false
    @State private var exportErrorMessage: String?
    @State private var preparationTask: Task<Void, Never>?

    init(report: SystemProfilerReport) {
        self.report = report
        summary = reportSummary(report)
        scalarCount = reportScalarCount(report)
    }

    var body: some View {
        VStack(spacing: 0) {
            ExportReviewHeader()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ExportScopeCard(summary: summary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose a privacy level")
                            .font(.headline)
                        Text("The complete scan is exported. Search text and finding filters do not limit the saved report.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        ExportPrivacyChoice(
                            privacy: .redacted,
                            selectedPrivacy: $selectedPrivacy,
                            title: "Redacted report",
                            detail: "Replaces every reported value and record name, including unrecognized fields. Exact scan times and standard error text are omitted.",
                            badge: "Recommended for sharing",
                            symbolName: "eye.slash.fill"
                        )
                        .accessibilityIdentifier("export-privacy-redacted")

                        ExportPrivacyChoice(
                            privacy: .full,
                            selectedPrivacy: $selectedPrivacy,
                            title: "Full private report",
                            detail: "Preserves exact values, record names, timestamps, and collection diagnostics for private analysis and future comparison.",
                            badge: "Keep private",
                            symbolName: "lock.doc.fill"
                        )
                        .accessibilityIdentifier("export-privacy-full")
                    }

                    ExportPrivacyNotice(
                        selectedPrivacy: selectedPrivacy,
                        scalarCount: scalarCount,
                        privacyFindingCount: summary.privacyFindingCount
                    )

                    Label(
                        "The saved file uses a versioned JSON format. Explanations are derived from the app's offline catalog and remain separate from the observed profiler evidence.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("Cancel", role: .cancel) {
                    preparationTask?.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: prepareExport) {
                    HStack(spacing: 8) {
                        if isPreparingExport {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "folder.badge.plus")
                        }

                        Text(isPreparingExport ? "Preparing Report…" : "Choose Save Location…")
                    }
                    .frame(minWidth: 190)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(isPreparingExport)
                .opacity(isPreparingExport ? 0.78 : 1)
                .accessibilityIdentifier("confirm-report-export")
            }
            .padding(18)
        }
        .frame(width: 660, height: 680)
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: ReportExportFileDocument.contentType,
            defaultFilename: exportFilename,
            onCompletion: completeExport
        )
        .alert("Export Failed", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "The report could not be exported.")
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }

    private func prepareExport() {
        let privacy: ReportExportPrivacy = selectedPrivacy
        let reportToExport: SystemProfilerReport = report

        preparationTask?.cancel()
        isPreparingExport = true

        preparationTask = Task {
            do {
                let preparedExport: PreparedReportExport = try await Task.detached(priority: .userInitiated) {
                    switch privacy {
                    case .redacted:
                        PreparedReportExport(
                            data: try encodeReportExport(makeRedactedReportExport(reportToExport)),
                            filename: redactedReportExportFilename(completedAt: reportToExport.completedAt)
                        )
                    case .full:
                        PreparedReportExport(
                            data: try encodeReportExport(makeFullReportExport(reportToExport)),
                            filename: fullReportExportFilename(completedAt: reportToExport.completedAt)
                        )
                    }
                }.value

                try Task.checkCancellation()
                exportDocument = ReportExportFileDocument(data: preparedExport.data)
                exportFilename = preparedExport.filename
                isShowingFileExporter = true
            } catch is CancellationError {
                isPreparingExport = false
                preparationTask = nil
                return
            } catch {
                exportErrorMessage = "The report could not be encoded for export. \(String(reflecting: error))"
            }

            isPreparingExport = false
            preparationTask = nil
        }
    }

    private func completeExport(_ result: Result<URL, any Error>) {
        switch result {
        case .success:
            exportDocument = nil
            dismiss()
        case let .failure(error):
            exportErrorMessage = "The selected file could not be written. \(String(reflecting: error))"
        }
    }
}

private struct PreparedReportExport: Sendable {
    let data: Data
    let filename: String
}

private struct ExportReviewHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.arrow.up")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text("Export Report")
                    .font(.title2.weight(.semibold))
                Text("Review what will leave the in-memory workspace before choosing a file location.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }
}

private struct ExportScopeCard: View {
    let summary: ReportSummary

    var body: some View {
        HStack(spacing: 0) {
            ExportMetric(title: "Records", value: summary.recordCount)
            Divider().frame(height: 34)
            ExportMetric(title: "Findings", value: summary.findingCount)
            Divider().frame(height: 34)
            ExportMetric(title: "Privacy flagged", value: summary.privacyFindingCount)
        }
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        }
        .accessibilityIdentifier("export-scope-summary")
    }
}

private struct ExportMetric: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExportPrivacyChoice: View {
    let privacy: ReportExportPrivacy
    @Binding var selectedPrivacy: ReportExportPrivacy
    let title: String
    let detail: String
    let badge: String
    let symbolName: String

    var body: some View {
        Button {
            selectedPrivacy = privacy
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: selectedPrivacy == privacy ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedPrivacy == privacy ? Color.accentColor : Color.secondary)

                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(privacy == .redacted ? Color.green : Color.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .background(choiceBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(choiceBorder, lineWidth: selectedPrivacy == privacy ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedPrivacy == privacy ? .isSelected : [])
    }

    private var choiceBackground: Color {
        selectedPrivacy == privacy
            ? Color.accentColor.opacity(0.08)
            : Color(nsColor: .controlBackgroundColor)
    }

    private var choiceBorder: Color {
        selectedPrivacy == privacy
            ? Color.accentColor.opacity(0.7)
            : Color(nsColor: .separatorColor).opacity(0.5)
    }
}

private struct ExportPrivacyNotice: View {
    let selectedPrivacy: ReportExportPrivacy
    let scalarCount: Int
    let privacyFindingCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: noticeSymbolName)
                .font(.title3)
                .foregroundStyle(noticeColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(noticeTitle)
                    .font(.subheadline.weight(.semibold))
                Text(noticeDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(noticeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(noticeColor.opacity(0.28), lineWidth: 1)
        }
        .accessibilityIdentifier("export-privacy-notice")
    }

    private var noticeTitle: String {
        switch selectedPrivacy {
        case .redacted: "All \(scalarCount.formatted()) reported values will be redacted"
        case .full: "This file will contain private system data"
        }
    }

    private var noticeDetail: String {
        switch selectedPrivacy {
        case .redacted:
            "Redaction covers every scalar value, not only the \(privacyFindingCount.formatted()) findings currently recognized as privacy-sensitive."
        case .full:
            "The catalog flags \(privacyFindingCount.formatted()) privacy-sensitive findings, but unrecognized fields may also identify this Mac, its users, software, or networks."
        }
    }

    private var noticeSymbolName: String {
        switch selectedPrivacy {
        case .redacted: "checkmark.shield.fill"
        case .full: "exclamationmark.triangle.fill"
        }
    }

    private var noticeColor: Color {
        switch selectedPrivacy {
        case .redacted: .green
        case .full: .orange
        }
    }
}
