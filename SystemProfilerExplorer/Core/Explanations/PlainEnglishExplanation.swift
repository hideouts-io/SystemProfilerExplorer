import Foundation

/// Only maintained, value-independent catalog text crosses the model boundary. There
/// is intentionally no report, scalar value, record name, or source location here.
struct PlainEnglishExplanationInput: Codable, Sendable, Equatable {
    let title: String
    let meaning: String
    let significance: String
    let interpretation: String
}

enum PlainEnglishAvailability: Sendable, Equatable {
    case available
    case unavailable(PlainEnglishUnavailableReason)
}

enum PlainEnglishViewState: Sendable, Equatable {
    case loading
    case generated(title: String, text: String)
    case unavailable(PlainEnglishUnavailableReason)
    case failed(PlainEnglishExplanationError)
    case cancelled
}

/// Model readiness can change between preflight and inference. Keep that refusal
/// distinct from a failed generation so the user can explicitly recheck readiness.
func plainEnglishFailureState(error: PlainEnglishExplanationError) -> PlainEnglishViewState {
    if case let .unavailable(reason) = error {
        return .unavailable(reason)
    }
    return .failed(error)
}

enum PlainEnglishUnavailableReason: Sendable, Equatable {
    case operatingSystem
    case buildWithoutFramework
    case deviceNotEligible
    case notEnabled
    case modelNotReady
    case unsupportedLanguage
    case unknown

    var message: String {
        switch self {
        case .operatingSystem:
            "On-device explanations require macOS 26 or later. The app’s maintained explanations still work on this Mac."
        case .buildWithoutFramework:
            "This build does not include the on-device model framework. Use the maintained explanations below."
        case .deviceNotEligible:
            "This Mac does not support Apple’s on-device language model. The app’s maintained explanations remain available."
        case .notEnabled:
            "Apple Intelligence is not enabled on this Mac. You can review Apple Intelligence in System Settings; this app will not change that setting. The maintained explanations still work."
        case .modelNotReady:
            "Apple’s on-device model is not ready. Check Apple Intelligence in System Settings and try again once its model is available. The maintained explanations still work."
        case .unsupportedLanguage:
            "The installed model does not support English in its current configuration. Use the app’s maintained explanations."
        case .unknown:
            "Apple’s on-device model is unavailable for an unrecognized reason. Check Apple Intelligence in System Settings; no cloud service will be used."
        }
    }
}

enum PlainEnglishExplanationError: LocalizedError, Equatable {
    case unsupportedField
    case invalidInput
    case inputTooLarge
    case contextLimit
    case emptyOutput
    case outputTooLarge
    case unavailable(PlainEnglishUnavailableReason)
    case timedOut
    case generationFailed(domain: String, code: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedField:
            "This prototype only simplifies selected, value-independent hardware fields and battery cycle count. It does not interpret unknown fields or private identifiers."
        case .invalidInput:
            "The maintained field explanation is incomplete. Use the existing explanation and report this field to the project."
        case .inputTooLarge:
            "The maintained explanation exceeds the prototype’s input limit. No text was sent to the model."
        case .contextLimit:
            "Apple’s on-device model could not fit the maintained explanation into its context window. Use the maintained explanation."
        case .emptyOutput:
            "The on-device model returned no explanation. Use the maintained explanation or explicitly try again."
        case .outputTooLarge:
            "The generated explanation exceeded the display limit and was not shown. Use the maintained explanation."
        case let .unavailable(reason):
            reason.message
        case .timedOut:
            "The on-device explanation exceeded its 30-second deadline. Use the maintained explanation or explicitly try again."
        case let .generationFailed(domain, code):
            "The on-device explanation failed (\(domain), code \(code)). Use the maintained explanation; no cloud explanation service was used."
        }
    }
}

/// An explicit prototype allowlist avoids dynamic catalog titles and value-dependent
/// interpretations. In particular, names, identifiers, log contents and unknown fields
/// cannot become prompt text, even when their catalog paths come from an imported file.
func plainEnglishFieldIsSupported(dataType: SystemProfilerDataType, path: [String]) -> Bool {
    switch dataType {
    case .hardware:
        path.count == 1 && [
            "boot_rom_version", "chip_type", "machine_model", "machine_name",
            "number_processors", "os_loader_version", "physical_memory"
        ].contains(path[0])
    case .power:
        path.last == "sppower_battery_cycle_count"
    default:
        false
    }
}

func plainEnglishExplanationInput(
    dataType: SystemProfilerDataType,
    path: [String]
) throws -> PlainEnglishExplanationInput {
    guard plainEnglishFieldIsSupported(dataType: dataType, path: path),
          let field = path.last,
          let catalog = explanation(for: dataType, path: [field], reportedValue: ""),
          catalog.privacy == nil else {
        throw PlainEnglishExplanationError.unsupportedField
    }
    return PlainEnglishExplanationInput(
        title: catalog.title,
        meaning: catalog.meaning,
        significance: catalog.significance,
        interpretation: catalog.interpretation
    )
}

/// Bound the encoded payload, not just character count; multibyte characters and JSON
/// escapes consume input too. The caller must not truncate or silently drop caveats.
func plainEnglishPrompt(input: PlainEnglishExplanationInput) throws -> String {
    let fields: [String] = [input.title, input.meaning, input.significance, input.interpretation]
    guard fields.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
        throw PlainEnglishExplanationError.invalidInput
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let encoded: Data = try encoder.encode(input)
    guard encoded.count <= 6_000 else {
        throw PlainEnglishExplanationError.inputTooLarge
    }
    return String(decoding: encoded, as: UTF8.self)
}

/// Generated prose is not source evidence. Reject empty/oversized output rather than
/// inventing content or presenting a silently truncated explanation.
func validatedPlainEnglishOutput(_ output: String) throws -> String {
    guard output.utf8.count <= 2_400 else {
        throw PlainEnglishExplanationError.outputTooLarge
    }
    let text: String = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
        throw PlainEnglishExplanationError.emptyOutput
    }
    return text
}
