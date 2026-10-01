import SwiftUI

extension ValueStatus {
    var tint: Color {
        switch self {
        case .normal: .green
        case .informational: .blue
        case .worthReviewing: .orange
        case .unknown: .secondary
        }
    }
}

/// Status is always shown as icon plus word, never by color alone. The word uses the
/// primary label color so it stays readable; orange and green text on a light background
/// fall well below accessible contrast.
struct ValueStatusBadge: View {
    let status: ValueStatus

    var body: some View {
        Label {
            Text(status.title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.tint)
        }
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(status.tint.opacity(0.13), in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(status.title)")
    }
}

/// The one-line answer shown under a finding's value.
struct ValueSummaryLine: View {
    let explanation: ValueExplanation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ValueStatusBadge(status: explanation.status)

            Group {
                if case .likely = explanation.confidence {
                    Text("\(Text("Likely:").fontWeight(.semibold)) \(explanation.summary)")
                } else {
                    Text(explanation.summary)
                }
            }
            .font(.callout)
            .foregroundStyle(explanation.status == .unknown ? .secondary : .primary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The first thing in an expanded row: what this value means, why it matters, and what
/// to check. The row already shows the one-line summary, so the panel adds the rest.
struct ValueMeaningView: View {
    let explanation: ValueExplanation

    var body: some View {
        let sections: [ValuePanelSection] = valuePanelSections(for: explanation)

        if !sections.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sections) { section in
                    ValueMeaningSection(section: section)
                }

                if let source = valueSourceLine(for: explanation) {
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("value-source")
                }
            }
            .textSelection(.enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(explanation.status.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
            .padding(.top, 8)
            .accessibilityIdentifier("value-meaning")
        }
    }
}

private struct ValueMeaningSection: View {
    let section: ValuePanelSection

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(section.title, systemImage: section.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            if section.kind == .reasons {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(section.lines, id: \.self) { reason in
                        Label(reason, systemImage: "circle.fill")
                            .labelStyle(ReasonLabelStyle())
                    }
                }
            } else {
                ForEach(section.lines, id: \.self) { line in
                    Text(line)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("value-section-\(section.kind.rawValue)")
    }
}

private struct ReasonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            configuration.icon
                .font(.system(size: 4))
                .foregroundStyle(.secondary)
                .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] + 3 }
            configuration.title
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Text about the field in general, shown once per row in a small collapsed area so it
/// never crowds out what the value means. It holds the explanation coverage note too.
struct AboutThisFieldView: View {
    let presentation: FieldPresentation
    let startsExpanded: Bool
    let openSourceLocation: (String) -> Void

    @Environment(\.explanationDetailMode) private var detailMode
    @State private var isExpanded: Bool

    init(presentation: FieldPresentation, startsExpanded: Bool, openSourceLocation: @escaping (String) -> Void) {
        self.presentation = presentation
        self.startsExpanded = startsExpanded
        self.openSourceLocation = openSourceLocation
        _isExpanded = State(initialValue: startsExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if let explanation = presentation.explanation {
                    FieldNote(title: "What the field records", text: explanation.meaning)
                    FieldNote(title: "Why the field matters", text: explanation.significance)
                    FieldNote(title: "Interpret carefully", text: explanation.interpretation)

                    if let privacy = explanation.privacy {
                        FieldNote(title: "Privacy", text: privacy)
                    }
                } else {
                    FieldNote(
                        title: "Unrecognized field",
                        text: "The value is preserved exactly as system_profiler reported it. The app does not infer a meaning for an unrecognized field."
                    )
                }

                CoverageNote(coverage: explanationCoverage(for: presentation))

                if detailMode == .developer {
                    FieldSourceDetails(presentation: presentation, openSourceLocation: openSourceLocation)
                }
            }
            .textSelection(.enabled)
            .padding(.top, 6)
        } label: {
            Label("About this field", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
        .padding(.top, 8)
        .accessibilityIdentifier("about-this-field")
        // After a rescan the row can show a different value, so it returns to the
        // default for that value instead of keeping the old open or closed state.
        .onChange(of: presentation.rawValue) { _ in
            isExpanded = startsExpanded
        }
        .onChange(of: startsExpanded) { newValue in
            isExpanded = newValue
        }
    }
}

private struct FieldNote: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The explanation coverage note, such as "Curated explanation". It describes the app's
/// catalog, not the Mac, so it sits with the field notes rather than on every row.
private struct CoverageNote: View {
    let coverage: ExplanationCoverage

    var body: some View {
        Label {
            Text("\(Text(coverage.title).fontWeight(.semibold)). \(coverage.detail)")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: coverage.symbolName)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("explanation-coverage")
    }
}

private struct FieldSourceDetails: View {
    let presentation: FieldPresentation
    let openSourceLocation: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Source field", value: presentation.sourcePath)

                if presentation.displayedValue != presentation.rawValue {
                    LabeledContent("Raw value", value: presentation.rawValue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                openSourceLocation(presentation.sourcePath)
            } label: {
                Label("Show Raw Source Location", systemImage: "arrow.turn.down.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("open-raw-source-\(presentation.sourcePath)")
        }
    }
}

/// Plain-language sentences at the top of a report, built from collected values, followed
/// by the values worth a look so the answer to "is this Mac OK?" is on the first screen.
struct AtAGlanceCard: View {
    let sentences: [String]
    let worthReviewingItems: [WorthReviewingItem]
    let showItem: (WorthReviewingItem) -> Void
    let showAllWorthReviewing: () -> Void

    private let visibleItemLimit: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("At a glance", systemImage: "text.alignleft")
                .font(.headline)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(sentences, id: \.self) { sentence in
                    Text(sentence)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .textSelection(.enabled)

            if worthReviewingItems.isEmpty {
                Label {
                    Text("Nothing in this scan needs a look.")
                } icon: {
                    Image(systemName: ValueStatus.normal.symbolName)
                        .foregroundStyle(ValueStatus.normal.tint)
                }
                .accessibilityIdentifier("glance-nothing-worth-a-look")
            } else {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Worth a look")
                    } icon: {
                        Image(systemName: ValueStatus.worthReviewing.symbolName)
                            .foregroundStyle(ValueStatus.worthReviewing.tint)
                    }
                    .font(.subheadline.weight(.semibold))

                    ForEach(worthReviewingItems.prefix(visibleItemLimit)) { item in
                        WorthReviewingItemRow(item: item, show: { showItem(item) })
                    }

                    if worthReviewingItems.count > visibleItemLimit {
                        Button("Show all \(worthReviewingItems.count)", action: showAllWorthReviewing)
                            .buttonStyle(.link)
                    }
                }
                .accessibilityIdentifier("glance-worth-a-look")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier("at-a-glance")
    }
}

private struct WorthReviewingItemRow: View {
    let item: WorthReviewingItem
    let show: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.summary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(item.dataType.title) › \(item.recordLabel) › \(item.fieldTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button("Show", action: show)
                .controlSize(.small)
                .accessibilityLabel("Show \(item.fieldTitle) in \(item.recordLabel)")
        }
        .padding(.leading, 24)
    }
}

/// The word for an explained value: "values" for beginners, "findings" for developers.
func findingNoun(_ count: Int, mode: ExplanationDetailMode) -> String {
    switch mode {
    case .beginner: count == 1 ? "value" : "values"
    case .developer: count == 1 ? "finding" : "findings"
    }
}

// MARK: - Glossary

/// Buttons for glossary terms mentioned in an explanation. Each shows its definition.
struct GlossaryTermsRow: View {
    let texts: [String]

    var body: some View {
        let terms: [GlossaryTerm] = glossaryTerms(mentionedIn: texts)

        if !terms.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Terms used here")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                WrappingHStack(spacing: 6) {
                    ForEach(terms) { term in
                        GlossaryTermButton(term: term)
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityIdentifier("glossary-terms")
        }
    }
}

private struct GlossaryTermButton: View {
    let term: GlossaryTerm

    @State private var isShowingDefinition: Bool = false

    var body: some View {
        Button(term.term) {
            isShowingDefinition = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(term.definition)
        .popover(isPresented: $isShowingDefinition, arrowEdge: .bottom) {
            GlossaryDefinition(term: term)
                .padding(14)
                .frame(width: 320, alignment: .leading)
        }
    }
}

private struct GlossaryDefinition: View {
    let term: GlossaryTerm

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(term.term)
                .font(.headline)
            Text(term.definition)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

/// Every glossary term, searchable.
struct GlossarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Glossary", systemImage: "character.book.closed")
                    .font(.title2.weight(.semibold))
                Spacer()
                TextField("Search terms", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .accessibilityIdentifier("glossary-search")
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredTerms) { term in
                        GlossaryDefinition(term: term)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if filteredTerms.isEmpty {
                        Text("No terms match “\(searchText)”.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Text("Short definitions of terms used in explanations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: dismiss.callAsFunction)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 560, minHeight: 560)
        .accessibilityIdentifier("glossary-sheet")
    }

    private var filteredTerms: [GlossaryTerm] {
        let query: String = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return glossary
        }

        return glossary.filter {
            $0.term.localizedCaseInsensitiveContains(query) || $0.definition.localizedCaseInsensitiveContains(query)
        }
    }
}

/// Lays out children left to right, wrapping to new lines as needed.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows: [[CGSize]] = arrangeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width: CGFloat = rows.map { row in row.map(\.width).reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0)) }.max() ?? 0
        let height: CGFloat = rows.map { $0.map(\.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin: CGPoint = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size: CGSize = subview.sizeThatFits(.unspecified)

            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func arrangeRows(maxWidth: CGFloat, subviews: Subviews) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size: CGSize = subview.sizeThatFits(.unspecified)

            if !rows[rows.count - 1].isEmpty, rowWidth + spacing + size.width > maxWidth {
                rows.append([])
                rowWidth = 0
            }

            rowWidth += (rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width
            rows[rows.count - 1].append(size)
        }

        return rows
    }
}
