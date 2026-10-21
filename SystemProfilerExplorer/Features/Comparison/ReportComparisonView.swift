import SwiftUI

private let comparisonPageSize: Int = 200

private enum ComparisonChangeFilter: String, CaseIterable, Identifiable {
    case all
    case added
    case removed
    case changed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .added: "Added"
        case .removed: "Removed"
        case .changed: "Changed"
        }
    }

    var changeKind: ReportChangeKind? {
        switch self {
        case .all: nil
        case .added: .added
        case .removed: .removed
        case .changed: .changed
        }
    }
}

struct ReportComparisonView: View {
    let comparison: ReportComparison

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: ComparisonChangeFilter = .all
    @State private var visibleChangeLimit: Int = comparisonPageSize
    @State private var selectedChange: ReportChange?

    var body: some View {
        let matchingChanges: [ReportChange] = filteredChanges(
            comparison.changes,
            searchText: searchText,
            filter: selectedFilter
        )
        let visibleChanges: [ReportChange] = Array(matchingChanges.prefix(visibleChangeLimit))

        VStack(spacing: 0) {
            ComparisonHeader(comparison: comparison)
            Divider()

            HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ComparisonSummaryStrip(summary: comparison.summary)
                    ComparisonIdentityNotice(identity: comparison.machineIdentity)
                    ComparisonPrivacyNotice()
                    UnresolvedComparisonMatchesView(comparison: comparison)

                    if comparison.summary.changeCount == 0 {
                        if comparison.unresolvedMatches.isEmpty {
                            NoReportChangesView()
                        } else {
                            Text("No confirmed changes. Unresolved matches still require review.")
                                .accessibilityIdentifier("comparison-unresolved-only")
                        }
                    } else {
                        ComparisonControls(
                            searchText: $searchText,
                            selectedFilter: $selectedFilter
                        )

                        HStack {
                            Text(comparisonResultDescription(
                                visibleCount: visibleChanges.count,
                                matchingCount: matchingChanges.count,
                                totalCount: comparison.changes.count
                            ))
                                .accessibilityIdentifier("comparison-result-counts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        if matchingChanges.isEmpty {
                            NoMatchingChangesView(clearFilters: clearFilters)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(visibleChanges) { change in
                                    ReportChangeRow(change: change, comparison: comparison, inspect: { selectedChange = change })

                                    if change.id != visibleChanges.last?.id {
                                        Divider()
                                    }
                                }

                                if visibleChanges.count < matchingChanges.count {
                                    Divider()
                                    Button {
                                        visibleChangeLimit += comparisonPageSize
                                    } label: {
                                        Label(
                                            showMoreChangesTitle(
                                                visibleCount: visibleChanges.count,
                                                totalCount: matchingChanges.count
                                            ),
                                            systemImage: "chevron.down.circle"
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityIdentifier("show-more-comparison-changes")
                                }
                            }
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                            }
                        }
                    }

                    ComparisonMethodNotice()
                }
                .padding(24)
            }
            .frame(minWidth: 370)

            if let selectedChange {
                ComparisonEvidenceInspector(change: selectedChange, comparison: comparison, close: { self.selectedChange = nil })
                    .frame(minWidth: 550, idealWidth: 650)
            }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("close-report-comparison")
            }
            .padding(18)
        }
        .frame(minWidth: 1020, idealWidth: 1280, minHeight: 700, idealHeight: 800)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("report-comparison-workspace")
        .onChange(of: searchText) { _ in
            visibleChangeLimit = comparisonPageSize
        }
        .onChange(of: selectedFilter) { _ in
            visibleChangeLimit = comparisonPageSize
        }
    }

    private func clearFilters() {
        searchText = ""
        selectedFilter = .all
    }
}

private struct ComparisonHeader: View {
    let comparison: ReportComparison

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.left.arrow.right.square.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text("Report Comparison")
                    .font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    Text("Baseline \(comparison.baselineCompletedAt.formatted(date: .abbreviated, time: .shortened))")
                    Image(systemName: "arrow.right")
                    Text("Current \(comparison.currentCompletedAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }
}

private struct ComparisonSummaryStrip: View {
    let summary: ReportComparisonSummary

    var body: some View {
        HStack(spacing: 10) {
            ComparisonMetric(
                title: "Added",
                value: summary.addedCount,
                symbolName: "plus.circle.fill",
                color: .green
            )
            ComparisonMetric(
                title: "Removed",
                value: summary.removedCount,
                symbolName: "minus.circle.fill",
                color: .red
            )
            ComparisonMetric(
                title: "Changed",
                value: summary.changedCount,
                symbolName: "pencil.circle.fill",
                color: .orange
            )
            ComparisonMetric(
                title: "Unchanged",
                value: summary.unchangedCount,
                symbolName: "equal.circle.fill",
                color: .secondary
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("comparison-summary")
    }
}

private struct ComparisonMetric: View {
    let title: String
    let value: Int
    let symbolName: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value.formatted())
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }
}

private struct ComparisonPrivacyNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Private comparison")
                    .font(.subheadline.weight(.semibold))
                Text("Changed values can include serial numbers, user names, software inventory, network details, and other identifiers. Keep screenshots and copied results private unless they are reviewed and sanitized.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        }
        .accessibilityIdentifier("comparison-privacy-notice")
    }
}

private struct ComparisonControls: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ComparisonChangeFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search records, fields, values, and source locations", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("comparison-search")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear comparison search")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }

            Picker("Change filter", selection: $selectedFilter) {
                ForEach(ComparisonChangeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 330)
            .accessibilityIdentifier("comparison-filter")
        }
    }
}

private struct ReportChangeRow: View {
    let change: ReportChange
    let comparison: ReportComparison
    let inspect: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                switch change.kind {
                case .added:
                    ComparisonValueRow(
                        title: "Current value",
                        value: change.currentValue,
                        dataType: change.dataType,
                        catalogPath: change.catalogPath,
                        color: .green
                    )
                case .removed:
                    ComparisonValueRow(
                        title: "Baseline value",
                        value: change.previousValue,
                        dataType: change.dataType,
                        catalogPath: change.catalogPath,
                        color: .red
                    )
                case .changed:
                    ComparisonValueRow(
                        title: "Baseline value",
                        value: change.previousValue,
                        dataType: change.dataType,
                        catalogPath: change.catalogPath,
                        color: .red
                    )
                    ComparisonValueRow(
                        title: "Current value",
                        value: change.currentValue,
                        dataType: change.dataType,
                        catalogPath: change.catalogPath,
                        color: .green
                    )
                }

                ComparisonSourceLocations(change: change, inspect: inspect)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        } label: {
            HStack(spacing: 12) {
                ChangeKindBadge(kind: change.kind)

                VStack(alignment: .leading, spacing: 3) {
                    Text(comparisonFieldTitle(change))
                        .font(.subheadline.weight(.semibold))
                    Text("\(change.dataType.title) · \(change.recordLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityIdentifier("comparison-change-\(change.id)")
        .onChange(of: isExpanded) { expanded in
            if expanded { inspect() }
        }
    }
}

private struct ChangeKindBadge: View {
    let kind: ReportChangeKind

    var body: some View {
        Label(changeKindTitle(kind), systemImage: changeKindSymbol(kind))
            .font(.caption.weight(.semibold))
            .foregroundStyle(changeKindColor(kind))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(changeKindColor(kind).opacity(0.1), in: Capsule())
    }
}

/// Display only evidence locations that exist in the corresponding report.
struct ComparisonSourceLocations: View {
    let change: ReportChange
    let inspect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let path = change.baselineSourcePath {
                ComparisonSourceLocationRow(
                    title: "Baseline source location", path: path,
                    identifier: "comparison-baseline-source-\(change.id)"
                )
            }
            if let path = change.currentSourcePath {
                ComparisonSourceLocationRow(
                    title: "Current source location", path: path,
                    identifier: "comparison-current-source-\(change.id)"
                )
            }
            Text("Source locations use each report's original record order.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Inspect baseline and current evidence", action: inspect)
                .accessibilityIdentifier("inspect-comparison-evidence-\(change.id)")
        }
        .accessibilityElement(children: .contain)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct ComparisonSourceLocationRow: View {
    let title: String
    let path: String
    let identifier: String

    var body: some View {
        LabeledContent(title) {
            Text(path)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(path)
        .accessibilityIdentifier(identifier)
    }
}

private struct ComparisonValueRow: View {
    let title: String
    let value: ProfileScalar?
    let dataType: SystemProfilerDataType
    let catalogPath: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(comparisonValueDescription(
                value,
                dataType: dataType,
                catalogPath: catalogPath
            ))
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct NoReportChangesView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("No finding changes detected")
                .font(.headline)
            Text("Every comparable finding in the selected report matches the current scan.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("no-report-changes")
    }
}

private struct NoMatchingChangesView: View {
    let clearFilters: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("No matching changes")
                .font(.headline)
            Button("Clear Search and Filter", action: clearFilters)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ComparisonMethodNotice: View {
    var body: some View {
        DisclosureGroup("How findings are matched") {
            Text("Top-level records and nested lists containing only object records are matched by a unique system_profiler _name, regardless of order. Duplicate names and unnamed records match by complete contents only when that value occurs once on each side. Non-unique candidates remain unresolved and are excluded from confirmed finding totals; the rest of the comparison continues. A sole unnamed top-level section container, scalar lists, and mixed-type lists remain positional. Source paths retain the actual report indices, not matching identities. Added, removed, and changed describe structured value differences, not their cause or whether they are harmful.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

private func filteredChanges(
    _ changes: [ReportChange],
    searchText: String,
    filter: ComparisonChangeFilter
) -> [ReportChange] {
    let normalizedSearch: String = searchText
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    return changes.filter { change in
        let matchesKind: Bool = filter.changeKind == nil || change.kind == filter.changeKind

        guard matchesKind else {
            return false
        }

        guard !normalizedSearch.isEmpty else {
            return true
        }

        return comparisonSearchValues(change).contains { value in
            value.localizedCaseInsensitiveContains(normalizedSearch)
        }
    }
}

private func comparisonSearchValues(_ change: ReportChange) -> [String] {
    let values: [String?] = [
        change.dataType.title,
        change.recordLabel,
        change.baselineSourcePath,
        change.currentSourcePath,
        change.previousValue?.rawDescription,
        change.currentValue?.rawDescription
    ]
    return values.compactMap { $0 }
}

private func comparisonFieldTitle(_ change: ReportChange) -> String {
    let scalar: ProfileScalar = change.currentValue ?? change.previousValue ?? .null
    return fieldPresentation(
        dataType: change.dataType,
        path: change.catalogPath,
        scalar: scalar
    ).title
}

private func comparisonValueDescription(
    _ value: ProfileScalar?,
    dataType: SystemProfilerDataType,
    catalogPath: [String]
) -> String {
    guard let value else {
        return "Not present"
    }

    return fieldPresentation(
        dataType: dataType,
        path: catalogPath,
        scalar: value
    ).displayedValue
}

private func changeKindTitle(_ kind: ReportChangeKind) -> String {
    switch kind {
    case .added: "Added"
    case .removed: "Removed"
    case .changed: "Changed"
    }
}

private func changeKindSymbol(_ kind: ReportChangeKind) -> String {
    switch kind {
    case .added: "plus"
    case .removed: "minus"
    case .changed: "pencil"
    }
}

private func changeKindColor(_ kind: ReportChangeKind) -> Color {
    switch kind {
    case .added: .green
    case .removed: .red
    case .changed: .orange
    }
}

private func comparisonResultDescription(
    visibleCount: Int,
    matchingCount: Int,
    totalCount: Int
) -> String {
    "Showing \(visibleCount) of \(matchingCount) matching changes · \(totalCount) confirmed total · \(totalCount - matchingCount) hidden by filters"
}

private func showMoreChangesTitle(visibleCount: Int, totalCount: Int) -> String {
    let remainingCount: Int = totalCount - visibleCount
    let nextPageCount: Int = min(comparisonPageSize, remainingCount)
    return "Show \(nextPageCount) More \(nextPageCount == 1 ? "Change" : "Changes")"
}
