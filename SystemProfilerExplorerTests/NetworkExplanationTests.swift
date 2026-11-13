import Foundation
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
    func networkMountPointsRemainExactAndParticipateInPrivacyReview() throws {
        let data: Data = Data(
            #"{"SPNetworkVolumeDataType":[{"spnetworkvolume_fsmtnonname":"/Volumes/Example_Share","spnetworkvolume_automounted":false}]}"#.utf8
        )
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            data,
            importedAt: Date(timeIntervalSince1970: 3_000)
        )
        let section: SystemProfilerSection = try #require(report.sections.first)
        guard case let .object(volume) = try #require(section.items.first),
              case let .string(mountPoint)? = volume["spnetworkvolume_fsmtnonname"] else {
            Issue.record("The imported network mount point must remain a string.")
            return
        }
        let presentation: FieldPresentation = fieldPresentation(
            dataType: section.dataType,
            path: ["spnetworkvolume_fsmtnonname"],
            scalar: .string(mountPoint)
        )
        let field: FieldExplanation = try #require(presentation.explanation)

        #expect(presentation.title == "Network Volume Mount Point")
        #expect(presentation.rawValue == "/Volumes/Example_Share")
        #expect(presentation.sourcePath == "SPNetworkVolumeDataType.spnetworkvolume_fsmtnonname")
        #expect(field.privacy != nil)

        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)
        let privacyResult: ReportQueryResult = try index.queryResult(
            for: FindingQuery(text: mountPoint, filter: .privacy)
        )
        #expect(index.summary.privacyFindingCount == 1)
        #expect(privacyResult.findingCount == 1)

        let full: ReportExportEnvelope = try decodeReportExport(encodeReportExport(makeFullReportExport(report)))
        #expect(full.report.sections == report.sections)
        let redacted: String = String(decoding: try encodeReportExport(makeRedactedReportExport(report)), as: UTF8.self)
        let anonymized: String = String(decoding: try encodeAnonymizedSample(makeAnonymizedSample(report)), as: UTF8.self)
        #expect(!redacted.contains(mountPoint))
        #expect(!anonymized.contains(mountPoint))
    }

    @Test(arguments: [
        ProfileScalar.string("yes"), .string("no"), .string("true"), .string("false"),
        .string("on"), .string("off"), .string("1"), .string("0"),
        .string("YES"), .string("FaLsE"), .boolean(true), .boolean(false),
        .integer(1), .integer(0)
    ])
    func networkAutomountValuesDescribeTheFlagWithoutIdentifyingAnActor(_ scalar: ProfileScalar) throws {
        let result: ValueExplanation = try #require(valueExplanation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_automounted"],
            scalar: scalar
        ))

        #expect(result.status == .informational)
        #expect(result.detail?.contains("does not identify") == true)
        #expect(result.suggestedAction?.contains("mount configuration") == true)
    }

    @Test(arguments: [
        ProfileScalar.string(""), .string("maybe"), .string("unknown_yes"),
        .string("not_automounted_no"), .string("yes garbage"), .string("no\nextra"),
        .string("2"), .integer(-1), .integer(2), .decimal(0.5), .decimal(1), .null
    ])
    func malformedNetworkAutomountValuesStayUnexplained(_ scalar: ProfileScalar) throws {
        let result: ValueExplanation = try #require(valueExplanation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_automounted"],
            scalar: scalar
        ))

        #expect(result.status == .unknown)
        #expect(result.confidence == nil)
        #expect(fieldPresentation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_automounted"],
            scalar: scalar
        ).rawValue == scalar.rawDescription)
    }

    @Test(arguments: ["smbfs", "nfs"])
    func networkFilesystemValuesExplainTheFamilyWithoutClaimingConnectionSecurity(_ value: String) throws {
        let result: ValueExplanation = try #require(valueExplanation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_fstypename"],
            scalar: .string(value)
        ))

        #expect(result.status == .informational)
        #expect(result.confidence == .documented)
        #expect(result.summary.contains(value == "smbfs" ? "SMB" : "NFS"))
        #expect(result.significance?.contains("protocol version") == true)
        #expect(result.significance?.contains("encryption") == true)
        #expect(result.significance?.contains("server trust") == true)
        #expect(result.significance?.contains("file activity") == true)
        #expect(result.suggestedAction?.contains("Network Volume Source") == true)
    }

    @Test(arguments: [
        ProfileScalar.string(""), .string("SMB"), .string("NFS"), .string("smb"),
        .string("nfs4"), .string("smbfs_extra"), .string("smbfs,nfs"),
        .string(" smbfs"), .string("nfs "), .string("nfs\n"),
        .string("smbfs\u{200B}"), .string("nfs\u{0000}"), .string("apfs"),
        .string("ExamplePrivateVolume"), .boolean(false), .integer(0), .null
    ])
    func unknownNetworkFilesystemValuesStayUnexplainedAndExact(_ scalar: ProfileScalar) throws {
        let result: ValueExplanation = try #require(valueExplanation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_fstypename"],
            scalar: scalar
        ))

        #expect(result.status == .unknown)
        #expect(result.confidence == nil)
        #expect(fieldPresentation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_fstypename"],
            scalar: scalar
        ).rawValue == scalar.rawDescription)
    }

    @Test(arguments: [
        "smbfs", "nfs", "ExamplePrivateVolume", "smbfs_extra", "future_fs_token",
        " smbfs", "NFS", "unknown_yes", "true", "nfs\u{0000}"
    ])
    func networkFilesystemSamplesKeepOnlyKnownTypesAndFullExportsRemainExact(_ value: String) throws {
        let report: SystemProfilerReport = SystemProfilerReport(
            sections: [SystemProfilerSection(
                dataType: .networkVolumes,
                items: [.object([
                    "_name": .string("ExamplePrivateVolume"),
                    "spnetworkvolume_fstypename": .string(value),
                    "spnetworkvolume_fsmtnonname": .string("/Volumes/Example_Share"),
                    "spnetworkvolume_mntfromname": .string("//example.invalid/Example_Share")
                ])]
            )],
            commandArguments: [],
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 3_000),
            completedAt: Date(timeIntervalSince1970: 3_000)
        )
        let full: ReportExportEnvelope = try decodeReportExport(encodeReportExport(makeFullReportExport(report)))
        #expect(full.report.sections == report.sections)

        let sample: [String: [ProfileValue]] = makeAnonymizedSample(report)
        let expectedType: String = ["smbfs", "nfs"].contains(value) ? value : anonymizedSampleRemovedValue
        #expect(sample[SystemProfilerDataType.networkVolumes.rawValue] == [.object([
            "_name": .string(anonymizedSampleRemovedValue),
            "spnetworkvolume_fstypename": .string(expectedType),
            "spnetworkvolume_fsmtnonname": .string(anonymizedSampleRemovedValue),
            "spnetworkvolume_mntfromname": .string(anonymizedSampleRemovedValue)
        ])])
        let reopened: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            encodeAnonymizedSample(sample),
            importedAt: Date(timeIntervalSince1970: 3_000)
        )
        #expect(makeAnonymizedSample(reopened) == sample)

        let redacted: ReportExportEnvelope = try decodeReportExport(encodeReportExport(makeRedactedReportExport(report)))
        #expect(redacted.report.sections.first?.items == [.object([
            "_name": .string(redactedProfileValue),
            "spnetworkvolume_fstypename": .string(redactedProfileValue),
            "spnetworkvolume_fsmtnonname": .string(redactedProfileValue),
            "spnetworkvolume_mntfromname": .string(redactedProfileValue)
        ])])
        #expect(valueExplanation(
            dataType: .networkVolumes,
            path: ["spnetworkvolume_fstypename"],
            scalar: .string(redactedProfileValue)
        ) == nil)
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
