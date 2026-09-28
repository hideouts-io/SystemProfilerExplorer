import SwiftUI

struct SnapshotTimelineView: View {
    let currentReport: SystemProfilerReport

    @Environment(\.dismiss) private var dismiss
    @AppStorage("snapshot-retention") private var storedRetention: String = SnapshotRetention.ten.rawValue
    @State private var snapshots: [SystemProfilerSnapshot] = []
    @State private var unreadableSnapshotFileNames: [String] = []
    @State private var snapshotName: String = ""
    @State private var selectedPrivacy: SnapshotPrivacy = .full
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var snapshotErrorMessage: String?
    @State private var snapshotPendingDeletion: SystemProfilerSnapshot?

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

                    if !unreadableSnapshotFileNames.isEmpty {
                        UnreadableSnapshotsNotice(fileNames: unreadableSnapshotFileNames)
                    }

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
                            requestDeletion: requestDeletion
                        )
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text("Snapshots stay on this Mac. To compare, open What Changed and pick a snapshot.")
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

    /// Falls back to the default if the stored preference is missing or from another version.
    private var retention: SnapshotRetention {
        SnapshotRetention(rawValue: storedRetention) ?? .ten
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
            let history: SnapshotHistory = try await Task.detached(priority: .userInitiated) {
                let store: SnapshotStore = try snapshotStore()
                return try store.loadSnapshotHistory()
            }.value
            applySnapshotHistory(history)
        } catch is CancellationError {
            return
        } catch {
            snapshotErrorMessage = "The local snapshot history could not be loaded. \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func applySnapshotHistory(_ history: SnapshotHistory) {
        snapshots = history.snapshots
        unreadableSnapshotFileNames = history.unreadableFileNames
    }

    private func saveSnapshot() {
        let name: String = snapshotName
        let privacy: SnapshotPrivacy = selectedPrivacy
        let report: SystemProfilerReport = currentReport
        let selectedRetention: SnapshotRetention = retention

        isSaving = true

        Task {
            do {
                let history: SnapshotHistory = try await Task.detached(priority: .userInitiated) {
                    let store: SnapshotStore = try snapshotStore()
                    _ = try store.saveSnapshot(
                        name: name,
                        privacy: privacy,
                        report: report,
                        retention: selectedRetention
                    )
                    return try store.loadSnapshotHistory()
                }.value
                applySnapshotHistory(history)
                snapshotName = ""
            } catch is CancellationError {
                isSaving = false
                return
            } catch {
                snapshotErrorMessage = "The snapshot could not be saved. \(error.localizedDescription)"
            }

            isSaving = false
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
                let history: SnapshotHistory = try await Task.detached(priority: .userInitiated) {
                    let store: SnapshotStore = try snapshotStore()
                    try store.deleteSnapshot(snapshot)
                    return try store.loadSnapshotHistory()
                }.value
                applySnapshotHistory(history)
            } catch is CancellationError {
                return
            } catch {
                snapshotErrorMessage = "The snapshot could not be deleted. \(error.localizedDescription)"
            }
        }
    }
}

private struct UnreadableSnapshotsNotice: View {
    let fileNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                "\(fileNames.count) snapshot \(fileNames.count == 1 ? "file" : "files") could not be read and \(fileNames.count == 1 ? "was" : "were") skipped",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            Text("The files may be damaged or saved by a different version of the app. They are left untouched in Application Support: \(fileNames.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("unreadable-snapshots")
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
                Text("Save this report as a private baseline. Compare it with later scans in What Changed.")
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
