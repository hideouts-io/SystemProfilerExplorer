import Foundation

/// One section of the panel shown when a row is expanded.
struct ValuePanelSection: Sendable, Equatable, Identifiable {
    enum Kind: String, Sendable {
        case meaning
        case significance
        case reasons
        case action
    }

    let kind: Kind
    let title: String
    let symbolName: String
    let lines: [String]

    var id: Kind { kind }
}

/// The expanded panel leads with the value: what this result means, why it matters,
/// the clues behind an inference, then what to check. Text about the field in general
/// never appears here; it lives in the collapsed About this field area.
func valuePanelSections(for explanation: ValueExplanation) -> [ValuePanelSection] {
    var sections: [ValuePanelSection] = []

    if let detail = explanation.detail {
        sections.append(ValuePanelSection(
            kind: .meaning,
            title: "What this result means",
            symbolName: "text.magnifyingglass",
            lines: [detail]
        ))
    }

    if let significance = explanation.significance {
        sections.append(ValuePanelSection(
            kind: .significance,
            title: "Why it matters",
            symbolName: "scope",
            lines: [significance]
        ))
    }

    let reasons: [String] = explanation.confidence?.reasons ?? []

    if !reasons.isEmpty {
        sections.append(ValuePanelSection(
            kind: .reasons,
            title: "Why the app thinks so",
            symbolName: "list.bullet",
            lines: reasons
        ))
    }

    if let action = explanation.suggestedAction {
        sections.append(ValuePanelSection(
            kind: .action,
            title: "What to check",
            symbolName: "checklist",
            lines: [action]
        ))
    }

    return sections
}

/// The small line under the value panel that names where the explanation comes from.
func valueSourceLine(for explanation: ValueExplanation) -> String? {
    explanation.confidence.map { "Source: \($0.title)" }
}

/// Field-level text appears once per row, in a small collapsed area. It opens by itself
/// only when the value has no explanation of its own (names, numbers, identifiers),
/// because then it is the only explanation there is.
func aboutThisFieldStartsExpanded(valueExplanation: ValueExplanation?) -> Bool {
    valueExplanation == nil
}
