import Foundation

enum SnapshotPrivacy: String, CaseIterable, Identifiable, Codable, Sendable {
    case full
    case redacted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "Full values"
        case .redacted: "Redacted values"
        }
    }

    var detail: String {
        switch self {
        case .full: "Stores the collected report locally so it can be compared later."
        case .redacted: "Replaces scalar values before storing; redacted snapshots cannot be compared."
        }
    }
}

enum SnapshotRetention: String, CaseIterable, Identifiable, Sendable {
    case five
    case ten
    case twentyFive
    case unlimited

    var id: String { rawValue }

    var title: String {
        switch self {
        case .five: "Keep 5"
        case .ten: "Keep 10"
        case .twentyFive: "Keep 25"
        case .unlimited: "Keep all"
        }
    }

    var maximumCount: Int? {
        switch self {
        case .five: 5
        case .ten: 10
        case .twentyFive: 25
        case .unlimited: nil
        }
    }
}

struct SystemProfilerSnapshot: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let privacy: SnapshotPrivacy
    let report: ReportExportEnvelope
}

enum SnapshotStoreError: LocalizedError, Equatable {
    case emptyName
    case invalidSnapshotFile

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Enter a name for the snapshot before saving it."
        case .invalidSnapshotFile:
            "A snapshot file had an unexpected name and could not be loaded safely."
        }
    }
}

struct SnapshotStore: Sendable {
    private let directoryURL: URL

    init(applicationSupportURL: URL) {
        directoryURL = applicationSupportURL
            .appendingPathComponent("com.netctl.SystemProfilerExplorer", isDirectory: true)
            .appendingPathComponent("Snapshots", isDirectory: true)
    }

    func loadSnapshots() throws -> [SystemProfilerSnapshot] {
        let fileManager: FileManager = .default
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let files: [URL] = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let snapshotURLs: [URL] = files.filter { $0.pathExtension == "systemprofiler-snapshot" }

        return try snapshotURLs
            .map(loadSnapshot)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func saveSnapshot(
        name: String,
        privacy: SnapshotPrivacy,
        report: SystemProfilerReport,
        retention: SnapshotRetention
    ) throws -> SystemProfilerSnapshot {
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SnapshotStoreError.emptyName
        }

        try ensureDirectoryExists()

        let export: ReportExportEnvelope
        switch privacy {
        case .full:
            export = makeFullReportExport(report)
        case .redacted:
            export = makeRedactedReportExport(report)
        }

        let snapshot: SystemProfilerSnapshot = SystemProfilerSnapshot(
            id: UUID(),
            name: trimmedName,
            createdAt: Date(),
            privacy: privacy,
            report: export
        )
        let snapshotURL: URL = snapshotURL(for: snapshot.id)
        let data: Data = try encodeSnapshot(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
        try enforceRetention(retention)
        return snapshot
    }

    func deleteSnapshot(_ snapshot: SystemProfilerSnapshot) throws {
        let snapshotURL: URL = snapshotURL(for: snapshot.id)
        let fileManager: FileManager = .default
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try fileManager.removeItem(at: snapshotURL)
    }

    func enforceRetention(_ retention: SnapshotRetention) throws {
        guard let maximumCount = retention.maximumCount else {
            return
        }

        let snapshots: [SystemProfilerSnapshot] = try loadSnapshots()
        let expiredSnapshots: ArraySlice<SystemProfilerSnapshot> = snapshots.dropFirst(maximumCount)
        for snapshot in expiredSnapshots {
            try deleteSnapshot(snapshot)
        }
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func snapshotURL(for identifier: UUID) -> URL {
        directoryURL
            .appendingPathComponent(identifier.uuidString, isDirectory: false)
            .appendingPathExtension("systemprofiler-snapshot")
    }

    private func loadSnapshot(_ url: URL) throws -> SystemProfilerSnapshot {
        guard UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil else {
            throw SnapshotStoreError.invalidSnapshotFile
        }

        let data: Data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try decodeSnapshot(data)
    }
}

func snapshotStore() throws -> SnapshotStore {
    let applicationSupportURL: URL = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    return SnapshotStore(applicationSupportURL: applicationSupportURL)
}

func encodeSnapshot(_ snapshot: SystemProfilerSnapshot) throws -> Data {
    let encoder: JSONEncoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(snapshot)
}

func decodeSnapshot(_ data: Data) throws -> SystemProfilerSnapshot {
    let decoder: JSONDecoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let snapshot: SystemProfilerSnapshot = try decoder.decode(SystemProfilerSnapshot.self, from: data)

    guard snapshot.report.formatIdentifier == reportExportFormatIdentifier else {
        throw ReportExportError.invalidFormat(identifier: snapshot.report.formatIdentifier)
    }

    guard snapshot.report.formatVersion == reportExportFormatVersion else {
        throw ReportExportError.unsupportedVersion(version: snapshot.report.formatVersion)
    }

    return snapshot
}
