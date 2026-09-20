import Foundation

enum ChangeImportance: String, CaseIterable, Identifiable, Sendable, Equatable {
    case reviewFirst
    case review
    case informational

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reviewFirst: "Review First"
        case .review: "Worth Reviewing"
        case .informational: "Informational"
        }
    }

    var detail: String {
        switch self {
        case .reviewFirst:
            "Configuration or security-related inventory changed. Review the evidence and expected change history first."
        case .review:
            "This can affect troubleshooting, connectivity, power behavior, or hardware inventory."
        case .informational:
            "This is an inventory difference without an automatic security conclusion."
        }
    }

    var symbolName: String {
        switch self {
        case .reviewFirst: "exclamationmark.shield"
        case .review: "exclamationmark.circle"
        case .informational: "info.circle"
        }
    }
}

struct ReportChangeInsight: Identifiable, Sendable, Equatable {
    let change: ReportChange
    let importance: ChangeImportance
    let title: String
    let explanation: String

    var id: String { change.id }
}

func reportChangeInsights(_ comparison: ReportComparison) -> [ReportChangeInsight] {
    comparison.changes.map(reportChangeInsight)
}

func reportChangeInsight(_ change: ReportChange) -> ReportChangeInsight {
    let scalar: ProfileScalar = change.currentValue ?? change.previousValue ?? .null
    let presentation: FieldPresentation = fieldPresentation(
        dataType: change.dataType,
        path: change.catalogPath,
        scalar: scalar
    )
    let importance: ChangeImportance = changeImportance(change)

    return ReportChangeInsight(
        change: change,
        importance: importance,
        title: presentation.title,
        explanation: plainLanguageChangeExplanation(change: change, presentation: presentation)
    )
}

func changeImportance(_ change: ReportChange) -> ChangeImportance {
    switch change.dataType {
    case .firewall, .configurationProfiles, .managedClient, .startupItems,
         .extensions, .secureElement, .smartCards, .universalAccess:
        return .reviewFirst
    case .network, .wifi, .ethernet, .networkLocation, .networkVolumes,
         .power, .storage, .nvme, .serialATA, .hardware, .memory:
        return .review
    default:
        return .informational
    }
}

private func plainLanguageChangeExplanation(
    change: ReportChange,
    presentation: FieldPresentation
) -> String {
    let observedDifference: String

    switch change.kind {
    case .added:
        observedDifference = "\(presentation.title) is newly reported for \(change.recordLabel)."
    case .removed:
        observedDifference = "\(presentation.title) is no longer reported for \(change.recordLabel)."
    case .changed:
        let previous: String = formattedChangeValue(
            change.previousValue,
            dataType: change.dataType,
            catalogPath: change.catalogPath
        )
        let current: String = formattedChangeValue(
            change.currentValue,
            dataType: change.dataType,
            catalogPath: change.catalogPath
        )
        observedDifference = "\(presentation.title) changed from \(previous) to \(current) for \(change.recordLabel)."
    }

    guard let explanation = presentation.explanation else {
        return "\(observedDifference) The app does not have a field-specific interpretation, so this remains a raw inventory difference rather than a diagnosis."
    }

    return "\(observedDifference) \(explanation.meaning) \(explanation.interpretation)"
}

private func formattedChangeValue(
    _ value: ProfileScalar?,
    dataType: SystemProfilerDataType,
    catalogPath: [String]
) -> String {
    guard let value else {
        return "not present"
    }

    return fieldPresentation(
        dataType: dataType,
        path: catalogPath,
        scalar: value
    ).displayedValue
}
