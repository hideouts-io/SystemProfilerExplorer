import Foundation

/// A single finding as Markdown, for pasting into a support request or note.
func findingMarkdown(
    presentation: FieldPresentation,
    valueExplanation: ValueExplanation?
) -> String {
    var lines: [String] = [
        "**\(presentation.title):** \(inlineCode(presentation.displayedValue))"
    ]

    if let valueExplanation {
        let likely: String = if case .likely = valueExplanation.confidence { "Likely: " } else { "" }
        lines.append("- \(valueExplanation.status.title): \(likely)\(valueExplanation.summary)")

        if let action = valueExplanation.suggestedAction {
            lines.append("- What you can do: \(action)")
        }
    }

    if let explanation = presentation.explanation {
        lines.append("- About this field: \(explanation.meaning)")
    }

    var source: String = "- Source: \(inlineCode(presentation.sourcePath))"

    if presentation.displayedValue != presentation.rawValue {
        source += " (raw value \(inlineCode(presentation.rawValue)))"
    }

    lines.append(source)
    return lines.joined(separator: "\n")
}

/// Wraps text in a code span that survives backticks inside the value.
private func inlineCode(_ text: String) -> String {
    let singleLine: String = text.replacingOccurrences(of: "\n", with: " ")
    return singleLine.contains("`") ? "`` \(singleLine) ``" : "`\(singleLine)`"
}
