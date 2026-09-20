import SwiftUI

struct SystemHighlightsWorkspaceView: View {
    let reports: [ProfilerSubject: SystemProfilerReport]

    @State private var selectedSubject: ProfilerSubject?

    private var availableSubjects: [ProfilerSubject] {
        reports.keys.sorted { $0.title < $1.title }
    }

    private var selectedReport: SystemProfilerReport? {
        guard let selectedSubject else {
            return nil
        }

        return reports[selectedSubject]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            WorkspaceHeading(
                title: "Highlights",
                detail: "Cross-section relationships from one collected report, with the raw source fields and interpretation limits kept visible.",
                symbolName: "point.3.connected.trianglepath.dotted"
            )

            if availableSubjects.isEmpty {
                ContentCard(
                    title: "Collect a report first",
                    detail: "Highlights are available after a subject scan or raw JSON import. They never combine reports collected at different times.",
                    symbolName: "doc.badge.plus"
                )
            } else if let selectedReport {
                HighlightSourcePicker(
                    availableSubjects: availableSubjects,
                    selectedSubject: $selectedSubject
                )
                SystemHighlightsView(report: selectedReport)
            }
        }
        .onAppear(perform: selectInitialSubjectIfNeeded)
        .onChange(of: availableSubjects) { _ in
            selectInitialSubjectIfNeeded()
        }
        .accessibilityIdentifier("highlights-workspace")
    }

    private func selectInitialSubjectIfNeeded() {
        if let selectedSubject, reports[selectedSubject] != nil {
            return
        }

        selectedSubject = reports[.reports] == nil ? availableSubjects.first : .reports
    }
}

private struct HighlightSourcePicker: View {
    let availableSubjects: [ProfilerSubject]
    @Binding var selectedSubject: ProfilerSubject?

    var body: some View {
        HStack {
            Picker("Highlight source", selection: $selectedSubject) {
                ForEach(availableSubjects) { subject in
                    Label(subject.title, systemImage: subject.symbolName)
                        .tag(Optional(subject))
                }
            }
            .frame(maxWidth: 270)

            Text("Relationships use one collection only; scans are never merged across times.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(.quaternary.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SystemHighlightsView: View {
    let report: SystemProfilerReport

    private var highlights: [SystemHighlight] {
        systemHighlights(report)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HighlightCoverageNotice(coverage: collectionCoverage(for: report))

            if highlights.isEmpty {
                ContentCard(
                    title: "No relationship cards available",
                    detail: "This report did not contain both sides of the supported relationships. Check Collection coverage before interpreting a missing relationship as an absent configuration.",
                    symbolName: "point.3.filled.connected.trianglepath.dotted"
                )
            } else {
                ForEach(highlights) { highlight in
                    SystemHighlightCard(highlight: highlight)
                }
            }
        }
    }
}

private struct HighlightCoverageNotice: View {
    let coverage: CollectionCoverage

    var body: some View {
        Label(
            "This view uses \(coverage.collectedCount) collected and \(coverage.emptyCount) empty sections. \(coverage.incompleteEntries.count) section(s) were incomplete, unavailable, timed out, permission-limited, or skipped.",
            systemImage: "checklist"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(13)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct SystemHighlightCard: View {
    let highlight: SystemHighlight

    @State private var isShowingEvidence: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: highlight.symbolName)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.title)
                        .font(.headline)
                    Text(highlight.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label(highlight.interpretationLimit, systemImage: "exclamationmark.bubble")
                .font(.caption)
                .foregroundStyle(.secondary)

            DisclosureGroup("Evidence fields (\(highlight.evidence.count))", isExpanded: $isShowingEvidence) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(highlight.evidence) { evidence in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(evidence.dataType.title) · \(evidence.presentation.title)")
                                .font(.caption.weight(.semibold))
                            Text(evidence.presentation.displayedValue)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text(evidence.presentation.sourcePath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        }
    }
}
