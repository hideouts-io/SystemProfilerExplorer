import SwiftUI
import UniformTypeIdentifiers

private let recordPageSize: Int = 100
private let largeReportFindingThreshold: Int = 5_000
private let automaticExpansionFindingLimit: Int = 200

private func shouldAutomaticallyExpandResults(
    query: FindingQuery,
    matchCount: Int
) -> Bool {
    !query.normalizedText.isEmpty && matchCount <= automaticExpansionFindingLimit
}

struct ProfileReportView: View {
    let report: SystemProfilerReport

    @State private var searchText: String = ""
    @State private var selectedFilter: FindingFilter = .all
    @State private var isShowingExportReview: Bool = false
    @State private var isShowingComparisonImporter: Bool = false
    @State private var isPreparingComparison: Bool = false
    @State private var reportComparison: ReportComparison?
    @State private var comparisonErrorMessage: String?
    @State private var comparisonTask: Task<Void, Never>?

    var body: some View {
        let currentQuery: FindingQuery = query
        let summary: ReportSummary = reportSummary(report)
        let matchCount: Int = currentQuery.isActive
            ? matchingFindingCount(report, query: currentQuery)
            : summary.findingCount
        let automaticallyExpandResults: Bool = shouldAutomaticallyExpandResults(
            query: currentQuery,
            matchCount: matchCount
        )

        VStack(alignment: .leading, spacing: 16) {
            ReportSummaryStrip(summary: summary)

            if summary.findingCount >= largeReportFindingThreshold {
                LargeReportNotice()
            }

            FindingControls(searchText: $searchText, selectedFilter: $selectedFilter)

            HStack {
                Text("Export and comparison use the complete collected report.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isShowingComparisonImporter = true
                } label: {
                    HStack(spacing: 7) {
                        if isPreparingComparison {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.left.arrow.right")
                        }

                        Text(isPreparingComparison ? "Comparing…" : "Compare with Saved Report…")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isPreparingComparison)
                .accessibilityIdentifier("compare-report")

                Button {
                    isShowingExportReview = true
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("export-report")
            }

            if matchCount == 0 {
                NoMatchingFindingsView(clearQuery: clearQuery)
            } else {
                HStack {
                    Text(resultDescription(
                        matchCount: matchCount,
                        totalCount: summary.findingCount,
                        query: currentQuery
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(report.sections) { section in
                    ProfileSectionView(
                        section: section,
                        query: currentQuery,
                        automaticallyExpandResults: automaticallyExpandResults
                    )
                }
            }

            ScanProvenanceView(report: report)
        }
        .sheet(isPresented: $isShowingExportReview) {
            ReportExportReviewView(report: report)
        }
        .sheet(item: $reportComparison) { comparison in
            ReportComparisonView(comparison: comparison)
        }
        .fileImporter(
            isPresented: $isShowingComparisonImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importComparisonBaseline
        )
        .alert("Comparison Failed", isPresented: comparisonErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(comparisonErrorMessage ?? "The reports could not be compared.")
        }
    }

    private var query: FindingQuery {
        FindingQuery(text: searchText, filter: selectedFilter)
    }

    private var comparisonErrorBinding: Binding<Bool> {
        Binding(
            get: { comparisonErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    comparisonErrorMessage = nil
                }
            }
        )
    }

    private func importComparisonBaseline(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard urls.count == 1, let reportURL = urls.first else {
                comparisonErrorMessage = ReportComparisonError
                    .expectedSingleFile(count: urls.count)
                    .localizedDescription
                return
            }

            prepareComparison(reportURL: reportURL)

        case let .failure(error):
            let cocoaError: NSError = error as NSError

            if cocoaError.domain == NSCocoaErrorDomain,
               cocoaError.code == NSUserCancelledError {
                return
            }

            comparisonErrorMessage = "The report picker failed. \(String(reflecting: error))"
        }
    }

    private func prepareComparison(reportURL: URL) {
        let currentReport: SystemProfilerReport = report

        comparisonTask?.cancel()
        isPreparingComparison = true

        comparisonTask = Task {
            do {
                let comparison: ReportComparison = try await Task.detached(priority: .userInitiated) {
                    let data: Data = try Data(contentsOf: reportURL, options: .mappedIfSafe)
                    let export: ReportExportEnvelope = try decodeReportExport(data)
                    let baselineReport: SystemProfilerReport = try comparisonBaselineReport(from: export)
                    return try compareReports(baseline: baselineReport, current: currentReport)
                }.value

                try Task.checkCancellation()
                reportComparison = comparison
            } catch is CancellationError {
                isPreparingComparison = false
                comparisonTask = nil
                return
            } catch {
                comparisonErrorMessage = "The selected report could not be compared. \(String(reflecting: error))"
            }

            isPreparingComparison = false
            comparisonTask = nil
        }
    }

    private func resultDescription(
        matchCount: Int,
        totalCount: Int,
        query: FindingQuery
    ) -> String {
        if query.isActive {
            return "Showing \(matchCount) of \(totalCount) findings"
        }

        return "\(totalCount) findings"
    }

    private func clearQuery() {
        searchText = ""
        selectedFilter = .all
    }
}

private struct LargeReportNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("Large report mode")
                    .font(.subheadline.weight(.semibold))
                Text("Records are presented in pages of 100 to keep navigation responsive. Search and filters still evaluate the complete collected report, and every record remains available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("large-report-notice")
    }
}

private struct ReportSummaryStrip: View {
    let summary: ReportSummary

    var body: some View {
        HStack(spacing: 10) {
            SummaryCard(
                title: "Records",
                value: summary.recordCount,
                symbolName: "square.stack.3d.up",
                tint: .blue
            )
            SummaryCard(
                title: "Findings",
                value: summary.findingCount,
                symbolName: "list.bullet.rectangle",
                tint: .cyan
            )
            SummaryCard(
                title: "Explained",
                value: summary.explainedFindingCount,
                symbolName: "text.book.closed",
                tint: .green
            )
            SummaryCard(
                title: "Privacy",
                value: summary.privacyFindingCount,
                symbolName: "eye.slash",
                tint: .orange
            )
        }
        .accessibilityIdentifier("report-summary")
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Int
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))

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
                .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
        }
    }
}

private struct FindingControls: View {
    @Binding var searchText: String
    @Binding var selectedFilter: FindingFilter

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search values and explanations", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("finding-search")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .accessibilityIdentifier("clear-finding-search")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }

            Picker("Finding filter", selection: $selectedFilter) {
                ForEach(FindingFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbolName)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 330)
            .accessibilityIdentifier("finding-filter")
        }
    }
}

private struct NoMatchingFindingsView: View {
    let clearQuery: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("No matching findings")
                .font(.headline)
            Text("Try a different term or show all finding types.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Clear Search and Filters", action: clearQuery)
                .accessibilityIdentifier("clear-finding-query")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ProfileSectionView: View {
    let section: SystemProfilerSection
    let query: FindingQuery
    let automaticallyExpandResults: Bool

    @State private var visibleRecordLimit: Int = recordPageSize

    var body: some View {
        let selection: MatchingRecordSelection = matchingRecordSelection(
            items: section.items,
            dataType: section.dataType,
            query: query,
            visibleLimit: visibleRecordLimit
        )
        let visibleRecords: [ProfileRecord] = profileRecords(selection)

        if selection.matchingCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(dataTypeTitle(section.dataType))
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(recordDescription(selection: selection))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: 0) {
                    ForEach(visibleRecords) { record in
                        ProfileValueDisclosure(
                            label: record.value.preferredName ?? "Record \(record.index + 1)",
                            value: record.value,
                            depth: 0,
                            dataType: section.dataType,
                            path: [],
                            query: query,
                            automaticallyExpandResults: automaticallyExpandResults
                        )

                        if record.id != visibleRecords.last?.id {
                            Divider()
                        }
                    }

                    if visibleRecords.count < selection.matchingCount {
                        Divider()
                        Button {
                            visibleRecordLimit += recordPageSize
                        } label: {
                            Label(
                                showMoreTitle(selection: selection),
                                systemImage: "chevron.down.circle"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityIdentifier("show-more-records-\(section.dataType.rawValue)")
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                }
            }
            .onChange(of: query) { _ in
                visibleRecordLimit = recordPageSize
            }
        }
    }

    private func profileRecords(_ selection: MatchingRecordSelection) -> [ProfileRecord] {
        selection.visibleIndices.map { index in
            ProfileRecord(index: index, value: section.items[index])
        }
    }

    private func recordDescription(selection: MatchingRecordSelection) -> String {
        if selection.visibleIndices.count == selection.matchingCount {
            let count: Int = selection.matchingCount
            return "\(count) \(count == 1 ? "record" : "records")"
        }

        return "Showing \(selection.visibleIndices.count) of \(selection.matchingCount) records"
    }

    private func showMoreTitle(selection: MatchingRecordSelection) -> String {
        let remainingCount: Int = selection.matchingCount - selection.visibleIndices.count
        let nextPageCount: Int = min(recordPageSize, remainingCount)
        return "Show \(nextPageCount) More \(nextPageCount == 1 ? "Record" : "Records")"
    }
}

private struct ProfileValueDisclosure: View {
    let label: String
    let value: ProfileValue
    let depth: Int
    let dataType: SystemProfilerDataType
    let path: [String]
    let query: FindingQuery
    let automaticallyExpandResults: Bool

    @State private var isManuallyExpanded: Bool = false

    var body: some View {
        switch value {
        case let .object(object):
            let fields: [ProfileField] = filteredObjectFields(object)
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(spacing: 0) {
                    ForEach(fields) { field in
                        ProfileFieldRow(
                            label: displayName(for: field.key),
                            value: field.value,
                            depth: depth + 1,
                            dataType: dataType,
                            path: path + [field.key],
                            query: descendantQuery,
                            automaticallyExpandResults: automaticallyExpandResults
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                ProfileGroupLabel(label: label, count: fields.count, depth: depth)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

        case let .array(values):
            let items: [ProfileArrayItem] = filteredArrayItems(values)
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ProfileFieldRow(
                            label: item.value.preferredName ?? "Item \(item.index + 1)",
                            value: item.value,
                            depth: depth + 1,
                            dataType: dataType,
                            path: path + ["[]"],
                            query: descendantQuery,
                            automaticallyExpandResults: automaticallyExpandResults
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                ProfileGroupLabel(label: label, count: items.count, depth: depth)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

        case let .string(value):
            ScalarProfileRow(
                presentation: fieldPresentation(dataType: dataType, path: path, scalar: .string(value)),
                depth: depth
            )
        case let .integer(value):
            ScalarProfileRow(
                presentation: fieldPresentation(dataType: dataType, path: path, scalar: .integer(value)),
                depth: depth
            )
        case let .decimal(value):
            ScalarProfileRow(
                presentation: fieldPresentation(dataType: dataType, path: path, scalar: .decimal(value)),
                depth: depth
            )
        case let .boolean(value):
            ScalarProfileRow(
                presentation: fieldPresentation(dataType: dataType, path: path, scalar: .boolean(value)),
                depth: depth
            )
        case .null:
            ScalarProfileRow(
                presentation: fieldPresentation(dataType: dataType, path: path, scalar: .null),
                depth: depth
            )
        }
    }

    private var descendantQuery: FindingQuery {
        queryForDescendants(parentLabel: label, query: query)
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { automaticallyExpandResults || isManuallyExpanded },
            set: { isManuallyExpanded = $0 }
        )
    }

    private func filteredObjectFields(_ object: [String: ProfileValue]) -> [ProfileField] {
        let fields: [ProfileField] = visibleObjectFields(object)

        guard descendantQuery.isActive else {
            return fields
        }

        return fields.filter { field in
            profileValueMatches(
                field.value,
                label: displayName(for: field.key),
                dataType: dataType,
                path: path + [field.key],
                query: descendantQuery
            )
        }
    }

    private func filteredArrayItems(_ values: [ProfileValue]) -> [ProfileArrayItem] {
        guard descendantQuery.isActive else {
            return values.enumerated().map { index, value in
                ProfileArrayItem(index: index, value: value)
            }
        }

        return values.enumerated().compactMap { index, value in
            let itemLabel: String = value.preferredName ?? "Item \(index + 1)"

            guard profileValueMatches(
                value,
                label: itemLabel,
                dataType: dataType,
                path: path + ["[]"],
                query: descendantQuery
            ) else {
                return nil
            }

            return ProfileArrayItem(index: index, value: value)
        }
    }
}

private struct ProfileFieldRow: View {
    let label: String
    let value: ProfileValue
    let depth: Int
    let dataType: SystemProfilerDataType
    let path: [String]
    let query: FindingQuery
    let automaticallyExpandResults: Bool

    var body: some View {
        ProfileValueDisclosure(
            label: label,
            value: value,
            depth: depth,
            dataType: dataType,
            path: path,
            query: query,
            automaticallyExpandResults: automaticallyExpandResults
        )

        if shouldShowDivider(after: value) {
            Divider()
                .padding(.leading, CGFloat(depth * 14))
        }
    }
}

private struct ProfileGroupLabel: View {
    let label: String
    let count: Int
    let depth: Int

    var body: some View {
        HStack {
            Text(label)
                .font(depth == 0 ? .headline : .subheadline.weight(.medium))
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
    }
}

private struct ScalarProfileRow: View {
    let presentation: FieldPresentation
    let depth: Int

    var body: some View {
        DisclosureGroup {
            if let explanation = presentation.explanation {
                FieldExplanationView(presentation: presentation, explanation: explanation)
            } else {
                MissingExplanationView(presentation: presentation)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(presentation.title)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 280, alignment: .leading)
                Spacer(minLength: 12)
                Text(presentation.displayedValue)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.leading, CGFloat(depth * 14))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityIdentifier("finding-\(presentation.sourcePath)")
    }
}

private struct FieldExplanationView: View {
    let presentation: FieldPresentation
    let explanation: FieldExplanation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExplanationSection(
                title: "What it means",
                symbolName: "text.book.closed",
                text: explanation.meaning
            )
            ExplanationSection(
                title: "Why it matters",
                symbolName: "scope",
                text: explanation.significance
            )
            ExplanationSection(
                title: "Interpret carefully",
                symbolName: "exclamationmark.bubble",
                text: explanation.interpretation
            )

            if let privacy = explanation.privacy {
                ExplanationSection(
                    title: "Privacy",
                    symbolName: "eye.slash",
                    text: privacy
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                LabeledContent("Source field", value: presentation.sourcePath)

                if presentation.displayedValue != presentation.rawValue {
                    LabeledContent("Raw value", value: presentation.rawValue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        .padding(.top, 8)
    }
}

private struct ExplanationSection: View {
    let title: String
    let symbolName: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct MissingExplanationView: View {
    let presentation: FieldPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No curated explanation yet", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
            Text("The value is preserved exactly as system_profiler reported it. The app does not infer a meaning for an unrecognized field.")
                .font(.callout)
                .foregroundStyle(.secondary)
            LabeledContent("Source field", value: presentation.sourcePath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
        .padding(.top, 8)
    }
}

private struct ScanProvenanceView: View {
    let report: SystemProfilerReport

    var body: some View {
        DisclosureGroup("Collection details") {
            VStack(alignment: .leading, spacing: 8) {
                if report.commandArguments.isEmpty {
                    LabeledContent("Source", value: "Imported system_profiler JSON")
                    LabeledContent("Imported", value: report.completedAt.formatted(date: .abbreviated, time: .standard))
                } else {
                    LabeledContent("Command", value: "/usr/sbin/system_profiler \(report.commandArguments.joined(separator: " "))")
                    LabeledContent("Started", value: report.startedAt.formatted(date: .abbreviated, time: .standard))
                    LabeledContent("Duration", value: durationDescription(report))
                }

                if !report.standardError.isEmpty {
                    LabeledContent("Standard error", value: report.standardError)
                }
            }
            .font(.caption)
            .textSelection(.enabled)
            .padding(.top, 8)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProfileField: Identifiable {
    let key: String
    let value: ProfileValue

    var id: String { key }
}

private struct ProfileRecord: Identifiable {
    let index: Int
    let value: ProfileValue

    var id: Int { index }
}

private struct ProfileArrayItem: Identifiable {
    let index: Int
    let value: ProfileValue

    var id: Int { index }
}

private func visibleObjectFields(_ object: [String: ProfileValue]) -> [ProfileField] {
    object
        .filter { $0.key != "_name" }
        .map { ProfileField(key: $0.key, value: $0.value) }
        .sorted {
            displayName(for: $0.key).localizedStandardCompare(displayName(for: $1.key)) == .orderedAscending
        }
}

private func dataTypeTitle(_ dataType: SystemProfilerDataType) -> String {
    dataType.title
}

private func durationDescription(_ report: SystemProfilerReport) -> String {
    let duration: TimeInterval = report.completedAt.timeIntervalSince(report.startedAt)
    return duration.formatted(.number.precision(.fractionLength(2))) + " seconds"
}

private func shouldShowDivider(after value: ProfileValue) -> Bool {
    switch value {
    case .object, .array: false
    case .string, .integer, .decimal, .boolean, .null: true
    }
}
