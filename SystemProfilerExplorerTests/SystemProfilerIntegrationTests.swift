import Foundation
import Testing
@testable import SystemProfilerExplorer

struct SystemProfilerIntegrationTests {
    @Test
    func collectsAndParsesHardwareFromInstalledSystemProfiler() async throws {
        let collector = SystemProfilerCollector(
            executableURL: URL(fileURLWithPath: "/usr/sbin/system_profiler")
        )
        let request = SystemProfilerRequest(
            dataTypes: [.hardware],
            detailLevel: .mini,
            timeoutSeconds: 30
        )

        let execution: SystemProfilerExecution = try await collector.collect(request)
        let report: SystemProfilerReport = try SystemProfilerParser().parse(execution)

        #expect(report.sections.count == 1)
        #expect(report.sections[0].dataType == .hardware)
        #expect(!report.sections[0].items.isEmpty)
        #expect(report.completedAt >= report.startedAt)
    }

    @Test
    func collectsAndParsesStorageFromInstalledSystemProfiler() async throws {
        let collector = SystemProfilerCollector(
            executableURL: URL(fileURLWithPath: "/usr/sbin/system_profiler")
        )
        let request = SystemProfilerRequest(
            dataTypes: [.storage],
            detailLevel: .mini,
            timeoutSeconds: 30
        )

        let execution: SystemProfilerExecution = try await collector.collect(request)
        let report: SystemProfilerReport = try SystemProfilerParser().parse(execution)

        #expect(report.sections.count == 1)
        #expect(report.sections[0].dataType == .storage)
        #expect(!report.sections[0].items.isEmpty)
    }

    @Test
    func collectsAndParsesPowerFromInstalledSystemProfiler() async throws {
        let collector = SystemProfilerCollector(
            executableURL: URL(fileURLWithPath: "/usr/sbin/system_profiler")
        )
        let request = SystemProfilerRequest(
            dataTypes: [.power],
            detailLevel: .mini,
            timeoutSeconds: 30
        )

        let execution: SystemProfilerExecution = try await collector.collect(request)
        let report: SystemProfilerReport = try SystemProfilerParser().parse(execution)

        #expect(report.sections.count == 1)
        #expect(report.sections[0].dataType == .power)
        #expect(!report.sections[0].items.isEmpty)
    }

    @Test
    func rejectsRequestWithoutDataTypes() async throws {
        let collector = SystemProfilerCollector(
            executableURL: URL(fileURLWithPath: "/usr/sbin/system_profiler")
        )
        let request = SystemProfilerRequest(
            dataTypes: [],
            detailLevel: .mini,
            timeoutSeconds: 30
        )

        await #expect(throws: SystemProfilerRequestError.emptyDataTypes) {
            _ = try await collector.collect(request)
        }
    }

    @Test
    func terminatesAProcessThatExceedsTheCollectorDeadline() async throws {
        let process: Process = Process()
        let exitMonitor: ProcessExitMonitor = ProcessExitMonitor()
        let arguments: [String] = ["5"]

        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = arguments
        process.terminationHandler = { completedProcess in
            Task {
                await exitMonitor.record(status: completedProcess.terminationStatus)
            }
        }

        try process.run()

        await #expect(
            throws: SystemProfilerCollectorError.timedOut(
                timeoutSeconds: 1,
                arguments: arguments
            )
        ) {
            _ = try await exitMonitor.wait(
                process: process,
                timeoutSeconds: 1,
                arguments: arguments
            )
        }
    }
}
