import Foundation

enum AppWorkspace: Hashable, Identifiable, Sendable {
    case subject(ProfilerSubject)
    case highlights
    case changes

    var id: String {
        switch self {
        case let .subject(subject): "subject-\(subject.rawValue)"
        case .highlights: "highlights"
        case .changes: "changes"
        }
    }

    var title: String {
        switch self {
        case let .subject(subject): subject.title
        case .highlights: "Highlights"
        case .changes: "What Changed?"
        }
    }

    var symbolName: String {
        switch self {
        case let .subject(subject): subject.symbolName
        case .highlights: "point.3.connected.trianglepath.dotted"
        case .changes: "arrow.left.arrow.right.square"
        }
    }
}
