import Foundation
import Testing
@testable import SystemProfilerExplorer

/// The expanded row leads with the value; text about the field stays in one small,
/// collapsed About this field area.
struct ValuePanelTests {
    @Test
    func panelLeadsWithTheValueInReadingOrder() throws {
        let explanation = try #require(valueExplanation(
            dataType: .software,
            path: ["system_integrity"],
            scalar: .string("integrity_disabled")
        ))
        let sections: [ValuePanelSection] = valuePanelSections(for: explanation)

        #expect(sections.map(\.kind) == [.meaning, .significance, .action])
        #expect(sections.map(\.title) == ["What this result means", "Why it matters", "What to check"])
        #expect(valueSourceLine(for: explanation) == "Source: Documented by Apple")
    }

    @Test
    func inferredValuesListTheirCluesBeforeWhatToCheck() {
        let explanation: ValueExplanation = .info(
            "A summary.",
            detail: "What it means.",
            why: "Why it matters.",
            action: "What to check.",
            confidence: .likely(reasons: ["First clue.", "Second clue."])
        )
        let sections: [ValuePanelSection] = valuePanelSections(for: explanation)

        #expect(sections.map(\.kind) == [.meaning, .significance, .reasons, .action])
        #expect(sections.first { $0.kind == .reasons }?.lines == ["First clue.", "Second clue."])
        #expect(valueSourceLine(for: explanation) == "Source: Inferred by the app")
    }

    @Test
    func fieldTextNeverAppearsInTheValuePanel() throws {
        let path: [String] = ["system_integrity"]
        let scalar: ProfileScalar = .string("integrity_enabled")
        let field = try #require(fieldPresentation(dataType: .software, path: path, scalar: scalar).explanation)
        let value = try #require(valueExplanation(dataType: .software, path: path, scalar: scalar))
        let panelText: [String] = valuePanelSections(for: value).flatMap(\.lines)

        #expect(!panelText.isEmpty)
        #expect(!panelText.contains(field.meaning))
        #expect(!panelText.contains(field.significance))
        #expect(!panelText.contains(field.interpretation))
    }

    @Test
    func aboutThisFieldOpensOnlyWhenTheValueHasNoExplanation() throws {
        let explained = try #require(valueExplanation(
            dataType: .software,
            path: ["system_integrity"],
            scalar: .string("integrity_enabled")
        ))

        #expect(aboutThisFieldStartsExpanded(valueExplanation: explained) == false)
        #expect(aboutThisFieldStartsExpanded(valueExplanation: .unexplained("future_value")) == false)
        #expect(aboutThisFieldStartsExpanded(valueExplanation: nil) == true)
    }

    @Test
    func unrecognizedValuesSayTheyArentExplainedAndNeverGuess() throws {
        let explanation = try #require(valueExplanation(
            dataType: .software,
            path: ["system_integrity"],
            scalar: .string("integrity_future_state")
        ))

        #expect(explanation.status == .unknown)
        #expect(explanation.summary.contains("isn't explained yet"))
        #expect(explanation.summary.contains("integrity_future_state"))
        #expect(explanation.confidence == nil)
        #expect(explanation.significance == nil)
        #expect(valueSourceLine(for: explanation) == nil)
        #expect(explanation.suggestedAction?.contains("About this field") == true)
    }

    @Test
    func confidenceTitlesNameTheSource() {
        #expect(ValueConfidence.documented.title == "Documented by Apple")
        #expect(ValueConfidence.observed.title == "Standard macOS behavior")
        #expect(ValueConfidence.likely(reasons: []).title == "Inferred by the app")
    }
}
