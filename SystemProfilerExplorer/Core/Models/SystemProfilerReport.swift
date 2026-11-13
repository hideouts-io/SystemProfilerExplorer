import Foundation

struct SystemProfilerSection: Identifiable, Sendable, Equatable, Codable {
    let dataType: SystemProfilerDataType
    let items: [ProfileValue]

    var id: String { dataType.rawValue }
}

struct SystemProfilerReport: Sendable, Equatable {
    let sections: [SystemProfilerSection]
    let commandArguments: [String]
    let standardError: String
    let startedAt: Date
    let completedAt: Date
    /// Session-only input capture. Stored reports and snapshots contain only the
    /// structured fields; source identity is independent of semantic equality.
    let originalSource: OriginalReportSource?

    init(
        sections: [SystemProfilerSection],
        commandArguments: [String],
        standardError: String,
        startedAt: Date,
        completedAt: Date
    ) {
        self.init(
            sections: sections,
            commandArguments: commandArguments,
            standardError: standardError,
            startedAt: startedAt,
            completedAt: completedAt,
            originalSource: nil
        )
    }

    init(
        sections: [SystemProfilerSection],
        commandArguments: [String],
        standardError: String,
        startedAt: Date,
        completedAt: Date,
        originalSource: OriginalReportSource?
    ) {
        self.sections = sections
        self.commandArguments = commandArguments
        self.standardError = standardError
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.originalSource = originalSource
    }

    static func == (lhs: SystemProfilerReport, rhs: SystemProfilerReport) -> Bool {
        lhs.sections == rhs.sections
            && lhs.commandArguments == rhs.commandArguments
            && lhs.standardError == rhs.standardError
            && lhs.startedAt == rhs.startedAt
            && lhs.completedAt == rhs.completedAt
    }
}
