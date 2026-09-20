import SwiftUI
import UniformTypeIdentifiers

enum SystemReviewExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: "Markdown"
        case .pdf: "PDF"
        }
    }

    var contentType: UTType {
        switch self {
        case .markdown: .plainText
        case .pdf: .pdf
        }
    }
}

struct SystemReviewFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .pdf] }

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

struct SystemReviewSummaryView: View {
    let report: SystemProfilerReport
    let selectedSourcePaths: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: SystemReviewExportFormat = .markdown
    @State private var exportDocument: SystemReviewFileDocument?
    @State private var exportFilename: String = ""
    @State private var isShowingFileExporter: Bool = false
    @State private var exportErrorMessage: String?

    private var selectedFindings: [SystemReviewFinding] {
        selectedSystemReviewFindings(report: report, selectedSourcePaths: selectedSourcePaths)
    }

    var body: some View {
        VStack(spacing: 0) {
            SystemReviewHeader()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ReviewSelectionCard(findings: selectedFindings)
                    ReviewCoverageCard(coverage: collectionCoverage(for: report))
                    ReviewPrivacyWarning()

                    Picker("Export format", selection: $selectedFormat) {
                        ForEach(SystemReviewExportFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)

                    Text("The summary contains the selected findings, their explanation coverage labels, their detailed explanations, collection limits, and a privacy warning. Raw JSON remains a separate export.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("Cancel", role: .cancel, action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(action: prepareExport) {
                    Label("Choose Save Location…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFindings.isEmpty)
                .accessibilityIdentifier("export-system-review")
            }
            .padding(18)
        }
        .frame(width: 680, height: 650)
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: selectedFormat.contentType,
            defaultFilename: exportFilename,
            onCompletion: completeExport
        )
        .alert("System Review Export Failed", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "The system review could not be exported.")
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
        let markdown: String = makeSystemReviewMarkdown(report: report, selectedFindings: selectedFindings)
        let exportDate: Date = Date()

        do {
            switch selectedFormat {
            case .markdown:
                exportDocument = SystemReviewFileDocument(data: Data(markdown.utf8))
                exportFilename = systemReviewMarkdownFilename(createdAt: exportDate)
            case .pdf:
                exportDocument = SystemReviewFileDocument(data: try makeSystemReviewPDF(markdown: markdown))
                exportFilename = systemReviewPDFFilename(createdAt: exportDate)
            }
            isShowingFileExporter = true
        } catch {
            exportErrorMessage = "The system review could not be prepared. \(String(reflecting: error))"
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

private struct SystemReviewHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text("System Review Summary")
                    .font(.title2.weight(.semibold))
                Text("A focused, shareable explanation of the findings you selected with bookmarks.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }
}

private struct ReviewSelectionCard: View {
    let findings: [SystemReviewFinding]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Selected findings", systemImage: "bookmark.fill")
                .font(.headline)
            Text("Bookmarks define the summary selection. \(findings.count) \(findings.count == 1 ? "finding is" : "findings are") currently selected.")
                .foregroundStyle(.secondary)

            if findings.isEmpty {
                Text("Close this panel, expand a finding, and use its bookmark button to add it to this review.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(findings.prefix(8)) { finding in
                    Text("• \(finding.dataType.title): \(finding.presentation.title)")
                        .font(.callout)
                }

                if findings.count > 8 {
                    Text("…and \(findings.count - 8) more bookmarked findings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ReviewCoverageCard: View {
    let coverage: CollectionCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Collection limits", systemImage: "checklist")
                .font(.headline)
            Text("\(coverage.collectedCount) collected, \(coverage.emptyCount) empty, and \(coverage.skippedCount) skipped data types are included in the summary.")
                .foregroundStyle(.secondary)
            Text("A missing or skipped section is a collection limit, not a conclusion that the related hardware or service is absent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ReviewPrivacyWarning: View {
    var body: some View {
        Label(
            "Privacy warning: bookmarked findings can include device identifiers, network configuration, installed software, and other sensitive values. Review the file before sharing it.",
            systemImage: "hand.raised.fill"
        )
        .font(.callout)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
}
