import SwiftUI

/// A comparison's immutable reports own all evidence shown by this inspector.
struct ComparisonEvidenceInspector: View {
    let change: ReportChange
    let comparison: ReportComparison
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Evidence inspector").font(.headline)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }
                    .accessibilityLabel("Close evidence inspector")
                    .accessibilityIdentifier("close-comparison-evidence-inspector")
            }
            Text(change.recordLabel).font(.subheadline)
            ComparisonIdentityNotice(identity: comparison.machineIdentity)
            Text("Private evidence · local inspection only. Original input bytes are session-only; reconstructed JSON is labeled separately.")
                .font(.caption).foregroundStyle(.secondary)
            if comparison.changes.contains(change) {
                HStack(alignment: .top, spacing: 12) {
                    ComparisonEvidenceColumn(side: .baseline, report: comparison.baselineReport, address: change.baselineAddress, tint: .red)
                    Divider()
                    ComparisonEvidenceColumn(side: .current, report: comparison.currentReport, address: change.currentAddress, tint: .green)
                }
            } else {
                Label(ComparisonRawEvidenceError.valueMismatch.localizedDescription, systemImage: "exclamationmark.triangle")
            }
        }
        .padding(16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("comparison-evidence-inspector")
    }
}

private struct ComparisonEvidenceColumn: View {
    let side: ComparisonEvidenceSide
    let report: SystemProfilerReport
    let address: ProfileValueAddress?
    let tint: Color
    @State private var isShowingContext: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(side.title).font(.headline).foregroundStyle(tint)
                Text("Report timestamp (may be import time)").font(.caption).foregroundStyle(.secondary)
                Text(report.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                if let address {
                    AddressedEvidenceContent(address: address, report: report, side: side)
                        .padding(8)
                        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    Button(isShowingContext ? "Hide surrounding record" : "Show surrounding record") {
                        isShowingContext.toggle()
                    }
                    .accessibilityValue(isShowingContext ? "Expanded" : "Collapsed")
                    .accessibilityIdentifier("comparison-context-\(side.rawValue)")
                    if isShowingContext, let first = address.path.first {
                        AddressedEvidenceContent(address: ProfileValueAddress(dataType: address.dataType, path: [first]), report: report, side: side)
                    }
                } else {
                    Text("Field not present in this report. This is not a reported null value.")
                        .font(.callout)
                        .accessibilityIdentifier("comparison-evidence-absent-\(side.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("comparison-evidence-\(side.rawValue)")
    }
}

/// Formatting-only reimports must invalidate preparation despite semantic equality.
private struct EvidenceLookupKey: Equatable {
    let address: ProfileValueAddress
    let report: SystemProfilerReport
    let sourceID: UUID?
}

private struct AddressedEvidenceContent: View {
    let address: ProfileValueAddress
    let report: SystemProfilerReport
    let side: ComparisonEvidenceSide
    @State private var evidence: AddressedReportEvidence?
    @State private var errorMessage: String?
    @State private var evidenceID: UUID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(address.sourcePath).font(.caption.monospaced())
                .accessibilityIdentifier("comparison-evidence-path-\(side.rawValue)")
            DisclosureGroup("Exact address components") {
                ForEach(Array(address.path.enumerated()), id: \.offset) { offset, component in
                    Text("\(offset + 1). \(evidenceAddressComponent(component))").font(.caption.monospaced())
                }
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    .accessibilityIdentifier("comparison-evidence-error-\(side.rawValue)")
            } else if let evidence {
                Text("Type: \(evidenceValueType(evidence.value))").font(.caption)
                Text("Structured evidence · reconstructed JSON").font(.subheadline.weight(.semibold))
                EvidenceTextPages(pages: evidence.structuredPages, identifier: "comparison-structured-\(side.rawValue)-\(address.identity)")
                    .id(evidenceID)
                Divider()
                Text("Original source · exact input excerpt").font(.subheadline.weight(.semibold))
                switch evidence.original {
                case .unavailable:
                    Text("Original source unavailable")
                        .accessibilityIdentifier("comparison-original-unavailable-\(side.rawValue)")
                    Text("No input bytes were retained for this report. Structured evidence above is not a substitute for original bytes.")
                        .font(.caption).foregroundStyle(.secondary)
                case let .failed(message):
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        .accessibilityIdentifier("comparison-original-error-\(side.rawValue)")
                case let .available(pages, byteRange):
                    Text("Input bytes \(byteRange.lowerBound)..<\(byteRange.upperBound) (zero-based)").font(.caption.monospaced())
                    EvidenceTextPages(pages: pages, identifier: "comparison-original-\(side.rawValue)-\(address.identity)")
                        .id(evidenceID)
                }
            } else {
                ProgressView("Resolving retained evidence…")
            }
        }
        .task(id: EvidenceLookupKey(address: address, report: report, sourceID: report.originalSource?.id)) {
            evidence = nil
            errorMessage = nil
            let capturedAddress: ProfileValueAddress = address
            let capturedReport: SystemProfilerReport = report
            let work = Task.detached(priority: .userInitiated) {
                try addressedReportEvidence(at: capturedAddress, in: capturedReport)
            }
            do {
                let loaded: AddressedReportEvidence = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: { work.cancel() }
                try Task.checkCancellation()
                evidenceID = UUID()
                evidence = loaded
            } catch is CancellationError {
                // Replaced selections cannot publish obsolete evidence.
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct EvidenceTextPages: View {
    let pages: [String]
    let identifier: String
    @State private var pageIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Previous") { pageIndex -= 1 }.disabled(pageIndex == 0)
                    .accessibilityIdentifier(identifier + "-previous")
                Text("\(pageIndex + 1)/\(pages.count)").font(.caption.monospacedDigit())
                    .accessibilityIdentifier(identifier + "-page")
                Button("Next") { pageIndex += 1 }.disabled(pageIndex + 1 >= pages.count)
                    .accessibilityIdentifier(identifier + "-next")
            }
            Text(pages[pageIndex]).font(.callout.monospaced()).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(identifier + "-text")
            if pages.count > 1 {
                Text("Pages preserve characters and may split a JSON token.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ComparisonIdentityNotice: View {
    let identity: ComparisonMachineIdentity

    var body: some View {
        if identity == .unverified {
            Label("Same Mac not verified", systemImage: "exclamationmark.triangle")
                .font(.callout.weight(.semibold)).foregroundStyle(.orange)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("comparison-machine-unverified")
        } else if identity == .matched {
            Text("Machine identifiers match. This does not authenticate the reports.")
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("comparison-machine-matched")
        }
    }
}

/// Unresolved candidates remain visible independently of confirmed-change filters.
struct UnresolvedComparisonMatchesView: View {
    let comparison: ReportComparison

    var body: some View {
        if !comparison.unresolvedMatches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("\(comparison.unresolvedMatches.count) unresolved record groups", systemImage: "questionmark.diamond")
                    .font(.headline).accessibilityIdentifier("comparison-unresolved-count")
                Text("These records cannot be matched uniquely. Candidates are not counted as confirmed changes; no pairing was guessed.")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(comparison.unresolvedMatches) { match in
                    UnresolvedMatchView(match: match, comparison: comparison)
                }
            }
        }
    }
}

private struct UnresolvedMatchView: View {
    let match: UnresolvedRecordMatch
    let comparison: ReportComparison
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isExpanded.toggle()
            } label: {
                Label("\(match.dataType.title) · \(match.recordName ?? "Unnamed records")", systemImage: isExpanded ? "chevron.down" : "chevron.right")
            }
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("comparison-unresolved-\(match.id)")
            if isExpanded {
                HStack(alignment: .top, spacing: 12) {
                    UnresolvedCandidatesColumn(candidates: match.baselineCandidates, report: comparison.baselineReport, side: .baseline)
                    UnresolvedCandidatesColumn(candidates: match.currentCandidates, report: comparison.currentReport, side: .current)
                }
            }
        }
    }
}

private struct UnresolvedCandidatesColumn: View {
    let candidates: [ProfileValueAddress]
    let report: SystemProfilerReport
    let side: ComparisonEvidenceSide
    @State private var visibleLimit: Int = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(side.title): \(candidates.count) candidates").font(.subheadline)
            ForEach(Array(candidates.prefix(visibleLimit)), id: \.identity) { address in
                UnresolvedCandidateView(address: address, report: report, side: side)
            }
            if candidates.count > visibleLimit {
                Button("Show more candidates") { visibleLimit += 50 }
                    .accessibilityIdentifier("comparison-more-candidates-\(side.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UnresolvedCandidateView: View {
    let address: ProfileValueAddress
    let report: SystemProfilerReport
    let side: ComparisonEvidenceSide
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(address.sourcePath) { isExpanded.toggle() }
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("comparison-candidate-\(side.rawValue)-\(address.identity)")
            if isExpanded { AddressedEvidenceContent(address: address, report: report, side: side) }
        }
        .font(.caption)
    }
}

private func evidenceAddressComponent(_ component: ProfileValuePathComponent) -> String {
    switch component {
    case let .field(key): "Field \(key.debugDescription)"
    case let .index(index): "Array index \(index) (zero-based)"
    }
}

private func evidenceValueType(_ value: ProfileValue) -> String {
    switch value {
    case .object: "Object"
    case .array: "Array"
    case .string: "String"
    case .integer: "Integer"
    case .decimal: "Decimal"
    case .boolean: "Boolean"
    case .null: "Reported null"
    }
}
