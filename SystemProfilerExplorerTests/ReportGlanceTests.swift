import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ReportGlanceTests {
    @Test
    func glanceDescribesCollectedValuesInPlainLanguage() {
        let glance: [String] = reportGlance(glanceReport())

        #expect(glance == [
            "This MacBook Pro has an Apple M3 Max chip with 14 CPU cores (10 performance and 4 efficiency) and 36 GB of memory.",
            "This Mac runs macOS 27.0 (26A428) with System Integrity Protection on, and has been running for 1 hour 17 minutes since the last restart.",
            "The startup disk has 90 GB free of 1 TB (9%), which is low, and its drive reports no problems.",
            "The battery was at 4% and not charging when scanned. Its condition is Good after 16 charge cycles, with 100% of its original capacity.",
            "Wi-Fi is connected using Wi-Fi 6 (802.11ax) on the 5 GHz band, with an excellent signal.",
            "2 network services are set up, including 1 VPN.",
            "Bluetooth is on, with 1 device connected and 2 more paired but not connected.",
            "The firewall is on, with stealth mode on."
        ])
    }

    @Test
    func glanceOmitsDataThatWasNotCollected() {
        let report = SystemProfilerReport(
            sections: [
                SystemProfilerSection(dataType: .firewall, items: [
                    .object(["spfirewall_globalstate": .string("spfirewall_globalstate_off")])
                ])
            ],
            commandArguments: [],
            standardError: "",
            startedAt: Date(),
            completedAt: Date()
        )

        #expect(reportGlance(report) == ["The firewall is off."])
    }

    @Test
    func bluetoothWithOnlyPairedDevicesReadsNaturally() {
        let report = SystemProfilerReport(
            sections: [
                SystemProfilerSection(dataType: .bluetooth, items: [
                    .object([
                        "controller_properties": .object(["controller_state": .string("attrib_on")]),
                        "device_not_connected": .array([.object(["Device": .object([:])])])
                    ])
                ])
            ],
            commandArguments: [],
            standardError: "",
            startedAt: Date(),
            completedAt: Date()
        )

        #expect(reportGlance(report) == ["Bluetooth is on, with 1 paired device not connected right now."])
    }
}

private func glanceReport() -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(dataType: .hardware, items: [
                .object([
                    "machine_name": .string("MacBook Pro"),
                    "chip_type": .string("Apple M3 Max"),
                    "number_processors": .string("proc 14:0:10:4"),
                    "physical_memory": .string("36 GB")
                ])
            ]),
            SystemProfilerSection(dataType: .software, items: [
                .object([
                    "os_version": .string("macOS 27.0 (26A428)"),
                    "system_integrity": .string("integrity_enabled"),
                    "uptime": .string("up 0:1:17:52")
                ])
            ]),
            SystemProfilerSection(dataType: .storage, items: [
                .object([
                    "mount_point": .string("/System/Volumes/Data"),
                    "free_space_in_bytes": .integer(90_000_000_000),
                    "size_in_bytes": .integer(1_000_000_000_000),
                    "physical_drive": .object(["smart_status": .string("Verified")])
                ])
            ]),
            SystemProfilerSection(dataType: .power, items: [
                .object([
                    "sppower_battery_charge_info": .object([
                        "sppower_battery_state_of_charge": .integer(4),
                        "sppower_battery_is_charging": .string("FALSE")
                    ]),
                    "sppower_battery_health_info": .object([
                        "sppower_battery_cycle_count": .integer(16),
                        "sppower_battery_health": .string("Good"),
                        "sppower_battery_health_maximum_capacity": .string("100%")
                    ])
                ])
            ]),
            SystemProfilerSection(dataType: .wifi, items: [
                .object([
                    "spairport_airport_interfaces": .array([
                        .object([
                            "spairport_status_information": .string("spairport_status_connected"),
                            "spairport_current_network_information": .object([
                                "spairport_network_phymode": .string("802.11ax"),
                                "spairport_network_channel": .string("36 (5GHz, 160MHz)"),
                                "spairport_signal_noise": .string("-45 dBm / -91 dBm")
                            ])
                        ])
                    ])
                ])
            ]),
            SystemProfilerSection(dataType: .network, items: [
                .object(["type": .string("Ethernet")]),
                .object(["type": .string("VPN (com.example.vpn)")])
            ]),
            SystemProfilerSection(dataType: .bluetooth, items: [
                .object([
                    "controller_properties": .object(["controller_state": .string("attrib_on")]),
                    "device_connected": .array([.object(["Mouse": .object([:])])]),
                    "device_not_connected": .array([
                        .object(["Headphones": .object([:])]),
                        .object(["Keyboard": .object([:])])
                    ])
                ])
            ]),
            SystemProfilerSection(dataType: .firewall, items: [
                .object([
                    "spfirewall_globalstate": .string("spfirewall_globalstate_limit_connections"),
                    "spfirewall_stealthenabled": .string("Yes")
                ])
            ])
        ],
        commandArguments: [],
        standardError: "",
        startedAt: Date(),
        completedAt: Date()
    )
}
