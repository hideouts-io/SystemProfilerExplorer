import Foundation

enum AppWorkspace: Hashable, Identifiable, Sendable {
    case subject(ProfilerSubject)
    case changes

    var id: String {
        switch self {
        case let .subject(subject): "subject-\(subject.rawValue)"
        case .changes: "changes"
        }
    }

    var title: String {
        switch self {
        case let .subject(subject): subject.title
        case .changes: "What Changed?"
        }
    }

    var symbolName: String {
        switch self {
        case let .subject(subject): subject.symbolName
        case .changes: "arrow.left.arrow.right.square"
        }
    }
}
