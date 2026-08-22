import Foundation

func accessibilityExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "contrast":
        return accessibilityValueExplanation(
            title: "Display Contrast",
            meaning: "This reports the configured accessibility contrast adjustment for the display.",
            significance: "Contrast adjustment can make interface boundaries and text easier to distinguish.",
            interpretation: "The value is a preference, not a display calibration measurement or evidence of a medical condition."
        )
    case "cursor_mag":
        return accessibilityValueExplanation(
            title: "Cursor Magnification",
            meaning: "This reports the configured cursor-size or magnification preference.",
            significance: "A larger pointer can improve visibility and make pointer tracking easier.",
            interpretation: "The setting does not prove current use, user identity, or a particular visual condition."
        )
    case "display":
        return accessibilityValueExplanation(
            title: "Display Accessibility Mode",
            meaning: "This summarizes a display-related accessibility setting represented by System Information.",
            significance: "Display adaptations can change color, contrast, motion, or visibility behavior to match user needs.",
            interpretation: "The summary does not describe every display accommodation and is not a hardware, calibration, or medical assessment."
        )
    case "flash_screen":
        return accessibilityBooleanExplanation(
            title: "Flash Screen for Alerts",
            meaning: "This reports whether the screen is configured to flash as a visual indication of an alert sound.",
            significance: "Visual alerts can make notifications perceptible when audio is unavailable or unsuitable.",
            interpretation: "The setting does not prove that an alert occurred or establish why the preference was enabled.",
            reportedValue: reportedValue
        )
    case "keyboardZoom":
        return accessibilityBooleanExplanation(
            title: "Keyboard Zoom Control",
            meaning: "This reports whether keyboard-based control is enabled for the relevant screen-zoom accessibility feature.",
            significance: "Keyboard control provides quick access to magnification without requiring pointer gestures.",
            interpretation: "Enabled capability does not prove that zoom was used or identify the person who configured it.",
            reportedValue: reportedValue
        )
    case "mouse_keys":
        return accessibilityBooleanExplanation(
            title: "Mouse Keys",
            meaning: "This reports whether the keyboard is configured to move and click the pointer through Mouse Keys.",
            significance: "Mouse Keys provides pointer control without relying on a conventional mouse or trackpad.",
            interpretation: "The setting does not prove active use, input-device failure, or a particular motor condition.",
            reportedValue: reportedValue
        )
    case "scrollZoom":
        return accessibilityBooleanExplanation(
            title: "Scroll Gesture Zoom",
            meaning: "This reports whether a modifier-assisted scroll gesture can control screen magnification.",
            significance: "Gesture zoom provides rapid, continuous magnification control from a mouse or trackpad.",
            interpretation: "Enabled capability does not prove that a zoom gesture occurred or that a specific input device was used.",
            reportedValue: reportedValue
        )
    case "slow_keys":
        return accessibilityBooleanExplanation(
            title: "Slow Keys",
            meaning: "This reports whether key presses must be held for a configured interval before macOS accepts them.",
            significance: "Slow Keys can reduce unintended input by filtering very brief key presses.",
            interpretation: "The setting does not reveal typed content, prove active use, or establish a medical reason for the preference.",
            reportedValue: reportedValue
        )
    case "sticky_keys":
        return accessibilityBooleanExplanation(
            title: "Sticky Keys",
            meaning: "This reports whether modifier keys can be entered sequentially instead of held simultaneously.",
            significance: "Sticky Keys can make multi-key shortcuts easier to perform with different input needs.",
            interpretation: "The setting does not reveal shortcuts used, prove active use, or establish why it was configured.",
            reportedValue: reportedValue
        )
    case "voiceover":
        return accessibilityBooleanExplanation(
            title: "VoiceOver",
            meaning: "This reports whether Apple's built-in screen reader is enabled in the collected accessibility configuration.",
            significance: "VoiceOver provides spoken and braille-oriented access to interface elements, text, and controls.",
            interpretation: "The state is point-in-time configuration and does not prove who used it, what content was read, or why it was enabled.",
            reportedValue: reportedValue
        )
    case "zoomMode":
        return accessibilityValueExplanation(
            title: "Zoom Mode",
            meaning: "This identifies the selected screen-magnification presentation mode, such as full-screen or a windowed region.",
            significance: "The mode controls how enlarged content is placed relative to the rest of the display.",
            interpretation: "The configured mode does not prove that zoom was active or identify the user or reason for the preference."
        )
    default:
        return nil
    }
}

private func accessibilityBooleanExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String
) -> FieldExplanation {
    softwareBooleanExplanation(
        title: title,
        meaning: meaning,
        significance: significance,
        interpretation: interpretation,
        reportedValue: reportedValue,
        privacy: accessibilityPrivacy
    )
}

private func accessibilityValueExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String
) -> FieldExplanation {
    FieldExplanation(
        title: title,
        meaning: meaning,
        significance: significance,
        interpretation: interpretation,
        privacy: accessibilityPrivacy
    )
}

private let accessibilityPrivacy: String = "Accessibility preferences can reveal sensitive information about user needs or working habits. Do not infer a diagnosis, and redact the settings from public reports unless they are directly relevant."
