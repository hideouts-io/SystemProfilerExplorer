import SwiftUI

struct DiagnosticLogView: View {
    let presentation: FieldPresentation
    let openSourceLocation: (String) -> Void

    @State private var summary: DiagnosticLogSummary?
    @State private var pages: [String] = []
    @State private var pageIndex: Int = 0
    @State private var analysisError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Understanding this log").font(.headline)
            Text("Retained diagnostic text—not a live monitor or a safety verdict. The report may contain only part of the original log.")
                .foregroundStyle(.secondary)

            if let summary {
                Text("Reviewed \(summary.inspectedLineCount.formatted()) nonempty lines\(summary.isPartial ? " (partial analysis: first 2 million characters only)" : " in this excerpt").")
                    .font(.caption)
                if summary.aveLineCount > 0 {
                    GroupBox("HEVC encoder activity") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Observed: \(summary.aveLineCount.formatted()) recognized AVE diagnostic lines. \(summary.singleInputSummaryCount.formatted()) summary lines report one input processed and zero dropped. Counts describe log lines, not unique images or recording sessions.")
                            Text(summary.processLabels.isEmpty
                                 ? "Process attribution: no supported process prefix was recognized."
                                 : "Reported by: \(summary.processLabels.joined(separator: ", ")). These are log labels, not independently verified executable identities.")
                            Text("Possible meaning: HEVC compresses video and HEIF/HEIC still images. Short single-input jobs can be consistent with image or thumbnail processing. This summary does not identify the content or exact trigger.")
                            Text("Not established: camera or screen recording, sending a message, a recipient, network transmission, or compromise. Other entries may contain separate evidence; this pattern summary does not assess them.")
                            Text("Reading the terms: Session means an encoder work session. Prepare, Stop, Invalidate, and Destroy describe its lifecycle; those words alone do not indicate errors.")
                            Link("Apple: HEVC is also used for still images", destination: URL(string: "https://developer.apple.com/videos/play/wwdc2019/506/")!)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                } else {
                    Text("No supported AVE pattern was recognized in the analyzed text. This does not mean the log is empty, error-free, or safe. Review its timestamps, process labels, and surrounding lines.")
                }

                DisclosureGroup("View original log text") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Private information may appear below. Pages preserve the original text and may split a line.")
                            .font(.caption).foregroundStyle(.secondary)
                        if pages.isEmpty {
                            Text("No data returned in this field.")
                        } else {
                            HStack {
                                Button("Previous") { pageIndex -= 1 }
                                    .disabled(pageIndex == 0)
                                    .accessibilityIdentifier("log-previous-page")
                                Text("Page \(pageIndex + 1) of \(pages.count)")
                                Button("Next") { pageIndex += 1 }
                                    .disabled(pageIndex + 1 >= pages.count)
                                    .accessibilityIdentifier("log-next-page")
                            }
                            Text(pages[pageIndex]).font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .accessibilityIdentifier("log-original-text")
            } else if let analysisError {
                Text("Log analysis failed: \(analysisError). The original source remains available below.")
                    .foregroundStyle(.orange)
            } else {
                ProgressView("Preparing log summary…")
            }

            Text(presentation.sourcePath).font(.caption).textSelection(.enabled)
            Button("Show Raw Source Location") { openSourceLocation(presentation.sourcePath) }
                .accessibilityIdentifier("open-raw-source-\(presentation.sourcePath)")
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        .task(id: presentation.rawValue) {
            summary = nil
            pages = []
            pageIndex = 0
            analysisError = nil
            let rawText: String = presentation.rawValue
            let work = Task.detached(priority: .userInitiated) {
                (try summarizeDiagnosticLog(rawText), try diagnosticLogPages(rawText))
            }
            do {
                let result: (DiagnosticLogSummary, [String]) = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: {
                    work.cancel()
                }
                try Task.checkCancellation()
                pages = result.1
                summary = result.0
            } catch is CancellationError {
                // Selection changed; obsolete analysis must not replace the current result.
            } catch {
                analysisError = error.localizedDescription
            }
        }
    }
}
