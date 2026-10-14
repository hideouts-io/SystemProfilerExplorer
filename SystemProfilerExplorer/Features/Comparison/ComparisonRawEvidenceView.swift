import SwiftUI

/// Captures the exact comparison at click time, including both original reports.
struct ComparisonEvidenceRequest: Identifiable, Sendable {
    let change: ReportChange
    let side: ComparisonEvidenceSide
    let comparison: ReportComparison

    var id: String { change.id + "|" + side.rawValue }
}

struct ComparisonRawEvidenceView: View {
    let request: ComparisonEvidenceRequest

    @Environment(\.dismiss) private var dismiss
    @State private var evidence: ComparisonRawEvidence?
    @State private var pages: [String] = []
    @State private var pageIndex: Int = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(request.side.title) raw evidence")
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("comparison-raw-evidence-title")
            Text("The selected original structured value from the report used for this comparison. Private information may appear below; nothing is sent to a model or saved by this viewer.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("comparison-raw-evidence-error")
                Spacer()
            } else if let evidence {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent("Source location", value: evidence.address.sourcePath)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("comparison-raw-evidence-location")
                        LabeledContent("Report collected/imported", value: evidence.completedAt.formatted(date: .abbreviated, time: .shortened))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exact address components")
                                .font(.caption)
                                .accessibilityIdentifier("comparison-raw-evidence-components-title")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(evidence.address.dataType.rawValue)
                                    .font(.caption.monospaced())
                                    .accessibilityIdentifier("comparison-raw-evidence-data-type")
                                ForEach(Array(evidence.address.path.enumerated()), id: \.offset) { offset, component in
                                    LabeledContent("Step \(offset + 1)", value: addressComponentDescription(component))
                                        .textSelection(.enabled)
                                        .accessibilityIdentifier("comparison-raw-evidence-component-\(offset)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("comparison-raw-evidence-components")
                        Text("JSON below is reconstructed from the parsed value, not the original file's bytes or formatting. Pages preserve all characters and may split a JSON token.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Previous") { pageIndex -= 1 }
                                .disabled(pageIndex == 0)
                                .accessibilityIdentifier("comparison-raw-evidence-previous")
                            Text("Page \(pageIndex + 1) of \(pages.count)")
                                .accessibilityIdentifier("comparison-raw-evidence-page")
                            Button("Next") { pageIndex += 1 }
                                .disabled(pageIndex + 1 >= pages.count)
                                .accessibilityIdentifier("comparison-raw-evidence-next")
                        }
                        Text(pages[pageIndex])
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityIdentifier("comparison-raw-evidence-json")
                            .id(pageIndex)
                    }
                }
            } else {
                ProgressView("Resolving retained evidence…")
                    .accessibilityIdentifier("comparison-raw-evidence-loading")
                Spacer()
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("close-comparison-raw-evidence")
            }
        }
        .padding(24)
        .frame(width: 760, height: 620)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("comparison-raw-evidence")
        .task(id: request.id) {
            evidence = nil
            pages = []
            pageIndex = 0
            errorMessage = nil
            let capturedRequest: ComparisonEvidenceRequest = request
            let work = Task.detached(priority: .userInitiated) {
                let evidence: ComparisonRawEvidence = try comparisonRawEvidence(
                    for: capturedRequest.change, side: capturedRequest.side,
                    comparison: capturedRequest.comparison
                )
                return (evidence, try comparisonRawEvidencePages(evidence))
            }
            do {
                let result: (ComparisonRawEvidence, [String]) = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: {
                    work.cancel()
                }
                try Task.checkCancellation()
                pages = result.1
                evidence = result.0
            } catch is CancellationError {
                // A dismissed viewer must not apply obsolete preparation results.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private func addressComponentDescription(_ component: ProfileValuePathComponent) -> String {
    switch component {
    case let .field(key): "Field \(key.debugDescription)"
    case let .index(index): "Array index \(index) (zero-based)"
    }
}
