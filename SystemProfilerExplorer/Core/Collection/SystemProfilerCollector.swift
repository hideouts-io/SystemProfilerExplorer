import Foundation

struct SystemProfilerExecution: Sendable, Equatable {
    let request: SystemProfilerRequest
    let standardOutput: Data
    let standardError: String
    let startedAt: Date
    let completedAt: Date
}

enum SystemProfilerCollectorError: LocalizedError, Equatable {
    case alreadyRunning
    case launchFailed(executable: String, arguments: [String], reason: String)
    case timedOut(timeoutSeconds: Int, arguments: [String])
    case unsuccessfulExit(status: Int32, standardError: String)
    case emptyOutput(arguments: [String])

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "A system profiler scan is already running. Cancel it or wait for it to finish before starting another scan."
        case let .launchFailed(executable, arguments, reason):
            "Could not launch \(executable) with arguments \(arguments.joined(separator: " ")). \(reason)"
        case let .timedOut(timeoutSeconds, arguments):
            "system_profiler did not exit within \(timeoutSeconds) seconds for arguments: \(arguments.joined(separator: " ")). The scan was terminated."
        case let .unsuccessfulExit(status, standardError):
            "system_profiler exited with status \(status). Standard error: \(standardError.isEmpty ? "No error details were produced." : standardError)"
        case let .emptyOutput(arguments):
            "system_profiler completed without returning JSON for arguments: \(arguments.joined(separator: " "))."
        }
    }
}

protocol SystemProfilerCollecting: Sendable {
    func collect(_ request: SystemProfilerRequest) async throws -> SystemProfilerExecution
    func cancel() async
}

actor SystemProfilerCollector: SystemProfilerCollecting {
    private let executableURL: URL
    private var runningProcess: Process?

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    func collect(_ request: SystemProfilerRequest) async throws -> SystemProfilerExecution {
        try validateSystemProfilerRequest(request)

        guard runningProcess == nil else {
            throw SystemProfilerCollectorError.alreadyRunning
        }

        try Task.checkCancellation()

        let process: Process = Process()
        let standardOutputPipe: Pipe = Pipe()
        let standardErrorPipe: Pipe = Pipe()
        let startedAt: Date = Date()

        process.executableURL = executableURL
        process.arguments = request.arguments
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe
        runningProcess = process

        let exitMonitor: ProcessExitMonitor = ProcessExitMonitor()
        process.terminationHandler = { completedProcess in
            Task {
                await exitMonitor.record(status: completedProcess.terminationStatus)
            }
        }

        defer {
            runningProcess = nil
        }

        do {
            try process.run()
        } catch {
            throw SystemProfilerCollectorError.launchFailed(
                executable: executableURL.path,
                arguments: request.arguments,
                reason: String(reflecting: error)
            )
        }

        let standardOutputTask: Task<Data, Never> = Task.detached(priority: .userInitiated) {
            standardOutputPipe.fileHandleForReading.readDataToEndOfFile()
        }
        let standardErrorTask: Task<Data, Never> = Task.detached(priority: .utility) {
            standardErrorPipe.fileHandleForReading.readDataToEndOfFile()
        }

        let status: Int32

        do {
            status = try await withTaskCancellationHandler {
                try await exitMonitor.wait(
                    process: process,
                    timeoutSeconds: request.timeoutSeconds,
                    arguments: request.arguments
                )
            } onCancel: {
                if process.isRunning {
                    process.terminate()
                }
                Task {
                    await exitMonitor.cancel()
                }
            }
        } catch {
            if process.isRunning {
                process.terminate()
            }
            standardOutputPipe.fileHandleForReading.closeFile()
            standardErrorPipe.fileHandleForReading.closeFile()
            throw error
        }

        process.terminationHandler = nil

        let standardOutput: Data = await standardOutputTask.value
        let standardErrorData: Data = await standardErrorTask.value
        let standardError: String = String(decoding: standardErrorData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        try Task.checkCancellation()

        guard status == 0 else {
            throw SystemProfilerCollectorError.unsuccessfulExit(
                status: status,
                standardError: standardError
            )
        }

        guard !standardOutput.isEmpty else {
            throw SystemProfilerCollectorError.emptyOutput(arguments: request.arguments)
        }

        return SystemProfilerExecution(
            request: request,
            standardOutput: standardOutput,
            standardError: standardError,
            startedAt: startedAt,
            completedAt: Date()
        )
    }

    func cancel() {
        guard let runningProcess, runningProcess.isRunning else {
            return
        }

        runningProcess.terminate()
    }
}

actor ProcessExitMonitor {
    private enum State {
        case waiting
        case completed(Int32)
        case failed(SystemProfilerCollectorError)
        case cancelled
    }

    private var state: State = .waiting
    private var continuation: CheckedContinuation<Int32, Error>?
    private var timeoutTask: Task<Void, Never>?

    func wait(
        process: Process,
        timeoutSeconds: Int,
        arguments: [String]
    ) async throws -> Int32 {
        switch state {
        case let .completed(status):
            return status
        case let .failed(error):
            throw error
        case .cancelled:
            throw CancellationError()
        case .waiting:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                timeoutTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(timeoutSeconds))
                    } catch {
                        return
                    }

                    expire(
                        process: process,
                        timeoutSeconds: timeoutSeconds,
                        arguments: arguments
                    )
                }
            }
        }
    }

    func record(status: Int32) {
        guard case .waiting = state else {
            return
        }

        state = .completed(status)
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(returning: status)
        continuation = nil
    }

    func cancel() {
        guard case .waiting = state else {
            return
        }

        state = .cancelled
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }

    private func expire(
        process: Process,
        timeoutSeconds: Int,
        arguments: [String]
    ) {
        guard case .waiting = state else {
            return
        }

        if process.isRunning {
            process.terminate()
        }

        let error: SystemProfilerCollectorError = .timedOut(
            timeoutSeconds: timeoutSeconds,
            arguments: arguments
        )
        state = .failed(error)
        continuation?.resume(throwing: error)
        continuation = nil
        timeoutTask = nil
    }
}
