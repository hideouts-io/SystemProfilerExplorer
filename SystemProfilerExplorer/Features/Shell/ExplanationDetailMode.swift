import SwiftUI

/// How much technical detail findings show. Beginner leads with plain-language meaning;
/// Developer adds raw values, source paths, and explanation provenance.
enum ExplanationDetailMode: String, CaseIterable, Identifiable, Sendable {
    case beginner
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .developer: "Developer"
        }
    }

    var help: String {
        switch self {
        case .beginner: "Show plain-language explanations"
        case .developer: "Also show raw values, source paths, and where explanations come from"
        }
    }
}

let explanationDetailModeStorageKey: String = "explanation-detail-mode"

private struct ExplanationDetailModeKey: EnvironmentKey {
    static let defaultValue: ExplanationDetailMode = .beginner
}

private struct ValueReportContextKey: EnvironmentKey {
    static let defaultValue: ValueReportContext = .empty
}

extension EnvironmentValues {
    var explanationDetailMode: ExplanationDetailMode {
        get { self[ExplanationDetailModeKey.self] }
        set { self[ExplanationDetailModeKey.self] = newValue }
    }

    var valueReportContext: ValueReportContext {
        get { self[ValueReportContextKey.self] }
        set { self[ValueReportContextKey.self] = newValue }
    }
}
