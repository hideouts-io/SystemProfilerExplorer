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
    var glance: [String] = []
    var worthReviewingItems: [WorthReviewingItem] = []

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
                    ReviewContentsCard(
                        glance: glance,
                        worthReviewingItems: worthReviewingItems,
                        bookmarkedFindings: selectedFindings
                    )
                    ReviewCoverageCard(coverage: collectionCoverage(for: report))
                    ReviewPrivacyWarning()

                    Picker("Export format", selection: $selectedFormat) {
                        ForEach(SystemReviewExportFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)

                    Text("Markdown is easy to paste into a message or support request; PDF is ready to print. To share the full scan data, choose Share › Report File instead.")
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
                .disabled(glance.isEmpty && worthReviewingItems.isEmpty && selectedFindings.isEmpty)
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
        let markdown: String = makeSystemReviewMarkdown(
            report: report,
            selectedFindings: selectedFindings,
            glance: glance,
            worthReviewingItems: worthReviewingItems
        )
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
            exportErrorMessage = "The system review could not be prepared. \(error.localizedDescription)"
        }
    }

    private func completeExport(_ result: Result<URL, any Error>) {
        switch result {
        case .success:
            exportDocument = nil
            dismiss()
        case let .failure(error):
            exportErrorMessage = "The selected file could not be written. \(error.localizedDescription)"
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
                Text("Share a Summary")
                    .font(.title2.weight(.semibold))
                Text("A readable summary of this scan to send to someone or keep for your records.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }
}

private struct ReviewContentsCard: View {
    let glance: [String]
    let worthReviewingItems: [WorthReviewingItem]
    let bookmarkedFindings: [SystemReviewFinding]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The summary includes", systemImage: "doc.text")
                .font(.headline)

            if !glance.isEmpty {
                Label("At a glance (\(glance.count) \(glance.count == 1 ? "line" : "lines"))", systemImage: "text.alignleft")
            }

            Label {
                Text(worthReviewingItems.isEmpty
                    ? "Worth a look: nothing in this scan"
                    : "Worth a look: \(worthReviewingItems.count) \(worthReviewingItems.count == 1 ? "value" : "values")")
            } icon: {
                Image(systemName: ValueStatus.worthReviewing.symbolName)
                    .foregroundStyle(ValueStatus.worthReviewing.tint)
            }

            Label(
                bookmarkedFindings.isEmpty
                    ? "Bookmarks: none. Bookmark a finding to add its full explanation."
                    : "Bookmarks: \(bookmarkedFindings.count) \(bookmarkedFindings.count == 1 ? "finding" : "findings") with full explanations",
                systemImage: bookmarkedFindings.isEmpty ? "bookmark" : "bookmark.fill"
            )
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        Label {
            Text("Summaries can include device names, network details, serial numbers, and installed software. Review the file before sharing it.")
        } icon: {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
}
