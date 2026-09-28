import Testing
@testable import SystemProfilerExplorer

struct RecordNameTests {
    @Test
    func knownInternalRecordNamesBecomeReadable() {
        #expect(friendlyReportGroupName("sppower_ac_charger_information") == "Power Adapter")
        #expect(friendlyReportGroupName("spfirewall_settings") == "Firewall Settings")
        #expect(friendlyReportGroupName("os_overview") == "macOS")
        #expect(friendlyReportGroupName("thunderboltusb4_bus_2") == "Thunderbolt/USB4 Bus 2")
        #expect(friendlyReportGroupName("kernel_log_description") == "Kernel Log")
        #expect(friendlyReportGroupName("power_management_log_description") == "Power Management Log")
    }

    @Test
    func realNamesWithUnderscoresStayAsReported() {
        #expect(friendlyReportGroupName("webdav_fs") == "webdav_fs")
        #expect(friendlyReportGroupName("apfs_boot_mount") == "apfs_boot_mount")
        #expect(friendlyReportGroupName("Macintosh HD") == "Macintosh HD")
    }

    @Test
    func searchMatchesFriendlyRecordNames() throws {
        let report = SystemProfilerReport(
            sections: [
                SystemProfilerSection(dataType: .power, items: [
                    .object(["_name": .string("sppower_ac_charger_information"), "sppower_ac_charger_watts": .string("96")])
                ])
            ],
            commandArguments: [],
            standardError: "",
            startedAt: .now,
            completedAt: .now
        )
        let query = FindingQuery(text: "Power Adapter", filter: .all)
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)

        #expect(try index.queryResult(for: query).findingCount == 1)
        #expect(matchingFindingCount(report, query: query) == 1)
    }

    @Test
    func worthReviewingCountsAreKeptPerRecord() throws {
        let lowBattery: ProfileValue = .object([
            "sppower_battery_charge_info": .object([
                "sppower_battery_state_of_charge": .integer(4),
                "sppower_battery_is_charging": .string("FALSE")
            ])
        ])
        let report = SystemProfilerReport(
            sections: [
                SystemProfilerSection(dataType: .power, items: [
                    .object(["_name": .string("sppower_information")]),
                    lowBattery
                ])
            ],
            commandArguments: [],
            standardError: "",
            startedAt: .now,
            completedAt: .now
        )
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)

        #expect(index.worthReviewingCountsByRecord(for: .power) == [1: 1])
        #expect(index.worthReviewingCountsByRecord(for: .storage).isEmpty)
    }
}
