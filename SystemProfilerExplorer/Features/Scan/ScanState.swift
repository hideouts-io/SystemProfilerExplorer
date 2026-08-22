import Foundation

enum ScanState: Equatable {
    case idle
    case running(subject: ProfilerSubject)
    case importing(subject: ProfilerSubject)
    case completed(subject: ProfilerSubject, date: Date)
    case cancelled(subject: ProfilerSubject)
    case failed(subject: ProfilerSubject, message: String)

    var isRunning: Bool {
        switch self {
        case .running, .importing:
            true
        case .idle, .completed, .cancelled, .failed:
            false
        }
    }

    var statusTitle: String {
        switch self {
        case .idle: "Not scanned"
        case let .running(subject): "Scanning \(subject.title)"
        case let .importing(subject): "Importing \(subject.title)"
        case .completed: "Scan complete"
        case .cancelled: "Scan cancelled"
        case .failed: "Scan failed"
        }
    }

    var statusSymbolName: String {
        switch self {
        case .idle: "circle.dashed"
        case .running: "progress.indicator"
        case .importing: "square.and.arrow.down"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}
