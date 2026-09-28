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

/// The expanded "What this value means on your Mac" panel. The row already shows the
/// one-line summary, so the panel adds only the detail, reasons, and next step.
struct ValueMeaningView: View {
    let explanation: ValueExplanation

    @Environment(\.explanationDetailMode) private var detailMode

    var body: some View {
        if hasContent {
            panel
        }
    }

    private var reasons: [String] {
        explanation.confidence?.reasons ?? []
    }

    private var hasContent: Bool {
        explanation.detail != nil
            || !reasons.isEmpty
            || explanation.suggestedAction != nil
            || (detailMode == .developer && explanation.confidence != nil)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let detail = explanation.detail {
                ValueMeaningSection(title: "What this value means on your Mac", symbolName: "text.magnifyingglass") {
                    Text(detail)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !reasons.isEmpty {
                ValueMeaningSection(title: "Why the app thinks so", symbolName: "list.bullet") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(reasons, id: \.self) { reason in
                            Label(reason, systemImage: "circle.fill")
                                .labelStyle(ReasonLabelStyle())
                        }
                    }
                }
            }

            if let action = explanation.suggestedAction {
                ValueMeaningSection(title: "What you can do", symbolName: "hand.point.right") {
                    Text(action)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if detailMode == .developer, let confidence = explanation.confidence {
                Text("Explanation source: \(confidence.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct ValueMeaningSection<Content: View>: View {
    let title: String
    let symbolName: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            content()
        }
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

/// Plain-language sentences at the top of a report, built from collected values.
struct AtAGlanceCard: View {
    let sentences: [String]
    let worthReviewingCount: Int
    let showWorthReviewing: () -> Void

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

            if worthReviewingCount > 0 {
                Button(action: showWorthReviewing) {
                    Label {
                        Text("\(worthReviewingCount) \(worthReviewingCount == 1 ? "finding is" : "findings are") worth a look")
                    } icon: {
                        Image(systemName: ValueStatus.worthReviewing.symbolName)
                            .foregroundStyle(ValueStatus.worthReviewing.tint)
                    }
                }
                .buttonStyle(.link)
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
