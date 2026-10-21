import Foundation

enum ComparisonEvidenceSide: String, Sendable, Identifiable {
    case baseline
    case current

    var id: String { rawValue }

    var title: String {
        switch self {
        case .baseline: "Baseline"
        case .current: "Current"
        }
    }
}

struct ComparisonRawEvidence: Sendable, Equatable {
    let side: ComparisonEvidenceSide
    let address: ProfileValueAddress
    let value: ProfileValue
    let completedAt: Date
}

enum ComparisonRawEvidenceError: LocalizedError, Equatable {
    case missingSide(ComparisonEvidenceSide)
    case valueMismatch

    var errorDescription: String? {
        switch self {
        case let .missingSide(side):
            "This finding has no \(side.title.lowercased()) evidence. Added findings exist only in the current report; removed findings exist only in the baseline."
        case .valueMismatch:
            "The addressed value does not match this comparison's reported value. No substitute evidence was shown. Close this viewer and create a new comparison."
        }
    }
}

/// Uses the original in-memory source for this side, never a later scan or file read.
/// Resolution and value validation fail explicitly rather than searching by a display
/// path, substituting the other side, or confusing a reported null with missing data.
func comparisonRawEvidence(
    for change: ReportChange,
    side: ComparisonEvidenceSide,
    comparison: ReportComparison
) throws -> ComparisonRawEvidence {
    guard comparison.changes.contains(change) else {
        throw ComparisonRawEvidenceError.valueMismatch
    }
    let report: SystemProfilerReport
    let address: ProfileValueAddress?
    let expectedValue: ProfileScalar?
    switch side {
    case .baseline:
        report = comparison.baselineReport
        address = change.baselineAddress
        expectedValue = change.previousValue
    case .current:
        report = comparison.currentReport
        address = change.currentAddress
        expectedValue = change.currentValue
    }

    guard let address, let expectedValue else {
        throw ComparisonRawEvidenceError.missingSide(side)
    }
    let value: ProfileValue = try profileValue(at: address, in: report)
    guard value == rawProfileValue(expectedValue) else {
        throw ComparisonRawEvidenceError.valueMismatch
    }
    return ComparisonRawEvidence(side: side, address: address, value: value, completedAt: report.completedAt)
}

private func rawProfileValue(_ scalar: ProfileScalar) -> ProfileValue {
    switch scalar {
    case let .string(value): .string(value)
    case let .integer(value): .integer(value)
    case let .decimal(value): .decimal(value)
    case let .boolean(value): .boolean(value)
    case .null: .null
    }
}

/// Reconstructed JSON for the selected structured value, not original file bytes.
/// Pages use the existing bounded, cancellation-aware text pagination and never
/// normalize, redact, or truncate the retained value.
func comparisonRawEvidencePages(_ evidence: ComparisonRawEvidence) throws -> [String] {
    try Task.checkCancellation()
    let encoder: JSONEncoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data: Data = try encoder.encode(evidence.value)
    return try diagnosticLogPages(String(decoding: data, as: UTF8.self))
}

/// Original-source failures remain distinct from a successful structured lookup.
enum OriginalEvidencePresentation: Sendable, Equatable {
    case unavailable
    case available(pages: [String], byteRange: Range<Int>)
    case failed(message: String)
}

struct AddressedReportEvidence: Sendable, Equatable {
    let value: ProfileValue
    let structuredPages: [String]
    let original: OriginalEvidencePresentation
}

/// Resolves retained immutable input only. No source file is reopened or persisted.
func addressedReportEvidence(
    at address: ProfileValueAddress,
    in report: SystemProfilerReport
) throws -> AddressedReportEvidence {
    try Task.checkCancellation()
    let value: ProfileValue = try profileValue(at: address, in: report)
    let encoder: JSONEncoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let structured: Data = try encoder.encode(value)
    let structuredPages: [String] = try diagnosticLogPages(String(decoding: structured, as: UTF8.self))
    let original: OriginalEvidencePresentation
    do {
        if let excerpt = try originalSourceExcerpt(at: address, in: report) {
            original = .available(pages: try diagnosticLogPages(excerpt.text), byteRange: excerpt.byteRange)
        } else {
            original = .unavailable
        }
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        original = .failed(message: error.localizedDescription)
    }
    try Task.checkCancellation()
    return AddressedReportEvidence(value: value, structuredPages: structuredPages, original: original)
}
