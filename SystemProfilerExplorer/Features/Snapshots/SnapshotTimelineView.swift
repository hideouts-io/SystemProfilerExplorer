import SwiftUI

struct SnapshotTimelineView: View {
    let currentReport: SystemProfilerReport

    @Environment(\.dismiss) private var dismiss
    @AppStorage("snapshot-retention") private var storedRetention: String = SnapshotRetention.ten.rawValue
    @State private var snapshots: [SystemProfilerSnapshot] = []
    @State private var snapshotName: String = ""
    @State private var selectedPrivacy: SnapshotPrivacy = .full
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var snapshotErrorMessage: String?
    @State private var snapshotPendingDeletion: SystemProfilerSnapshot?
    @State private var comparison: ReportComparison?

    var body: some View {
        VStack(spacing: 0) {
            SnapshotTimelineHeader()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SnapshotSaveCard(
                        snapshotName: $snapshotName,
                        selectedPrivacy: $selectedPrivacy,
                        retention: retentionBinding,
                        isSaving: isSaving,
                        save: saveSnapshot
                    )

                    SnapshotPrivacyWarning()

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading local snapshots…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                    } else if snapshots.isEmpty {
                        SnapshotEmptyState()
                    } else {
                        SnapshotHistoryList(
                            snapshots: snapshots,
                            compare: compareSnapshot,
                            requestDeletion: requestDeletion
                        )
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text("Snapshots stay on this Mac in Application Support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: dismiss.callAsFunction)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 700, minHeight: 640)
        .task {
            await reloadSnapshots()
        }
        .sheet(item: $comparison) { reportComparison in
            ReportComparisonView(comparison: reportComparison)
        }
        .confirmationDialog(
            "Delete snapshot?",
            isPresented: deletionConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePendingSnapshot)
        } message: {
            Text("This removes the selected local snapshot. This action cannot be undone.")
        }
        .alert("Snapshot Error", isPresented: snapshotErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(snapshotErrorMessage ?? "The snapshot operation could not be completed.")
        }
        .accessibilityIdentifier("snapshot-timeline")
    }

    private var retention: SnapshotRetention {
        guard let retention = SnapshotRetention(rawValue: storedRetention) else {
            preconditionFailure("The stored snapshot retention preference is invalid.")
        }

        return retention
    }

    private var retentionBinding: Binding<SnapshotRetention> {
        Binding(
            get: { retention },
            set: { storedRetention = $0.rawValue }
        )
    }

    private var snapshotErrorBinding: Binding<Bool> {
        Binding(
            get: { snapshotErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    snapshotErrorMessage = nil
                }
            }
        )
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { snapshotPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    snapshotPendingDeletion = nil
                }
            }
        )
    }

    private func reloadSnapshots() async {
        isLoading = true

        do {
            let loadedSnapshots: [SystemProfilerSnapshot] = try await Task.detached(priority: .userInitiated) {
                let store: SnapshotStore = try snapshotStore()
                return try store.loadSnapshots()
            }.value
            snapshots = loadedSnapshots
        } catch is CancellationError {
            return
        } catch {
            snapshotErrorMessage = "The local snapshot history could not be loaded. \(String(reflecting: error))"
        }

        isLoading = false
    }

    private func saveSnapshot() {
        let name: String = snapshotName
        let privacy: SnapshotPrivacy = selectedPrivacy
        let report: SystemProfilerReport = currentReport
        let selectedRetention: SnapshotRetention = retention

        isSaving = true

        Task {
            do {
                let updatedSnapshots: [SystemProfilerSnapshot] = try await Task.detached(priority: .userInitiated) {
                    let store: SnapshotStore = try snapshotStore()
                    _ = try store.saveSnapshot(
                        name: name,
                        privacy: privacy,
                        report: report,
                        retention: selectedRetention
                    )
                    return try store.loadSnapshots()
                }.value
                snapshots = updatedSnapshots
                snapshotName = ""
            } catch is CancellationError {
                isSaving = false
                return
            } catch {
                snapshotErrorMessage = "The snapshot could not be saved. \(String(reflecting: error))"
            }

            isSaving = false
        }
    }

    private func compareSnapshot(_ snapshot: SystemProfilerSnapshot) {
        let current: SystemProfilerReport = currentReport

        Task {
            do {
                let preparedComparison: ReportComparison = try await Task.detached(priority: .userInitiated) {
                    let baseline: SystemProfilerReport = try comparisonBaselineReport(from: snapshot.report)
                    return try compareReports(baseline: baseline, current: current)
                }.value
                comparison = preparedComparison
            } catch is CancellationError {
                return
            } catch {
                snapshotErrorMessage = "The snapshot could not be compared. \(String(reflecting: error))"
            }
        }
    }

    private func requestDeletion(_ snapshot: SystemProfilerSnapshot) {
        snapshotPendingDeletion = snapshot
    }

    private func deletePendingSnapshot() {
        guard let snapshot = snapshotPendingDeletion else {
            return
        }

        snapshotPendingDeletion = nil

        Task {
            do {
                let updatedSnapshots: [SystemProfilerSnapshot] = try await Task.detached(priority: .userInitiated) {
                    let store: SnapshotStore = try snapshotStore()
                    try store.deleteSnapshot(snapshot)
                    return try store.loadSnapshots()
                }.value
                snapshots = updatedSnapshots
            } catch is CancellationError {
                return
            } catch {
                snapshotErrorMessage = "The snapshot could not be deleted. \(String(reflecting: error))"
            }
        }
    }
}

private struct SnapshotTimelineHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text("Snapshot History")
                    .font(.title2.weight(.semibold))
                Text("Save private local baselines and compare a full snapshot with the report currently open.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }
}

private struct SnapshotSaveCard: View {
    @Binding var snapshotName: String
    @Binding var selectedPrivacy: SnapshotPrivacy
    @Binding var retention: SnapshotRetention
    let isSaving: Bool
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Create a baseline", systemImage: "plus.circle")
                .font(.headline)

            TextField("Snapshot name (for example, Before macOS update)", text: $snapshotName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("snapshot-name")

            Picker("Stored values", selection: $selectedPrivacy) {
                ForEach(SnapshotPrivacy.allCases) { privacy in
                    Text(privacy.title).tag(privacy)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedPrivacy.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Picker("Retention", selection: $retention) {
                    ForEach(SnapshotRetention.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .frame(width: 180)

                Spacer()

                Button(action: save) {
                    Label(isSaving ? "Saving…" : "Save Snapshot", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
                .accessibilityIdentifier("save-snapshot")
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct SnapshotPrivacyWarning: View {
    var body: some View {
        Label(
            "Full snapshots preserve all collected values and diagnostics. Keep them private. Redacted snapshots are useful for inventory history but cannot establish value changes in a comparison.",
            systemImage: "hand.raised"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SnapshotEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("No snapshots yet")
                .font(.headline)
            Text("Save a named baseline to compare future scans with this report.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

private struct SnapshotHistoryList: View {
    let snapshots: [SystemProfilerSnapshot]
    let compare: (SystemProfilerSnapshot) -> Void
    let requestDeletion: (SystemProfilerSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Timeline", systemImage: "timeline.selection")
                .font(.headline)

            ForEach(snapshots) { snapshot in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: snapshot.privacy == .full ? "lock.doc" : "eye.slash")
                        .foregroundStyle(snapshot.privacy == .full ? .orange : .secondary)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.name)
                            .font(.body.weight(.semibold))
                        Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(snapshot.privacy.title)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())

                    Button("Compare") {
                        compare(snapshot)
                    }
                    .disabled(snapshot.privacy != .full)
                    .accessibilityIdentifier("compare-snapshot-\(snapshot.id.uuidString)")

                    Button(role: .destructive) {
                        requestDeletion(snapshot)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete \(snapshot.name)")
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }
}
