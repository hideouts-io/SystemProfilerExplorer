import Foundation
import Testing
@testable import SystemProfilerExplorer

/// One known value of a limited-set field, as system_profiler reports it.
/// docs/value-explanations.md lists the same values with their sources.
struct ValueSample: Sendable, CustomTestStringConvertible {
    let dataType: SystemProfilerDataType
    let path: [String]
    let scalar: ProfileScalar
    let siblings: [String: ProfileValue]
    let report: ValueReportContext

    init(
        _ dataType: SystemProfilerDataType,
        _ path: [String],
        _ value: String,
        siblings: [String: ProfileValue] = [:],
        report: ValueReportContext = .empty
    ) {
        self.init(dataType, path, scalar: .string(value), siblings: siblings, report: report)
    }

    init(
        _ dataType: SystemProfilerDataType,
        _ path: [String],
        scalar: ProfileScalar,
        siblings: [String: ProfileValue] = [:],
        report: ValueReportContext = .empty
    ) {
        self.dataType = dataType
        self.path = path
        self.scalar = scalar
        self.siblings = siblings
        self.report = report
    }

    var testDescription: String {
        "\(dataType.rawValue).\(path.joined(separator: ".")) = \(scalar.rawDescription)"
    }

    func explain() -> ValueExplanation? {
        valueExplanation(dataType: dataType, path: path, scalar: scalar, siblings: siblings, report: report)
    }
}

let appleSiliconReport: ValueReportContext = ValueReportContext(usbDeviceNames: nil, processor: .appleSilicon)
let intelReport: ValueReportContext = ValueReportContext(usbDeviceNames: nil, processor: .intel)

/// Every value the app explains for fields with a limited set of values.
let explainedValueSamples: [ValueSample] = applicationValueSamples + fontValueSamples + extensionValueSamples
    + networkValueSamples + softwareHistoryAndFirewallValueSamples + wifiValueSamples
    + powerValueSamples + storageValueSamples + startupAndOverviewValueSamples
    + hardwareValueSamples + settingsValueSamples + driveAndCardValueSamples + discDriveValueSamples
    + bluetoothAccessoryValueSamples

/// Each value is checked with no Hardware section, on Apple silicon, and on an Intel Mac,
/// because what an architecture means depends on the Mac.
private let applicationValueSamples: [ValueSample] = {
    let architectures: [String] = [
        "arch_arm", "arch_arm_i64", "arch_i64", "arch_i32_i64", "arch_ios", "arch_other", "arch_i32", "arch_ppc"
    ]
    let origins: [String] = ["apple", "mac_app_store", "app_store", "ios_app_store", "identified_developer", "unknown"]
    var samples: [ValueSample] = []

    for dataType in [SystemProfilerDataType.applications, .frameworks] {
        for architecture in architectures {
            for report in [ValueReportContext.empty, appleSiliconReport, intelReport] {
                samples.append(ValueSample(dataType, ["arch_kind"], architecture, report: report))
            }
        }

        for origin in origins {
            samples.append(ValueSample(dataType, ["obtained_from"], origin))
        }
    }

    samples += origins.map { ValueSample(.extensions, ["obtained_from"], $0) }
    samples += ["yes", "no"].map { ValueSample(.frameworks, ["private_framework"], $0) }
    return samples
}()

private let fontValueSamples: [ValueSample] = {
    var samples: [ValueSample] = ["truetype", "opentype", "postscript", "bitmap", "unknown"].map {
        ValueSample(.fonts, ["type"], $0)
    }

    for flag in ["enabled", "valid"] {
        for value in ["yes", "no"] {
            samples.append(ValueSample(.fonts, [flag], value))
            samples.append(ValueSample(.fonts, ["typefaces", "[]", flag], value))
        }
    }

    for flag in ["duplicate", "copy_protected", "embeddable", "outline"] {
        for value in ["yes", "no"] {
            samples.append(ValueSample(.fonts, ["typefaces", "[]", flag], value))
        }
    }

    return samples
}()

private let extensionValueSamples: [ValueSample] = {
    var samples: [ValueSample] = []

    for value in ["spext_yes", "spext_no"] {
        samples.append(ValueSample(.extensions, ["spext_loaded"], value))
        samples.append(ValueSample(.extensions, ["spext_notarized"], value))

        for report in [ValueReportContext.empty, appleSiliconReport, intelReport] {
            samples.append(ValueSample(.extensions, ["spext_has64BitIntelCode"], value, report: report))
        }
    }

    samples += ["spext_satisfied", "spext_incomplete"].map { ValueSample(.extensions, ["spext_hasAllDependencies"], $0) }
    samples += ["yes", "no"].map { ValueSample(.extensions, ["spext_loadable"], $0) }
    samples += ["arm64e", "arm64", "x86_64", "i386"].map { ValueSample(.extensions, ["spext_architectures", "[]"], $0) }
    samples += ["spext_arch_arm", "spext_arch_x86", "spext_universal", "spext_arch_ppc"].map {
        ValueSample(.extensions, ["spext_runtime_environment"], $0)
    }
    samples += ["spext_apple", "spext_identified_developer", "spext_unknown", "spext_not_signed"].map {
        ValueSample(.extensions, ["spext_obtained_from"], $0)
    }
    return samples
}()

private let networkValueSamples: [ValueSample] = {
    let serviceTypes: [String] = [
        "Ethernet", "AirPort", "IEEE80211", "Bridge", "Bond", "VLAN", "6to4", "IPSec", "PPP", "PPP (PPPSerial)",
        "PPP (PPPoE)", "PPP (L2TP)", "PPP (PPTP)", "VPN", "VPN (com.example.vpn)"
    ]
    let ipv4Methods: [String] = ["DHCP", "Manual", "INFORM", "BOOTP", "LinkLocal", "Automatic", "PPP", "VPN"]
    let ipv6Methods: [String] = ["Automatic", "LinkLocal", "Manual", "RouterAdvertisement", "6to4"]
    let proxySwitches: [String] = [
        "HTTPEnable", "HTTPSEnable", "SOCKSEnable", "FTPEnable", "GopherEnable", "RTSPEnable",
        "ProxyAutoConfigEnable", "ProxyAutoDiscoveryEnable", "FTPPassive", "ExcludeSimpleHostnames"
    ]
    let connectionSwitches: [String] = [
        "DisconnectOnIdle", "DisconnectOnLogout", "DisconnectOnSleep", "DisconnectOnFastUserSwitch", "DisconnectOnWake",
        "DialOnDemand", "CommRedialEnabled", "IdleReminder", "LCPEchoEnabled", "VerboseLogging", "IPCPCompressionVJ",
        "CommDisplayTerminalWindow", "CommUseTerminalScript", "ACSPEnabled", "CCPEnabled", "CCPMPPE40Enabled",
        "CCPMPPE128Enabled", "IPCPUsePeerDNS", "LCPCompressionACField", "LCPCompressionPField", "UseSessionTimer"
    ]
    let service: [String] = ["spnetworklocation_services", "[]"]
    var samples: [ValueSample] = []

    for dataType in [SystemProfilerDataType.network, .networkLocation] {
        samples += ["Ethernet", "AirPort", "FireWire", "Modem"].map { ValueSample(dataType, ["hardware"], $0) }
        samples += serviceTypes.map { ValueSample(dataType, ["type"], $0) }
        samples += ipv4Methods.map { ValueSample(dataType, ["IPv4", "ConfigMethod"], $0) }
        samples += ipv6Methods.map { ValueSample(dataType, ["IPv6", "ConfigMethod"], $0) }

        for proxySwitch in proxySwitches {
            for value in ["yes", "no", "1", "0"] {
                samples.append(ValueSample(dataType, ["Proxies", proxySwitch], value))
            }
        }
    }

    samples.append(ValueSample(
        .network,
        ["hardware"],
        "Modem",
        siblings: ["_name": .string("nRF52 USB Product"), "type": .string("PPP (PPPSerial)"), "interface": .string("usbmodem0001")]
    ))

    for value in ["true", "false"] {
        samples.append(ValueSample(.networkLocation, service + ["VPN", "OnDemandEnabled"], value))
    }

    samples += ["Connect", "Disconnect", "EvaluateConnection", "Ignore"].map {
        ValueSample(.networkLocation, service + ["VPN", "OnDemandRules", "[]", "Action"], $0)
    }
    samples += ["WiFi", "Ethernet", "Cellular"].map {
        ValueSample(.networkLocation, service + ["VPN", "OnDemandRules", "[]", "InterfaceTypeMatch"], $0)
    }

    for connectionSwitch in connectionSwitches {
        for value in ["yes", "no"] {
            samples.append(ValueSample(.networkLocation, service + ["PPP", connectionSwitch], value))
        }
    }

    samples += ["yes", "no"].map { ValueSample(.networkLocation, ["spnetworklocation_isActive"], $0) }
    samples += ["Automatic", "Preferred", "Ranked", "Recent", "Strongest"].map {
        ValueSample(.networkLocation, service + ["IEEE80211", "JoinMode"], $0)
    }
    samples += ["Password", "Certificate", "SharedSecret", "Hybrid"].map {
        ValueSample(.networkLocation, service + ["VPN", "AuthenticationMethod"], $0)
    }
    samples += ["autoselect", "none", "10baseT/UTP", "100baseTX", "1000baseT", "10GbaseT"].map {
        ValueSample(.network, ["Ethernet", "MediaSubType"], $0)
    }
    samples += ["full-duplex", "half-duplex", "flow-control"].map {
        ValueSample(.network, ["Ethernet", "MediaOptions", "[]"], $0)
    }
    samples += ["yes", "no"].map { ValueSample(.networkVolumes, ["spnetworkvolume_automounted"], $0) }
    return samples
}()

private let softwareHistoryAndFirewallValueSamples: [ValueSample] = {
    var samples: [ValueSample] = ["package_source_apple", "package_source_other"].map {
        ValueSample(.installHistory, ["package_source"], $0)
    }

    samples += ["reason_x86_only", "reason_x86_forced_environmental"].map { ValueSample(.legacySoftware, ["reason"], $0) }
    samples += [
        "spfirewall_globalstate_limit_connections", "spfirewall_globalstate_block_all",
        "spfirewall_globalstate_allow_all", "spfirewall_globalstate_off"
    ].map { ValueSample(.firewall, ["spfirewall_globalstate"], $0) }
    samples += ["spfirewall_allow_all", "spfirewall_block_all", "spfirewall_allow_local"].map {
        ValueSample(.firewall, ["spfirewall_applications", "com.example.app"], $0)
    }

    for field in ["spfirewall_stealthenabled", "spfirewall_loggingenabled"] {
        samples += ["Yes", "No"].map { ValueSample(.firewall, [field], $0) }
    }

    return samples
}()

private let wifiValueSamples: [ValueSample] = {
    let interface: [String] = ["spairport_airport_interfaces", "[]"]
    let current: [String] = interface + ["spairport_current_network_information"]
    let nearby: [String] = interface + ["spairport_airport_other_local_wireless_networks", "[]"]

    var samples: [ValueSample] = [
        "spairport_status_connected", "spairport_status_off", "spairport_status_disassociated",
        "spairport_status_inactive", "spairport_status_disconnected", "spairport_status_not_associated"
    ].map { ValueSample(.wifi, interface + ["spairport_status_information"], $0) }

    let securityModes: [String] = [
        "none", "wep", "wep40", "wep128", "8021x", "wps", "wpa_personal", "wpa_personal_mixed", "wpa_enterprise",
        "wpa2_personal", "wpa2_personal_mixed", "wpa2_enterprise", "wpa2_enterprise_mixed", "wpa3_personal",
        "wpa3_transition", "wpa3_enterprise", "wpa2_wpa3_enterprise", "owe"
    ]
    for network in [current, nearby] {
        samples += securityModes.map { ValueSample(.wifi, network + ["spairport_security_mode"], "spairport_security_mode_\($0)") }
        samples += ["-45 dBm / -91 dBm", "-80 dBm / -91 dBm"].map { ValueSample(.wifi, network + ["spairport_signal_noise"], $0) }
        samples += ["36 (5GHz, 160MHz)", "6 (2GHz, 20MHz)", "37 (6GHz, 320MHz)"].map {
            ValueSample(.wifi, network + ["spairport_network_channel"], $0)
        }
        samples.append(ValueSample(.wifi, network + ["spairport_network_phymode"], "802.11ax"))
    }
    samples += ["station", "ibss", "sharing"].map {
        ValueSample(.wifi, nearby + ["spairport_network_type"], "spairport_network_type_\($0)")
    }
    samples.append(ValueSample(.wifi, current + ["spairport_network_rate"], scalar: .integer(1201)))
    samples.append(ValueSample(.wifi, current + ["spairport_network_country_code"], "US"))
    samples.append(ValueSample(.wifi, interface + ["spairport_wireless_country_code"], "DE"))
    samples.append(ValueSample(.wifi, interface + ["spairport_supported_phymodes"], "802.11 a/b/g/n/ac/ax"))
    samples += ["FCC", "ETSI", "MKK", "RoW"].map { ValueSample(.wifi, interface + ["spairport_wireless_locale"], $0) }

    for field in ["spairport_caps_airdrop", "spairport_caps_autounlock", "spairport_caps_wow", "spairport_caps_awdl"] {
        samples += ["spairport_caps_supported", "spairport_caps_unsupported"].map {
            ValueSample(.wifi, interface + [field], $0)
        }
    }

    return samples
}()

private let powerValueSamples: [ValueSample] = {
    let charge: [String] = ["sppower_battery_charge_info"]
    let health: [String] = ["sppower_battery_health_info"]
    let charging: [String: ProfileValue] = ["sppower_battery_is_charging": .string("TRUE")]
    let full: [String: ProfileValue] = ["sppower_battery_fully_charged": .string("TRUE")]

    var samples: [ValueSample] = [
        ValueSample(.power, charge + ["sppower_battery_at_warn_level"], "TRUE"),
        ValueSample(.power, charge + ["sppower_battery_at_warn_level"], "TRUE", siblings: charging),
        ValueSample(.power, charge + ["sppower_battery_at_warn_level"], "FALSE"),
        ValueSample(.power, charge + ["sppower_battery_state_of_charge"], scalar: .integer(4)),
        ValueSample(.power, charge + ["sppower_battery_state_of_charge"], scalar: .integer(67)),
        ValueSample(.power, charge + ["sppower_battery_is_charging"], "TRUE"),
        ValueSample(.power, charge + ["sppower_battery_is_charging"], "FALSE"),
        ValueSample(.power, charge + ["sppower_battery_is_charging"], "FALSE", siblings: full),
        ValueSample(.power, charge + ["sppower_battery_fully_charged"], "TRUE"),
        ValueSample(.power, charge + ["sppower_battery_fully_charged"], "FALSE"),
        ValueSample(.power, health + ["sppower_battery_cycle_count"], scalar: .integer(154)),
        ValueSample(.power, health + ["sppower_battery_cycle_count"], scalar: .integer(1_200)),
        ValueSample(.power, health + ["sppower_battery_health_maximum_capacity"], "97%"),
        ValueSample(.power, health + ["sppower_battery_health_maximum_capacity"], "72%")
    ]
    samples += ["Good", "Fair", "Poor", "Check Battery", "Normal", "Service Recommended"].map {
        ValueSample(.power, health + ["sppower_battery_health"], $0)
    }
    samples += ["AC Power", "Battery Power", "UPS Power"].map { ValueSample(.power, [$0, "Current Power Source"], "TRUE") }
    samples += ["0", "3", "25"].map { ValueSample(.power, ["AC Power", "Hibernate Mode"], $0) }

    for timer in ["Display Sleep Timer", "System Sleep Timer", "Disk Sleep Timer"] {
        samples += [Int64(0), 10].map { ValueSample(.power, ["AC Power", timer], scalar: .integer($0)) }
    }
    for setting in ["LowPowerMode", "HighPowerMode", "PrioritizeNetworkReachabilityOverSleep", "ReduceBrightness"] {
        samples += [Int64(0), 1].map { ValueSample(.power, ["Battery Power", setting], scalar: .integer($0)) }
    }
    for field in ["sppower_battery_charger_connected", "sppower_ups_installed"] {
        samples += ["TRUE", "FALSE"].map { ValueSample(.power, [field], $0) }
    }
    samples += ["wake", "poweron", "wakepoweron", "sleep", "shutdown", "restart"].map {
        ValueSample(.power, ["_items", "[]", "_items", "[]", "eventtype"], $0)
    }

    return samples
}()

private let storageValueSamples: [ValueSample] = {
    let drive: [String] = ["physical_drive"]
    var samples: [ValueSample] = [
        ValueSample(.storage, ["writable"], "yes"),
        ValueSample(.storage, ["writable"], "no"),
        ValueSample(.storage, ["writable"], "no", siblings: ["mount_point": .string("/")]),
        ValueSample(.storage, ["writable"], "no", siblings: ["physical_drive": .object(["protocol": .string("Disk Image")])]),
        ValueSample(.storage, ["free_space_in_bytes"], scalar: .integer(500), siblings: ["size_in_bytes": .string("1000")]),
        ValueSample(.storage, ["free_space_in_bytes"], scalar: .integer(50), siblings: ["size_in_bytes": .string("1000")]),
        ValueSample(.storage, drive + ["is_internal_disk"], "yes"),
        ValueSample(.storage, drive + ["is_internal_disk"], "no"),
        ValueSample(.storage, drive + ["is_internal_disk"], "no", siblings: ["protocol": .string("Disk Image")]),
        ValueSample(.storage, ["ignore_ownership"], "yes"),
        ValueSample(.storage, ["ignore_ownership"], "no")
    ]

    samples += ["Verified", "Failing", "Not Supported"].map { ValueSample(.storage, drive + ["smart_status"], $0) }
    samples += ["ssd", "rotational"].map { ValueSample(.storage, drive + ["medium_type"], $0) }
    samples += [
        "APFS", "Journaled HFS+", "Case-sensitive Journaled HFS+", "ExFAT", "MS-DOS FAT32", "NTFS"
    ].map { ValueSample(.storage, ["file_system"], $0) }
    samples += [
        "guid_partition_map_type", "master_boot_record_partition_map_type", "apple_partition_map_type", "unknown_partition_map_type"
    ].map { ValueSample(.storage, drive + ["partition_map_type"], $0) }
    samples += [
        "Apple Fabric", "Disk Image", "USB", "Thunderbolt", "SATA", "PCI-Express", "NVMe", "Secure Digital"
    ].map { ValueSample(.storage, drive + ["protocol"], $0) }

    for field in ["removable_media", "detachable_drive", "spnvme_trim_support"] {
        samples += ["yes", "no"].map { ValueSample(.nvme, ["_items", "[]", field], $0) }
    }
    samples += ["Yes", "No"].map { ValueSample(.serialATA, ["_items", "[]", "spsata_trim_support"], $0) }
    samples += [
        "Apple_APFS", "Apple_APFS_ISC", "Apple_APFS_Recovery", "EFI", "Apple_HFS", "Apple_Boot", "Apple_CoreStorage", "Microsoft Basic Data"
    ].map { ValueSample(.nvme, ["_items", "[]", "volumes", "[]", "iocontent"], $0) }

    return samples
}()

/// Serial ATA drives and cards in a card reader report the same drive and volume
/// fields as NVMe drives and the Storage section. The values are the ones in the
/// published macOS samples listed in docs/value-explanations.md.
private let driveAndCardValueSamples: [ValueSample] = {
    let drive: [String] = ["_items", "[]"]
    let volume: [String] = drive + ["volumes", "[]"]
    var samples: [ValueSample] = []

    for dataType in [SystemProfilerDataType.serialATA, .cardReader] {
        samples += ["Verified", "Failing", "Not Supported"].map { ValueSample(dataType, drive + ["smart_status"], $0) }
        samples += ["guid_partition_map_type", "master_boot_record_partition_map_type"].map {
            ValueSample(dataType, drive + ["partition_map_type"], $0)
        }
        for field in ["removable_media", "detachable_drive"] {
            samples += ["yes", "no"].map { ValueSample(dataType, drive + [field], $0) }
        }
        samples += ["Journaled HFS+", "MS-DOS FAT32", "ExFAT", "APFS"].map { ValueSample(dataType, volume + ["file_system"], $0) }
        samples += ["yes", "no"].map { ValueSample(dataType, volume + ["writable"], $0) }
        samples += ["Apple_APFS", "EFI", "Apple_HFS", "Apple_Boot", "Apple_CoreStorage", "Windows_FAT_32"].map {
            ValueSample(dataType, volume + ["iocontent"], $0)
        }
    }

    let port: [String: ProfileValue] = ["spsata_portspeed": .string("6 Gigabit")]
    samples += ["Rotational", "Solid State"].map { ValueSample(.serialATA, drive + ["spsata_medium_type"], $0) }
    samples += ["Yes", "No"].map { ValueSample(.serialATA, drive + ["spsata_ncq"], $0) }
    samples += ["SATA", "PCI"].map { ValueSample(.serialATA, ["spsata_physical_interconnect"], $0) }
    samples += ["1.5 Gigabit", "3 Gigabit", "6 Gigabit", "1,5 Gigabit"].map { ValueSample(.serialATA, ["spsata_portspeed"], $0) }
    samples += ["3 Gigabit", "6 Gigabit"].map { ValueSample(.serialATA, ["spsata_negotiatedlinkspeed"], $0, siblings: port) }
    samples.append(ValueSample(.serialATA, ["spsata_negotiatedlinkspeed"], "3 Gigabit"))
    samples += ["2.5 GT/s", "5.0 GT/s", "8.0 GT/s"].map { ValueSample(.serialATA, ["spsata_linkspeed"], $0) }
    samples += ["x1", "x2", "x4"].map { ValueSample(.serialATA, ["spsata_linkwidth"], $0) }

    return samples
}()

private let discDriveValueSamples: [ValueSample] = {
    var samples: [ValueSample] = [
        "DRDeviceSupportLevelAppleShipping", "DRDeviceSupportLevelAppleSupported", "DRDeviceSupportLevelVendorSupported",
        "DRDeviceSupportLevelUnsupported", "DRDeviceSupportLevelNone"
    ].map { ValueSample(.discBurning, ["burn_support"], $0) }

    samples.append(ValueSample(.discBurning, ["device_media"], "media_none"))
    samples += ["yes", "no"].map { ValueSample(.discBurning, ["device_readdvd"], $0) }
    samples += ["ATAPI", "USB", "FireWire", "SCSI"].map { ValueSample(.discBurning, ["interconnect"], $0) }
    samples += ["-R, -RW", "-R"].map { ValueSample(.discBurning, ["device_cdwrite"], $0) }
    samples += ["-R, -R DL, -RW, +R, +R DL, +RW", "-R, -RAM"].map { ValueSample(.discBurning, ["device_dvdwrite"], $0) }
    samples += ["CD-TAO, CD-SAO, CD-Raw, DVD-DAO", "CD-TAO"].map { ValueSample(.discBurning, ["device_strategies"], $0) }
    return samples
}()

private let bluetoothAccessoryValueSamples: [ValueSample] = {
    let accessory: [String] = ["device_connected", "[]", "Example Accessory"]
    var samples: [ValueSample] = ["Headphones", "Headset", "Keyboard", "Mouse", "Trackpad", "Speaker", "Gamepad"].map {
        ValueSample(.bluetooth, accessory + ["device_minorType"], $0)
    }

    for field in ["device_batteryLevelMain", "device_batteryLevelLeft", "device_batteryLevelRight", "device_batteryLevelCase"] {
        samples += ["100%", "15%", "5%", "0%"].map { ValueSample(.bluetooth, accessory + [field], $0) }
    }

    samples += ["0x400000 < BLE >", "0x980019 < HFP AVRCP A2DP AACP GATT >"].map {
        ValueSample(.bluetooth, accessory + ["device_services"], $0)
    }
    samples.append(ValueSample(
        .bluetooth,
        ["controller_properties", "controller_supportedServices"],
        "0x382039 < HFP AVRCP A2DP HID Braille AACP GATT SerialPort >"
    ))
    return samples
}()

private let startupAndOverviewValueSamples: [ValueSample] = {
    var samples: [ValueSample] = [
        "Full Security", "Reduced Security", "Permissive Security", "Medium Security", "No Security"
    ].map { ValueSample(.iBridge, ["ibridge_secure_boot"], $0) }

    samples += ["Enabled", "Disabled", "Custom Configuration"].map { ValueSample(.iBridge, ["ibridge_sb_sip"], $0) }
    for field in ["ibridge_sb_ssv", "ibridge_sb_ctrr", "ibridge_sb_boot_args"] {
        samples += ["Enabled", "Disabled"].map { ValueSample(.iBridge, [field], $0) }
    }
    for field in ["ibridge_sb_other_kext", "ibridge_sb_manual_mdm", "ibridge_sb_device_mdm"] {
        samples += ["Yes", "No"].map { ValueSample(.iBridge, [field], $0) }
    }

    samples += ["integrity_enabled", "integrity_disabled"].map { ValueSample(.software, ["system_integrity"], $0) }
    samples += ["secure_vm_enabled", "secure_vm_disabled"].map { ValueSample(.software, ["secure_vm"], $0) }
    samples += ["normal_boot", "safe_boot", "installer_boot"].map { ValueSample(.software, ["boot_mode"], $0) }
    samples += ["up 0:1:17:52", "up 45:3:0:0"].map { ValueSample(.software, ["uptime"], $0) }
    samples += ["activation_lock_enabled", "activation_lock_disabled"].map {
        ValueSample(.hardware, ["activation_lock_status"], $0)
    }
    samples.append(ValueSample(.hardware, ["number_processors"], "proc 14:0:10:4"))
    samples.append(ValueSample(.hardware, ["physical_memory"], "32 GB", siblings: ["chip_type": .string("Apple M4 Pro")]))

    return samples
}()

private let hardwareValueSamples: [ValueSample] = {
    let display: [String] = ["spdisplays_ndrvs", "[]"]
    let port: [String] = ["_items", "[]", "receptacle_1_tag"]
    var samples: [ValueSample] = [
        "LCD", "CRT", "retinaLCD", "built-in_retinaLCD", "projector", "television", "airplaydisplay", "built-in-liquid-retina-xdr"
    ].map { ValueSample(.displays, display + ["spdisplays_display_type"], "spdisplays_\($0)") }

    samples += ["internal", "external", "airplay"].map {
        ValueSample(.displays, display + ["spdisplays_connection_type"], "spdisplays_\($0)")
    }
    for field in ["spdisplays_online", "spdisplays_main", "spdisplays_mirror", "spdisplays_ambient_brightness"] {
        samples += ["spdisplays_yes", "spdisplays_off"].map { ValueSample(.displays, display + [field], $0) }
    }
    samples += ["gpu", "egpu"].map { ValueSample(.displays, ["sppci_device_type"], "spdisplays_\($0)") }
    samples += ["builtin", "pcie_device", "tb_device", "agp_device"].map { ValueSample(.displays, ["sppci_bus"], "spdisplays_\($0)") }
    samples += ["spdisplays_metal4", "spdisplays_mtlgpufamilymac2"].map { ValueSample(.displays, ["spdisplays_mtlgpufamilysupport"], $0) }
    samples += ["sppci_vendor_Apple", "sppci_vendor_amd"].map { ValueSample(.displays, ["spdisplays_vendor"], $0) }
    samples.append(ValueSample(.displays, display + ["spdisplays_pixelresolution"], "spdisplays_3024x1964Retina"))
    samples.append(ValueSample(.displays, display + ["_spdisplays_resolution"], "1512 x 982 @ 120.00Hz", siblings: ["_spdisplays_pixels": .string("3024 x 1964")]))
    samples.append(ValueSample(.displays, ["sppci_cores"], "40"))

    samples += [
        "airplay", "avb", "bluetooth", "builtin", "displayport", "firewire", "hdmi", "network", "other", "pci",
        "thunderbolt", "unknown", "usb", "virtual", "wireless", "bluetoothle", "aggregate"
    ].map { ValueSample(.audio, ["_items", "[]", "coreaudio_device_transport"], "coreaudio_device_type_\($0)") }
    for field in ["coreaudio_default_audio_input_device", "coreaudio_default_audio_output_device", "coreaudio_default_audio_system_device"] {
        samples.append(ValueSample(.audio, ["_items", "[]", field], "spaudio_yes"))
    }
    samples.append(ValueSample(.audio, ["_items", "[]", "_properties"], "coreaudio_default_audio_system_device"))
    samples.append(ValueSample(.audio, ["_items", "[]", "coreaudio_device_srate"], scalar: .integer(48_000)))

    samples += ["receptacle_no_devices_connected", "receptacle_connected"].map {
        ValueSample(.thunderbolt, port + ["receptacle_status_key"], $0)
    }
    samples += ["trained", "training", "untrained", "disabled", "off", "Loopback", "unknown"].map {
        ValueSample(.thunderbolt, port + ["link_status_key"], "\($0)_link_status")
    }
    samples += ["Up to 40 Gb/s", "Up to 20 Gb/s x2", "Up to 10 Gb/s x1", "Up to 120 Gb/s"].map {
        ValueSample(.thunderbolt, port + ["current_speed_key"], $0)
    }

    samples += ["attrib_on", "attrib_off"].map { ValueSample(.bluetooth, ["controller_properties", "controller_state"], $0) }
    samples += ["attrib_on", "attrib_off"].map { ValueSample(.bluetooth, ["controller_properties", "controller_discoverable"], $0) }
    samples += ["PCIe", "USB", "UART"].map { ValueSample(.bluetooth, ["controller_properties", "controller_transport"], $0) }
    samples.append(ValueSample(.bluetooth, ["device_connected", "[]", "Keyboard", "device_rssi"], "-58"))

    samples.append(ValueSample(.usb, ["_items", "[]", "USBKeyHardwareType"], "Built-in"))
    samples += ["LPDDR5", "DDR4"].map { ValueSample(.memory, ["dimm_type"], $0) }
    samples += ["ok", "empty", "mapped_out", "unknown"].map { ValueSample(.memory, ["_items", "[]", "dimm_status"], $0) }
    samples += ["ecc_enabled", "ecc_disabled"].map { ValueSample(.memory, ["global_ecc_state"], $0) }
    samples += ["Yes", "No"].map { ValueSample(.memory, ["is_memory_upgradeable"], $0) }
    samples += ["spcardreader_link-speed", "spcardreader_link-width"].map { ValueSample(.cardReader, [$0], "Off") }

    let adapter: [String: ProfileValue] = [
        "spethernet_product_name": .string("USB 10/100/1000 LAN"),
        "spethernet_max_link_speed": .string("ethernet_speed_1000")
    ]
    samples += ["spethernet_usb_device", "spethernet_pcie", "spethernet_builtin"].map {
        ValueSample(.ethernet, ["spethernet_bus"], $0, siblings: adapter)
    }
    samples.append(ValueSample(.ethernet, ["spethernet_max_link_speed"], "ethernet_speed_1000", siblings: adapter))
    samples += ["high_speed", "super_speed", "super_speed_plus"].map {
        ValueSample(.ethernet, ["spethernet_usb_device_speed"], $0, siblings: adapter)
    }

    return samples
}()

private let settingsValueSamples: [ValueSample] = {
    var samples: [ValueSample] = ["black_on_white", "white_on_black"].map {
        ValueSample(.universalAccess, ["display"], $0)
    }

    samples += ["zoom_full_screen", "zoom_split_screen", "zoom_in_window", "zoom_picture_in_picture"].map {
        ValueSample(.universalAccess, ["zoomMode"], $0)
    }
    for field in ["voiceover", "sticky_keys", "slow_keys", "mouse_keys", "cursor_mag", "flash_screen", "keyboardZoom", "scrollZoom"] {
        samples += ["on", "off"].map { ValueSample(.universalAccess, [field], $0) }
    }

    for field in ["system_text_direction", "user_text_direction"] {
        samples += ["text_direction_ltr", "text_direction_rtl"].map { ValueSample(.international, [field], $0) }
    }
    for field in ["system_uses_metric_system", "user_uses_metric_system"] {
        samples += ["value_yes", "value_no"].map { ValueSample(.international, [field], $0) }
    }
    samples.append(ValueSample(.international, ["system_country"], "US"))
    samples += ["voice_gender_female", "voice_gender_male"].map { ValueSample(.international, ["user_assistant_voice_gender"], $0) }
    samples += ["Celsius", "Fahrenheit"].map { ValueSample(.international, ["user_temperature_unit"], $0) }
    samples += [
        "gregorian", "buddhist", "chinese", "coptic", "ethiopic", "ethiopic-amete-alem", "hebrew", "indian", "islamic",
        "islamic-civil", "islamic-tbla", "islamic-umalqura", "iso8601", "japanese", "persian", "roc"
    ].map { ValueSample(.international, ["user_calendar"], $0) }

    samples += ["verified", "unsigned", "invalid"].map {
        ValueSample(.configurationProfiles, ["_items", "[]", "spconfigprofile_verification_state"], $0)
    }
    samples += ["Manual", "MDM"].map { ValueSample(.configurationProfiles, ["_items", "[]", "spconfigprofile_install_source"], $0) }
    samples += ["yes", "no"].map { ValueSample(.configurationProfiles, ["_items", "[]", "spconfigprofile_RemovalDisallowed"], $0) }
    samples += ["always", "often", "once"].map { ValueSample(.managedClient, ["_items", "[]", "data_state"], $0) }

    samples += ["idle", "processing", "stopped"].map { ValueSample(.printers, ["_items", "[]", "status"], $0) }
    for field in ["shared", "default", "printersharing", "scanner"] {
        samples += ["yes", "no"].map { ValueSample(.printers, ["_items", "[]", field], $0) }
    }

    samples += ["system_log_description", "sync_diagnostics_log_description"].map {
        ValueSample(.syncServices, ["_items", "[]", "description"], $0)
    }
    samples.append(ValueSample(.syncServices, ["_items", "[]", "summary_of_sync_log"], ""))
    samples.append(ValueSample(.syncServices, ["summary_os_version"], "10.6"))
    for field in ["se_in_restricted_mode", "se_prod_signed"] {
        samples += ["Yes", "No"].map { ValueSample(.secureElement, [field], $0) }
    }

    return samples
}()

struct ValueCatalogTests {
    @Test(arguments: explainedValueSamples)
    func everyKnownValueHasEveryPart(_ sample: ValueSample) throws {
        let explanation = try #require(sample.explain(), "\(sample.testDescription) has no explanation")

        #expect(explanation.status != .unknown)
        #expect(!explanation.summary.isEmpty)
        #expect(explanation.detail?.isEmpty == false, "missing what this result means")
        #expect(explanation.significance?.isEmpty == false, "missing why it matters")
        #expect(explanation.suggestedAction?.isEmpty == false, "missing what to check")
        #expect(explanation.confidence != nil, "missing a source")
    }

    // MARK: - Applications and frameworks

    @Test
    func architectureDependsOnThisMacsProcessor() throws {
        func explain(_ value: String, _ report: ValueReportContext) -> ValueExplanation? {
            valueExplanation(dataType: .applications, path: ["arch_kind"], scalar: .string(value), report: report)
        }

        let intelOnAppleSilicon = try #require(explain("arch_i64", appleSiliconReport))
        let intelOnIntel = try #require(explain("arch_i64", intelReport))
        let armOnIntel = try #require(explain("arch_arm", intelReport))

        #expect(intelOnAppleSilicon.status == .informational)
        #expect(intelOnAppleSilicon.detail?.contains("Rosetta 2") == true)
        #expect(intelOnAppleSilicon.significance?.contains("macOS 27") == true)
        #expect(intelOnIntel.status == .normal)
        #expect(intelOnIntel.detail?.contains("natively") == true)
        #expect(armOnIntel.status == .informational)
        #expect(armOnIntel.detail?.contains("can't run") == true)
        #expect(explain("arch_arm", appleSiliconReport)?.status == .normal)
        #expect(explain("arch_arm_i64", intelReport)?.status == .normal)
        #expect(explain("arch_future", appleSiliconReport)?.status == .unknown)
    }

    @Test
    func frameworksAreNotCalledApps() throws {
        let framework = try #require(valueExplanation(
            dataType: .frameworks,
            path: ["arch_kind"],
            scalar: .string("arch_other")
        ))

        #expect(framework.detail?.contains("frameworks whose main program") == true)
        #expect(framework.confidence?.reasons.isEmpty == false)
    }

    @Test
    func unsignedOriginIsInformationNotAWarning() throws {
        let unknown = try #require(valueExplanation(dataType: .applications, path: ["obtained_from"], scalar: .string("unknown")))

        #expect(unknown.status == .informational)
        #expect(unknown.significance?.contains("doesn't mean it's harmful") == true)
        #expect(valueExplanation(dataType: .applications, path: ["obtained_from"], scalar: .string("somewhere_else"))?.status == .unknown)
    }

    // MARK: - Extensions

    @Test
    func missingDependenciesAreWorthALook() {
        func status(_ value: String) -> ValueStatus? {
            valueExplanation(dataType: .extensions, path: ["spext_hasAllDependencies"], scalar: .string(value))?.status
        }

        #expect(status("spext_satisfied") == .normal)
        #expect(status("spext_incomplete") == .worthReviewing)
        #expect(status("spext_partly") == .unknown)
    }

    @Test
    func intelOnlyGapMattersOnlyOnAnIntelMac() throws {
        let onIntel = try #require(valueExplanation(
            dataType: .extensions,
            path: ["spext_has64BitIntelCode"],
            scalar: .string("spext_no"),
            report: intelReport
        ))
        let onAppleSilicon = try #require(valueExplanation(
            dataType: .extensions,
            path: ["spext_has64BitIntelCode"],
            scalar: .string("spext_no"),
            report: appleSiliconReport
        ))

        #expect(onIntel.detail?.contains("can't load on this Mac") == true)
        #expect(onAppleSilicon.detail?.contains("only for Macs with Apple silicon") == true)
    }

    // MARK: - Network

    @Test
    func pppSubtypesAreToldApart() throws {
        func summary(_ value: String) -> String? {
            valueExplanation(dataType: .network, path: ["type"], scalar: .string(value))?.summary
        }

        #expect(summary("PPP (PPPSerial)")?.contains("serial port") == true)
        #expect(summary("PPP (PPPoE)")?.contains("PPPoE") == true)
        #expect(summary("PPP (L2TP)")?.contains("L2TP") == true)
        #expect(summary("PPP (PPTP)")?.contains("no longer supports") == true)
        #expect(summary("PPP")?.contains("serial port") == false)
        #expect(valueExplanation(dataType: .network, path: ["type"], scalar: .string("PPP (FutureLink)"))?.status == .unknown)
    }

    @Test
    func aProxyThatsOnSaysWhyItMatters() throws {
        let on = try #require(valueExplanation(dataType: .network, path: ["Proxies", "HTTPSEnable"], scalar: .string("yes")))

        #expect(on.significance?.contains("see, log, and filter") == true)
        #expect(on.suggestedAction?.contains("System Settings") == true)
    }

    // MARK: - Firewall

    @Test
    func olderFirewallOffSpellingReadsAsOff() throws {
        let allowAll = try #require(valueExplanation(
            dataType: .firewall,
            path: ["spfirewall_globalstate"],
            scalar: .string("spfirewall_globalstate_allow_all")
        ))

        #expect(allowAll.status == .worthReviewing)
        #expect(allowAll.summary.contains("off"))
    }

    // MARK: - Wi-Fi

    @Test
    func weakWiFiSecurityMattersOnlyForTheCurrentNetwork() throws {
        func explain(_ mode: String, current: Bool) -> ValueExplanation? {
            wifiSecurityExplanation("spairport_security_mode_\(mode)", isCurrentNetwork: current)
        }

        for mode in ["wep40", "wep128", "8021x", "wps", "wpa2_personal_mixed", "wpa2_enterprise_mixed"] {
            #expect(explain(mode, current: true)?.status == .worthReviewing, "\(mode)")
            #expect(explain(mode, current: false)?.status == .informational, "\(mode)")
        }

        let nearby = try #require(explain("none", current: false))
        #expect(nearby.suggestedAction == "Nothing to do unless you plan to join it.")
        #expect(explain("wpa3_personal", current: false)?.status == .normal)
    }

    @Test
    func wiFiStatusSpellingsFromAppleAreRecognized() throws {
        let disassociated = try #require(valueExplanation(
            dataType: .wifi,
            path: ["spairport_status_information"],
            scalar: .string("spairport_status_disassociated")
        ))

        #expect(disassociated.summary == "Wi-Fi is on but not connected to a network.")
        #expect(valueExplanation(dataType: .wifi, path: ["spairport_status_information"], scalar: .string("spairport_status_future"))?.status == .unknown)
    }

    // MARK: - Power

    @Test
    func everyAppleBatteryConditionIsExplained() throws {
        func explain(_ value: String) -> ValueExplanation? {
            valueExplanation(dataType: .power, path: ["sppower_battery_health_info", "sppower_battery_health"], scalar: .string(value))
        }

        #expect(explain("Good")?.status == .normal)
        for value in ["Fair", "Poor", "Check Battery"] {
            #expect(explain(value)?.status == .worthReviewing, "\(value)")
        }
        #expect(explain("Fair")?.detail?.contains("Replace Soon") == true)
        #expect(explain("Check Battery")?.detail?.contains("Service Battery") == true)
        #expect(explain("Excellent")?.status == .unknown)
    }

    // MARK: - Startup and software overview

    @Test
    func installerStartupIsExplained() throws {
        let installer = try #require(valueExplanation(dataType: .software, path: ["boot_mode"], scalar: .string("installer_boot")))

        #expect(installer.status == .informational)
        #expect(installer.detail?.contains("installation CD/DVD") == true)
        #expect(valueExplanation(dataType: .software, path: ["boot_mode"], scalar: .string("network_boot"))?.status == .unknown)
    }

    // MARK: - Hardware

    @Test
    func thunderboltLinkStatesFromAppleAreRecognized() throws {
        let path: [String] = ["_items", "[]", "receptacle_1_tag", "link_status_key"]
        let trained = try #require(valueExplanation(dataType: .thunderbolt, path: path, scalar: .string("trained_link_status")))

        #expect(trained.status == .normal)
        #expect(valueExplanation(dataType: .thunderbolt, path: path, scalar: .string("0x2"))?.status == .unknown)
    }

    @Test
    func olderAppleGPUBusSpellingIsRecognized() {
        #expect(valueExplanation(dataType: .displays, path: ["sppci_bus"], scalar: .string("spdisplays_pcie_device"))?.summary
            == "Connected over PCI Express, as a separate graphics card.")
        #expect(valueExplanation(dataType: .displays, path: ["spdisplays_display_type"], scalar: .string("spdisplays_retinaLCD"))?.summary
            == "Display type: Retina LCD.")
    }

    @Test
    func processorFamilyComesFromTheHardwareOverview() {
        let appleSilicon: [ProfileValue] = [.object(["_name": .string("hardware_overview"), "chip_type": .string("Apple M1")])]
        let intel: [ProfileValue] = [.object(["_name": .string("hardware_overview"), "cpu_type": .string("Quad-Core Intel Core i5")])]

        #expect(processorFamily(inHardwareItems: appleSilicon) == .appleSilicon)
        #expect(processorFamily(inHardwareItems: intel) == .intel)
        #expect(processorFamily(inHardwareItems: [.object(["_name": .string("hardware_overview")])]) == nil)
    }
}

/// Values from drives, cards, disc drives, and Bluetooth accessories that the
/// inventory Mac didn't have.
struct DriveAndAccessoryValueTests {
    // MARK: - Serial ATA drives and cards

    @Test
    func aMemoryCardIsExplainedLikeAnyOtherDrive() throws {
        let card: [String] = ["_items", "[]"]
        let volume: [String] = card + ["volumes", "[]"]

        let smart = try #require(valueExplanation(dataType: .cardReader, path: card + ["smart_status"], scalar: .string("Not Supported")))
        let content = try #require(valueExplanation(dataType: .cardReader, path: volume + ["iocontent"], scalar: .string("Windows_FAT_32")))
        let format = try #require(valueExplanation(dataType: .cardReader, path: volume + ["file_system"], scalar: .string("MS-DOS FAT32")))

        #expect(smart.status == .informational)
        #expect(content.summary.contains("FAT32"))
        #expect(format.summary.contains("4 GB"))
        #expect(valueExplanation(dataType: .cardReader, path: card + ["removable_media"], scalar: .string("yes"))?.summary.contains("memory card") == true)
    }

    @Test
    func aFailingSerialATADriveIsWorthALook() {
        let drive: [String] = ["_items", "[]"]

        #expect(valueExplanation(dataType: .serialATA, path: drive + ["smart_status"], scalar: .string("Failing"))?.status == .worthReviewing)
        #expect(valueExplanation(dataType: .serialATA, path: drive + ["smart_status"], scalar: .string("Verified"))?.status == .normal)
    }

    @Test
    func aSATALinkSlowerThanItsPortIsPointedOut() throws {
        func explain(_ negotiated: String, port: String?) -> ValueExplanation? {
            let siblings: [String: ProfileValue] = port.map { ["spsata_portspeed": ProfileValue.string($0)] } ?? [:]
            return valueExplanation(dataType: .serialATA, path: ["spsata_negotiatedlinkspeed"], scalar: .string(negotiated), siblings: siblings)
        }

        let slower = try #require(explain("3 Gigabit", port: "6 Gigabit"))
        #expect(slower.status == .informational)
        #expect(slower.summary.contains("slower"))
        #expect(explain("3 Gigabit", port: "3 Gigabit")?.status == .normal)
        #expect(explain("6 Gigabit", port: nil)?.summary.contains("SATA III") == true)
        #expect(explain("12 Gigabit", port: nil)?.status == .unknown)
    }

    @Test
    func applesPCIExpressSSDControllerIsMarkedAsAnInference() throws {
        let pci = try #require(valueExplanation(dataType: .serialATA, path: ["spsata_physical_interconnect"], scalar: .string("PCI")))

        #expect(pci.confidence?.reasons.isEmpty == false)
        #expect(valueExplanation(dataType: .serialATA, path: ["spsata_linkspeed"], scalar: .string("5.0 GT/s"))?.summary.contains("PCI Express 2") == true)
        #expect(valueExplanation(dataType: .serialATA, path: ["spsata_linkwidth"], scalar: .string("x2"))?.summary.contains("2 PCI Express lanes") == true)
        #expect(valueExplanation(dataType: .serialATA, path: ["spsata_linkwidth"], scalar: .string("wide"))?.status == .unknown)
    }

    // MARK: - Disc drives

    @Test
    func discFormatListsAreSpelledOut() throws {
        let dvd = try #require(valueExplanation(dataType: .discBurning, path: ["device_dvdwrite"], scalar: .string("-R, -R DL, +RW")))
        let cd = try #require(valueExplanation(dataType: .discBurning, path: ["device_cdwrite"], scalar: .string("-R, -RW")))

        #expect(dvd.summary == "The drive can write DVD-R, DVD-R DL, and DVD+RW.")
        #expect(cd.summary == "The drive can write CD-R and CD-RW.")
        #expect(valueExplanation(dataType: .discBurning, path: ["device_dvdwrite"], scalar: .string("-R, +HD"))?.status == .unknown)
        #expect(valueExplanation(dataType: .discBurning, path: ["device_strategies"], scalar: .string("CD-TAO, HD-DAO"))?.status == .unknown)
    }

    @Test
    func aDriveMacOSCantBurnWithIsInformation() {
        func status(_ value: String) -> ValueStatus? {
            valueExplanation(dataType: .discBurning, path: ["burn_support"], scalar: .string(value))?.status
        }

        #expect(status("DRDeviceSupportLevelAppleShipping") == .normal)
        #expect(status("DRDeviceSupportLevelUnsupported") == .informational)
        #expect(status("DRDeviceSupportLevelSomethingElse") == .unknown)
        #expect(valueExplanation(dataType: .discBurning, path: ["device_media"], scalar: .string("media_cdr"))?.status == .unknown)
    }

    // MARK: - Bluetooth accessories

    @Test
    func aNearlyEmptyAccessoryBatteryIsWorthALook() {
        func explain(_ field: String, _ value: String) -> ValueExplanation? {
            valueExplanation(dataType: .bluetooth, path: ["device_connected", "[]", "Example Earbuds", field], scalar: .string(value))
        }

        #expect(explain("device_batteryLevelLeft", "8%")?.status == .worthReviewing)
        #expect(explain("device_batteryLevelLeft", "8%")?.summary.contains("left earbud") == true)
        #expect(explain("device_batteryLevelCase", "18%")?.status == .informational)
        #expect(explain("device_batteryLevelMain", "85%")?.status == .normal)
        #expect(explain("device_batteryLevelMain", "85")?.status == .unknown)
        #expect(explain("device_batteryLevelMain", "140%")?.status == .unknown)
    }

    @Test
    func accessoryTypesAreNotGuessed() {
        let path: [String] = ["device_not_connected", "[]", "Example Accessory", "device_minorType"]

        #expect(valueExplanation(dataType: .bluetooth, path: path, scalar: .string("Keyboard"))?.summary == "A keyboard.")
        #expect(valueExplanation(dataType: .bluetooth, path: path, scalar: .string("Toaster"))?.status == .unknown)
    }

    @Test
    func serviceListsNameWhatTheAppDoesntRecognize() throws {
        let path: [String] = ["device_connected", "[]", "Example Accessory", "device_services"]
        let mixed = try #require(valueExplanation(dataType: .bluetooth, path: path, scalar: .string("0x1 < A2DP XYZ >")))
        let apple = try #require(valueExplanation(dataType: .bluetooth, path: path, scalar: .string("0x2 < AACP GATT >")))

        #expect(mixed.summary == "This accessory supports stereo audio (A2DP).")
        #expect(mixed.detail?.contains("XYZ") == true)
        #expect(mixed.confidence == .observed)
        #expect(apple.confidence?.reasons.isEmpty == false)
        #expect(valueExplanation(dataType: .bluetooth, path: path, scalar: .string("0x3 < XYZ >"))?.status == .unknown)
        #expect(valueExplanation(dataType: .bluetooth, path: path, scalar: .string("none"))?.status == .unknown)
    }

    @Test
    func anUnknownPartitionTypeOnASerialATADriveIsNotGuessed() {
        let volume: [String] = ["_items", "[]", "volumes", "[]"]

        #expect(valueExplanation(dataType: .serialATA, path: volume + ["iocontent"], scalar: .string("Linux_Swap"))?.status == .unknown)
    }
}
