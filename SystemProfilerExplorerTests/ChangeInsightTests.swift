import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ChangeInsightTests {
    @Test
    func securityConfigurationChangesAreRankedForFirstReview() {
        let change: ReportChange = ReportChange(
            kind: .changed,
            dataType: .configurationProfiles,
            recordIdentifier: "name:Example#0",
            recordLabel: "Example",
            catalogPath: ["profile_identifier"],
            sourcePath: "SPConfigurationProfileDataType.profile_identifier",
            baselineAddress: ProfileValueAddress(dataType: .configurationProfiles, path: [.index(0), .field("profile_identifier")]),
            currentAddress: ProfileValueAddress(dataType: .configurationProfiles, path: [.index(0), .field("profile_identifier")]),
            previousValue: .string("old.example"),
            currentValue: .string("new.example")
        )

        let insight: ReportChangeInsight = reportChangeInsight(change)

        #expect(insight.importance == .reviewFirst)
        #expect(insight.explanation.contains("changed from"))
        #expect(!insight.explanation.localizedCaseInsensitiveContains("compromise"))
    }

    @Test
    func hardwareInventoryChangesRemainInformational() {
        let change: ReportChange = ReportChange(
            kind: .added,
            dataType: .applications,
            recordIdentifier: "name:Example App#0",
            recordLabel: "Example App",
            catalogPath: ["version"],
            sourcePath: "SPApplicationsDataType.version",
            baselineAddress: nil,
            currentAddress: ProfileValueAddress(dataType: .applications, path: [.index(0), .field("version")]),
            previousValue: nil,
            currentValue: .string("1.0")
        )

        #expect(changeImportance(change) == .informational)
    }
}
