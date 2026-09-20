import Foundation
import Testing
@testable import SystemProfilerExplorer

struct SystemHighlightsTests {
    @Test
    func highlightsCorrelateOnlyCollectedFieldsFromOneReport() {
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [
                SystemProfilerSection(
                    dataType: .storage,
                    items: [.object([
                        "startup_disk": .string("Macintosh HD"),
                        "filevault_status": .string("On")
                    ])]
                ),
                SystemProfilerSection(
                    dataType: .network,
                    items: [.object([
                        "interface": .string("en0"),
                        "dns_servers": .string("1.1.1.1")
                    ])]
                ),
                SystemProfilerSection(
                    dataType: .configurationProfiles,
                    items: [.object(["profile_identifier": .string("example.profile")])]
                ),
                SystemProfilerSection(
                    dataType: .managedClient,
                    items: [.object(["is_managed": .boolean(true)])]
                ),
                SystemProfilerSection(
                    dataType: .power,
                    items: [.object([
                        "cycle_count": .integer(30),
                        "charger_connected": .string("yes")
                    ])]
                )
            ],
            commandArguments: ["SPStorageDataType", "SPNetworkDataType", "SPConfigurationProfileDataType", "SPManagedClientDataType", "SPPowerDataType", "-json"],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_001)
        )

        let highlights: [SystemHighlight] = systemHighlights(report)

        #expect(highlights.map(\.id) == [
            "startup-disk-security",
            "network-configuration",
            "profiles-management",
            "battery-power"
        ])
        #expect(highlights.allSatisfy { !$0.evidence.isEmpty })
    }
}
