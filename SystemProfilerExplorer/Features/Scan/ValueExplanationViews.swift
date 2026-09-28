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

/// Status is always shown as icon plus word, never by color alone.
struct ValueStatusBadge: View {
    let status: ValueStatus

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(status.tint)
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
