import Foundation

enum SystemProfilerDetailLevel: String, Sendable {
    case mini
    case basic
    case full
}

struct SystemProfilerRequest: Sendable, Equatable {
    let dataTypes: [SystemProfilerDataType]
    let detailLevel: SystemProfilerDetailLevel
    let timeoutSeconds: Int

    var arguments: [String] {
        [
            "-json",
            "-detailLevel",
            detailLevel.rawValue,
            "-timeout",
            String(timeoutSeconds)
        ] + dataTypes.map(\.rawValue)
    }

    /// system_profiler emits a partial report when its own -timeout expires, so the
    /// collector waits a little longer before terminating the process.
    var collectorDeadlineSeconds: Int {
        timeoutSeconds + systemProfilerDeadlineGraceSeconds
    }
}

let systemProfilerDeadlineGraceSeconds: Int = 30

enum SystemProfilerRequestError: LocalizedError, Equatable {
    case emptyDataTypes
    case invalidTimeout(seconds: Int)

    var errorDescription: String? {
        switch self {
        case .emptyDataTypes:
            "The system profiler request did not contain any data types."
        case let .invalidTimeout(seconds):
            "The system profiler timeout must be greater than zero; received \(seconds) seconds."
        }
    }
}

func validateSystemProfilerRequest(_ request: SystemProfilerRequest) throws {
    guard !request.dataTypes.isEmpty else {
        throw SystemProfilerRequestError.emptyDataTypes
    }

    guard request.timeoutSeconds > 0 else {
        throw SystemProfilerRequestError.invalidTimeout(seconds: request.timeoutSeconds)
    }
}
