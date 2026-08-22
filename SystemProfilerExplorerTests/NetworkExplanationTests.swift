import Testing
@testable import SystemProfilerExplorer

struct NetworkExplanationTests {
    @Test
    func observedNetworkFieldsHaveCuratedExplanations() {
        let fields: [String] = [
            "Addresses",
            "ip_address",
            "ServerAddresses",
            "InterfaceName",
            "ConfirmedInterfaceName",
            "interface",
            "hardware",
            "type",
            "spnetwork_service_order",
            "MAC Address",
            "MediaSubType",
            "ConfigMethod",
            "Router",
            "ServerAddress",
            "SubnetMasks",
            "SubnetMask",
            "PrefixLength",
            "DestinationAddress",
            "ARPResolvedHardwareAddress",
            "ARPResolvedIPAddress",
            "NetworkSignature",
            "NetworkSignatureHash",
            "ExceptionsList",
            "ExcludeSimpleHostnames",
            "FTPEnable",
            "FTPPassive",
            "GopherEnable",
            "HTTPEnable",
            "HTTPSEnable",
            "RTSPEnable",
            "SOCKSEnable",
            "ProxyAutoConfigEnable",
            "ProxyAutoDiscoveryEnable"
        ]

        expectExplanations(dataType: .network, fields: fields)
    }

    @Test
    func observedWiFiFieldsHaveCuratedExplanations() {
        let fields: [String] = [
            "spairport_caps_airdrop",
            "spairport_caps_autounlock",
            "spairport_caps_wow",
            "spairport_status_information",
            "spairport_supported_phymodes",
            "spairport_wireless_card_type",
            "spairport_wireless_country_code",
            "spairport_wireless_locale",
            "spairport_wireless_firmware_version",
            "spairport_wireless_mac_address",
            "spairport_supported_channels",
            "spairport_network_channel",
            "spairport_network_country_code",
            "spairport_network_mcs",
            "spairport_network_phymode",
            "spairport_network_rate",
            "spairport_network_type",
            "spairport_security_mode",
            "spairport_signal_noise",
            "spairport_corewlan_version",
            "spairport_corewlankit_version",
            "spairport_diagnostics_version",
            "spairport_extra_version",
            "spairport_family_version",
            "spairport_profiler_version",
            "spairport_utility_version"
        ]

        expectExplanations(dataType: .wifi, fields: fields)
    }

    @Test
    func observedBluetoothFieldsHaveCuratedExplanations() {
        let fields: [String] = [
            "controller_address",
            "controller_chipset",
            "controller_discoverable",
            "controller_firmwareVersion",
            "controller_productID",
            "controller_state",
            "controller_supportedServices",
            "controller_transport",
            "controller_vendorID"
        ]

        expectExplanations(dataType: .bluetooth, fields: fields)
    }

    @Test
    func observedNetworkLocationFieldsHaveCuratedExplanations() {
        let fields: [String] = [
            "spnetworklocation_isActive",
            "JoinMode",
            "ACSPEnabled",
            "CommDisplayTerminalWindow",
            "CommRedialCount",
            "CommRedialEnabled",
            "CommRedialInterval",
            "CommUseTerminalScript",
            "DialOnDemand",
            "DisconnectOnFastUserSwitch",
            "DisconnectOnIdle",
            "DisconnectOnIdleTimer",
            "DisconnectOnLogout",
            "DisconnectOnSleep",
            "DisconnectOnWake",
            "DisconnectOnWakeTimer",
            "IPCPCompressionVJ",
            "IdleReminder",
            "IdleReminderTimer",
            "LCPEchoEnabled",
            "LCPEchoFailure",
            "LCPEchoInterval",
            "Logfile",
            "VerboseLogging",
            "AuthenticationMethod",
            "DesignatedRequirement",
            "NEProviderBundleIdentifier",
            "OnDemandEnabled",
            "Action",
            "InterfaceTypeMatch",
            "RemoteAddress",
            "bsd_device_name",
            "hardware_address"
        ]

        expectExplanations(dataType: .networkLocation, fields: fields)
    }

    @Test
    func observedNetworkVolumeFieldsHaveCuratedExplanations() {
        let fields: [String] = [
            "spnetworkvolume_automounted",
            "spnetworkvolume_fsmtnonname",
            "spnetworkvolume_fstypename",
            "spnetworkvolume_mntfromname"
        ]

        expectExplanations(dataType: .networkVolumes, fields: fields)
    }

    @Test
    func networkIdentifiersAndTopologyIncludePrivacyGuidance() throws {
        let address = try #require(
            explanation(for: .network, path: ["IPv4", "Addresses", "[]"], reportedValue: "REDACTED")
        )
        let wifiAddress = try #require(
            explanation(for: .wifi, path: ["spairport_wireless_mac_address"], reportedValue: "REDACTED")
        )
        let vpnEndpoint = try #require(
            explanation(for: .networkLocation, path: ["VPN", "RemoteAddress"], reportedValue: "REDACTED")
        )
        let volumeSource = try #require(
            explanation(for: .networkVolumes, path: ["spnetworkvolume_mntfromname"], reportedValue: "REDACTED")
        )

        #expect(address.privacy != nil)
        #expect(wifiAddress.privacy != nil)
        #expect(vpnEndpoint.privacy != nil)
        #expect(volumeSource.privacy != nil)
    }

    @Test
    func scalarArrayItemsUseTheNearestSourceFieldAsTheirTitle() {
        let presentation = fieldPresentation(
            dataType: .rawCamera,
            path: ["architectures", "[]"],
            scalar: .string("arm64")
        )

        #expect(presentation.title == "Architectures")
        #expect(presentation.sourcePath == "SPRawCameraDataType.architectures.[]")
    }
}

private func expectExplanations(
    dataType: SystemProfilerDataType,
    fields: [String]
) {
    for field in fields {
        let path: [String] = field == "Addresses" || field == "ServerAddresses"
            ? [field, "[]"]
            : [field]

        #expect(explanation(for: dataType, path: path, reportedValue: "yes") != nil)
    }
}
