import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ValueExplanationTests {
    // MARK: - The nRF52 modem case

    @Test
    func usbSerialModemServiceIsExplainedAsLikelyDevBoard() throws {
        let explanation = try #require(valueExplanation(
            dataType: .network,
            path: ["hardware"],
            scalar: .string("Modem"),
            siblings: nrf52Service
        ))

        #expect(explanation.status == .informational)
        #expect(explanation.summary.contains("Nordic Semiconductor nRF52 board or dongle"))
        #expect(explanation.summary.contains("not a phone-line or cellular modem"))
        #expect(explanation.confidence?.reasons.count == 3)
        #expect(explanation.detail?.contains("Scan Hardware") == true)
    }

    @Test
    func modemServiceChecksTheUSBDeviceListWhenCollected() throws {
        let unplugged = try #require(valueExplanation(
            dataType: .network,
            path: ["hardware"],
            scalar: .string("Modem"),
            siblings: nrf52Service,
            report: ValueReportContext(usbDeviceNames: ["USB 3.1 Bus", "Magic Keyboard"])
        ))
        let pluggedIn = try #require(valueExplanation(
            dataType: .network,
            path: ["hardware"],
            scalar: .string("Modem"),
            siblings: nrf52Service,
            report: ValueReportContext(usbDeviceNames: ["USB 3.1 Bus", "nRF52 USB Product"])
        ))

        #expect(unplugged.detail?.contains("left over from an earlier connection") == true)
        #expect(pluggedIn.detail?.contains("is connected right now") == true)
    }

    @Test
    func modemServiceWithoutSerialCluesStaysGeneric() throws {
        let explanation = try #require(valueExplanation(
            dataType: .network,
            path: ["hardware"],
            scalar: .string("Modem"),
            siblings: ["_name": .string("External Modem"), "type": .string("PPP")]
        ))

        #expect(explanation.confidence == .observed)
        #expect(explanation.summary.contains("dial-up"))
    }

    // MARK: - Enumerations

    @Test
    func wifiSecurityModesAreRankedAndMisspelledPrefixesStillMatch() throws {
        let transition = try #require(wifiSecurityExplanation("pairport_security_mode_wpa3_transition", isCurrentNetwork: true))
        let openCurrent = try #require(wifiSecurityExplanation("spairport_security_mode_none", isCurrentNetwork: true))
        let openNearby = try #require(wifiSecurityExplanation("spairport_security_mode_none", isCurrentNetwork: false))

        #expect(transition.status == .normal)
        #expect(openCurrent.status == .worthReviewing)
        #expect(openNearby.status == .informational)
        #expect(wifiSecurityExplanation("spairport_security_mode_wpa2_personal", isCurrentNetwork: true)?.status == .normal)
        #expect(wifiSecurityExplanation("spairport_security_mode_wep", isCurrentNetwork: true)?.status == .worthReviewing)
    }

    @Test
    func firewallStatesAndPerAppRulesAreExplained() throws {
        let on = try #require(valueExplanation(
            dataType: .firewall,
            path: ["spfirewall_globalstate"],
            scalar: .string("spfirewall_globalstate_limit_connections")
        ))
        let off = try #require(valueExplanation(
            dataType: .firewall,
            path: ["spfirewall_globalstate"],
            scalar: .string("spfirewall_globalstate_off")
        ))
        let appRule = try #require(valueExplanation(
            dataType: .firewall,
            path: ["spfirewall_applications", "com.example.helper"],
            scalar: .string("spfirewall_block_all")
        ))

        #expect(on.status == .normal)
        #expect(off.status == .worthReviewing)
        #expect(off.suggestedAction?.contains("System Settings") == true)
        #expect(appRule.summary == "Incoming connections to this app are blocked.")
    }

    @Test
    func securityStatesUseTheirTokenSuffix() {
        #expect(valueExplanation(dataType: .software, path: ["system_integrity"], scalar: .string("integrity_enabled"))?.status == .normal)
        #expect(valueExplanation(dataType: .software, path: ["system_integrity"], scalar: .string("integrity_disabled"))?.status == .worthReviewing)
        #expect(valueExplanation(dataType: .software, path: ["secure_vm"], scalar: .string("secure_vm_enabled"))?.status == .normal)
        #expect(valueExplanation(dataType: .hardware, path: ["activation_lock_status"], scalar: .string("activation_lock_disabled"))?.status == .informational)
    }

    @Test
    func booleanLikeSpellingsDecode() {
        #expect(decodeBooleanLike("attrib_on") == true)
        #expect(decodeBooleanLike("attrib_off") == false)
        #expect(decodeBooleanLike("spaudio_yes") == true)
        #expect(decodeBooleanLike("value_no") == false)
        #expect(decodeBooleanLike("TRUE") == true)
        #expect(decodeBooleanLike("spairport_caps_supported") == true)
        #expect(decodeBooleanLike("Not Supported") == false)
        #expect(decodeBooleanLike("normal_boot") == nil)
    }

    // MARK: - Numbers and thresholds

    @Test
    func processorCountSplitsPerformanceAndEfficiencyCores() throws {
        let fourPart = try #require(processorCountExplanation("proc 14:0:10:4"))
        let threePart = try #require(processorCountExplanation("proc 8:4:4"))

        #expect(fourPart.summary == "14 CPU cores: 10 performance and 4 efficiency.")
        #expect(fourPart.confidence?.reasons.contains { $0.contains("unused core group") } == true)
        #expect(threePart.summary == "8 CPU cores: 4 performance and 4 efficiency.")
        #expect(processorCountExplanation("proc 14:3:4") == nil)
    }

    @Test
    func uptimeIsReadAsDaysHoursMinutesSeconds() throws {
        #expect(uptimeExplanation("up 0:1:17:52")?.summary == "Running for 1 hour 17 minutes since the last restart.")
        #expect(uptimeExplanation("up 2:0:5:0")?.summary == "Running for 2 days since the last restart.")
        #expect(uptimeExplanation("up 0:0:0:30")?.summary == "Running for less than a minute since the last restart.")
        #expect(uptimeExplanation("up 45:3:0:0")?.status == .informational)
    }

    @Test
    func batteryThresholdsFollowAppleDesignLimits() {
        func cycles(_ count: Int64) -> ValueStatus? {
            valueExplanation(dataType: .power, path: ["sppower_battery_health_info", "sppower_battery_cycle_count"], scalar: .integer(count))?.status
        }
        func capacity(_ text: String) -> ValueStatus? {
            valueExplanation(dataType: .power, path: ["sppower_battery_health_info", "sppower_battery_health_maximum_capacity"], scalar: .string(text))?.status
        }

        #expect(cycles(999) == .normal)
        #expect(cycles(1_000) == .informational)
        #expect(capacity("80%") == .normal)
        #expect(capacity("79%") == .worthReviewing)
    }

    @Test
    func lowBatteryIsWorthALookUnlessCharging() {
        let path: [String] = ["sppower_battery_charge_info", "sppower_battery_state_of_charge"]

        #expect(valueExplanation(dataType: .power, path: path, scalar: .integer(4), siblings: ["sppower_battery_is_charging": .string("FALSE")])?.status == .worthReviewing)
        #expect(valueExplanation(dataType: .power, path: path, scalar: .integer(4), siblings: ["sppower_battery_is_charging": .string("TRUE")])?.status == .normal)
        #expect(valueExplanation(dataType: .power, path: path, scalar: .integer(11), siblings: [:])?.status == .normal)
    }

    @Test
    func freeSpaceBelowTenPercentIsWorthALook() {
        func status(free: Int64, size: Int64, protocolName: String = "Apple Fabric") -> ValueStatus? {
            valueExplanation(
                dataType: .storage,
                path: ["free_space_in_bytes"],
                scalar: .integer(free),
                siblings: [
                    "size_in_bytes": .integer(size),
                    "physical_drive": .object(["protocol": .string(protocolName)])
                ]
            )?.status
        }

        #expect(status(free: 100, size: 1_000) == .normal)
        #expect(status(free: 99, size: 1_000) == .worthReviewing)
        #expect(status(free: 1, size: 1_000, protocolName: "Disk Image") == nil)
    }

    @Test
    func sealedSystemVolumeIsReadOnlyByDesign() throws {
        let system = try #require(valueExplanation(
            dataType: .storage,
            path: ["writable"],
            scalar: .string("no"),
            siblings: ["mount_point": .string("/")]
        ))

        #expect(system.status == .normal)
        #expect(system.confidence == .documented)
    }

    @Test
    func wifiSignalBandsHaveInclusiveUpperEdges() {
        func status(_ dBm: Int) -> ValueStatus? {
            wifiSignalExplanation("\(dBm) dBm / -91 dBm", isCurrentNetwork: true)?.status
        }

        #expect(wifiSignalExplanation("-45 dBm / -91 dBm", isCurrentNetwork: true)?.summary == "Excellent signal (-45 dBm, 46 dB above background noise).")
        #expect(status(-67) == .normal)
        #expect(status(-68) == .informational)
        #expect(status(-75) == .informational)
        #expect(status(-76) == .worthReviewing)
        #expect(wifiSignalExplanation("-80 dBm / -91 dBm", isCurrentNetwork: false)?.status == .informational)
    }

    @Test
    func wifiChannelAndGenerationDecode() {
        #expect(wifiChannelExplanation("36 (5GHz, 160MHz)")?.summary == "Channel 36 on the 5 GHz band, 160 MHz wide.")
        #expect(wifiChannelExplanation("6 (2GHz, 20MHz)")?.summary == "Channel 6 on the 2.4 GHz band, 20 MHz wide.")
        #expect(wifiGeneration("802.11a/n/ac/ax") == "Wi-Fi 6 (802.11ax)")
        #expect(wifiGeneration("802.11 a/b/g/n/ac/ax") == "Wi-Fi 6 (802.11ax)")
        #expect(wifiGeneration("802.11g/n") == "Wi-Fi 4 (802.11n)")
    }

    @Test
    func ipConfigurationDependsOnAddressFamily() {
        #expect(valueExplanation(dataType: .network, path: ["IPv4", "ConfigMethod"], scalar: .string("DHCP"))?.status == .normal)
        #expect(valueExplanation(dataType: .network, path: ["IPv4", "ConfigMethod"], scalar: .string("Manual"))?.status == .informational)
        #expect(valueExplanation(dataType: .network, path: ["IPv6", "ConfigMethod"], scalar: .string("Automatic"))?.status == .normal)
    }

    // MARK: - Fallbacks

    @Test
    func unknownValuesInExplainedFieldsGetAnHonestFallback() throws {
        let explanation = try #require(valueExplanation(
            dataType: .firewall,
            path: ["spfirewall_globalstate"],
            scalar: .string("spfirewall_globalstate_future_mode")
        ))

        #expect(explanation.status == .unknown)
        #expect(explanation.confidence == nil)
        #expect(explanation.summary.contains("spfirewall_globalstate_future_mode"))
    }

    @Test
    func unknownEnumerationTokensAreMarkedButFreeTextIsNot() {
        #expect(valueExplanation(dataType: .audio, path: ["coreaudio_future_field"], scalar: .string("coreaudio_future_value"))?.status == .unknown)
        #expect(valueExplanation(dataType: .storage, path: ["_name"], scalar: .string("Macintosh HD")) == nil)
        #expect(valueExplanation(dataType: .hardware, path: ["serial_number"], scalar: .string("C02XXXXXXX")) == nil)
        #expect(valueExplanation(dataType: .power, path: ["AC Power", "Wake On LAN"], scalar: .string("No")) == nil)
    }

    // MARK: - Coverage

    /// Enumeration values observed in a full scan (see docs/value-inventory.md) for fields the
    /// first wave of rules covers. A value listed here must never fall back to "not yet explained".
    @Test
    func observedFirstWaveValuesAreAllExplained() {
        let observed: [(SystemProfilerDataType, [String], String)] = [
            (.hardware, ["activation_lock_status"], "activation_lock_enabled"),
            (.hardware, ["number_processors"], "proc 14:0:10:4"),
            (.software, ["system_integrity"], "integrity_enabled"),
            (.software, ["secure_vm"], "secure_vm_enabled"),
            (.software, ["boot_mode"], "normal_boot"),
            (.software, ["uptime"], "up 0:1:17:52"),
            (.firewall, ["spfirewall_globalstate"], "spfirewall_globalstate_limit_connections"),
            (.firewall, ["spfirewall_applications", "com.example.app"], "spfirewall_allow_all"),
            (.firewall, ["spfirewall_applications", "com.example.app"], "spfirewall_block_all"),
            (.firewall, ["spfirewall_stealthenabled"], "Yes"),
            (.firewall, ["spfirewall_loggingenabled"], "No"),
            (.power, ["sppower_battery_charge_info", "sppower_battery_at_warn_level"], "TRUE"),
            (.power, ["sppower_battery_charge_info", "sppower_battery_is_charging"], "FALSE"),
            (.power, ["sppower_battery_charge_info", "sppower_battery_fully_charged"], "FALSE"),
            (.power, ["sppower_battery_health_info", "sppower_battery_health"], "Good"),
            (.power, ["sppower_battery_health_info", "sppower_battery_health_maximum_capacity"], "100%"),
            (.power, ["AC Power", "Hibernate Mode"], "3"),
            (.storage, ["file_system"], "APFS"),
            (.storage, ["physical_drive", "medium_type"], "ssd"),
            (.storage, ["physical_drive", "smart_status"], "Verified"),
            (.storage, ["physical_drive", "partition_map_type"], "unknown_partition_map_type"),
            (.storage, ["writable"], "yes"),
            (.storage, ["writable"], "no"),
            (.network, ["hardware"], "Ethernet"),
            (.network, ["hardware"], "AirPort"),
            (.network, ["hardware"], "Modem"),
            (.network, ["type"], "Ethernet"),
            (.network, ["type"], "AirPort"),
            (.network, ["type"], "PPP (PPPSerial)"),
            (.network, ["type"], "VPN (com.example.vpn)"),
            (.network, ["IPv4", "ConfigMethod"], "DHCP"),
            (.network, ["IPv4", "ConfigMethod"], "Manual"),
            (.network, ["IPv4", "ConfigMethod"], "PPP"),
            (.network, ["IPv4", "ConfigMethod"], "VPN"),
            (.network, ["IPv6", "ConfigMethod"], "Automatic"),
            (.wifi, ["spairport_status_information"], "spairport_status_connected"),
            (.wifi, ["spairport_security_mode"], "spairport_security_mode_wpa2_personal"),
            (.wifi, ["spairport_security_mode"], "spairport_security_mode_wpa2_enterprise"),
            (.wifi, ["spairport_security_mode"], "spairport_security_mode_wpa3_personal"),
            (.wifi, ["spairport_security_mode"], "pairport_security_mode_wpa3_transition"),
            (.wifi, ["spairport_network_type"], "spairport_network_type_station"),
            (.wifi, ["spairport_network_channel"], "36 (5GHz, 160MHz)"),
            (.wifi, ["spairport_network_phymode"], "802.11ax"),
            (.wifi, ["spairport_supported_phymodes"], "802.11 a/b/g/n/ac/ax"),
            (.wifi, ["spairport_signal_noise"], "-45 dBm / -91 dBm"),
            (.wifi, ["spairport_network_country_code"], "US"),
            (.wifi, ["spairport_caps_airdrop"], "spairport_caps_supported"),
            (.bluetooth, ["controller_properties", "controller_state"], "attrib_on"),
            (.bluetooth, ["controller_properties", "controller_discoverable"], "attrib_off"),
            (.bluetooth, ["controller_properties", "controller_vendorID"], "0x004C (Apple)"),
            (.applications, ["arch_kind"], "arch_arm"),
            (.applications, ["arch_kind"], "arch_arm_i64"),
            (.applications, ["arch_kind"], "arch_i64"),
            (.applications, ["arch_kind"], "arch_ios"),
            (.applications, ["arch_kind"], "arch_other"),
            (.applications, ["obtained_from"], "identified_developer"),
            (.applications, ["obtained_from"], "mac_app_store"),
            (.applications, ["obtained_from"], "ios_app_store"),
            (.applications, ["obtained_from"], "apple"),
            (.installHistory, ["package_source"], "package_source_apple"),
            (.installHistory, ["package_source"], "package_source_other"),
            (.extensions, ["spext_loaded"], "spext_yes"),
            (.extensions, ["spext_hasAllDependencies"], "spext_satisfied"),
            (.extensions, ["spext_has64BitIntelCode"], "spext_no")
        ]

        for (dataType, path, value) in observed {
            let explanation: ValueExplanation? = valueExplanation(dataType: dataType, path: path, scalar: .string(value))
            #expect(explanation != nil, "\(dataType.rawValue).\(path.joined(separator: ".")) = \(value) has no explanation")
            #expect(explanation?.status != .unknown, "\(dataType.rawValue).\(path.joined(separator: ".")) = \(value) is not yet explained")
        }
    }
}

private let nrf52Service: [String: ProfileValue] = [
    "_name": .string("nRF52 USB Product"),
    "hardware": .string("Modem"),
    "type": .string("PPP (PPPSerial)"),
    "interface": .string("usbmodem0000000000001")
]
