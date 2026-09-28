import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ProfilerSubjectTests {
    @Test
    func subjectIdentifiersAreUnique() {
        let identifiers: [String] = ProfilerSubject.allCases.map(\.id)

        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test
    func everySubjectHasAReadOnlyScanConfiguration() {
        for subject in ProfilerSubject.allCases {
            #expect(scanConfiguration(for: subject) != nil)
        }
    }

    @Test
    func completeReportIncludesEveryDeclaredDataType() throws {
        let configuration = try #require(scanConfiguration(for: .reports))

        #expect(configuration.request.dataTypes == SystemProfilerDataType.allCases)
        #expect(configuration.request.detailLevel == .full)
        #expect(configuration.request.timeoutSeconds == 300)
    }

    @Test
    func collectorWaitsPastSystemProfilerTimeoutForPartialReports() {
        for subject in ProfilerSubject.allCases {
            guard let request = scanConfiguration(for: subject)?.request else {
                continue
            }

            #expect(request.arguments.contains(String(request.timeoutSeconds)))
            #expect(request.collectorDeadlineSeconds > request.timeoutSeconds)
        }
    }

    @Test
    func subjectConfigurationsContainExpectedCoreDataTypes() throws {
        let overview = try #require(scanConfiguration(for: .overview))
        let hardware = try #require(scanConfiguration(for: .hardware))
        let network = try #require(scanConfiguration(for: .network))
        let software = try #require(scanConfiguration(for: .software))
        let security = try #require(scanConfiguration(for: .security))
        let power = try #require(scanConfiguration(for: .power))

        #expect(overview.request.dataTypes.contains(.wifi))
        #expect(overview.request.dataTypes.contains(.bluetooth))
        #expect(hardware.request.dataTypes.contains(.usb))
        #expect(hardware.request.dataTypes.contains(.thunderbolt))
        #expect(network.request.dataTypes.contains(.wifi))
        #expect(network.request.dataTypes.contains(.ethernet))
        #expect(software.request.dataTypes.contains(.applications))
        #expect(software.request.dataTypes.contains(.installHistory))
        #expect(security.request.dataTypes.contains(.firewall))
        #expect(security.request.dataTypes.contains(.configurationProfiles))
        #expect(power.request.dataTypes == [.power])
    }

    @Test
    func scanStateReportsWhichSubjectItDescribes() {
        #expect(ScanState.idle.subject == nil)
        #expect(ScanState.running(subject: .network).subject == .network)
        #expect(ScanState.completed(subject: .power, date: Date()).subject == .power)
        #expect(ScanState.failed(subject: .storage, message: "x").subject == .storage)
    }

    @Test
    func profilerDataTypeIdentifiersAndTitlesAreUnique() {
        let identifiers: [String] = SystemProfilerDataType.allCases.map(\.rawValue)
        let titles: [String] = SystemProfilerDataType.allCases.map(\.title)

        #expect(Set(identifiers).count == identifiers.count)
        #expect(Set(titles).count == titles.count)
    }
}
