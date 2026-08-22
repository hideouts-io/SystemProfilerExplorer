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
}
