import Foundation

func wifiExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = semanticNetworkField(path)

    return switch field {
    case "spairport_caps_airdrop":
        networkBooleanExplanation(
            title: "AirDrop Capability",
            meaning: "This reports whether the Wi‑Fi hardware and macOS networking stack support the peer-to-peer wireless features used by AirDrop.",
            significance: "AirDrop capability allows nearby Apple devices to discover and transfer items when the user enables appropriate sharing settings.",
            interpretation: "Capability does not prove that AirDrop was enabled, discoverable, used, or that any file transfer occurred.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "spairport_caps_autounlock":
        networkBooleanExplanation(
            title: "Auto Unlock Capability",
            meaning: "This reports whether the wireless hardware supports Apple's proximity features used for Auto Unlock with compatible devices.",
            significance: "The capability is one prerequisite for workflows that use a nearby authorized Apple device to unlock the Mac.",
            interpretation: "Capability does not prove that Auto Unlock is configured, that a watch or phone is paired, or that an unlock occurred.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "spairport_caps_wow":
        networkBooleanExplanation(
            title: "Wake on Wireless",
            meaning: "This reports whether the Wi‑Fi hardware supports waking or maintaining network availability for supported sleep-time network activity.",
            significance: "The capability can support network services, management, and background tasks while the Mac would otherwise be asleep.",
            interpretation: "Capability is not the same as an enabled power policy and does not prove that a wireless wake occurred.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "spairport_status_information":
        FieldExplanation(
            title: "Wi‑Fi Status",
            meaning: "This is the operating status reported for the Wi‑Fi interface at collection time.",
            significance: "It establishes whether the interface was available and provides context for current-network fields.",
            interpretation: "An active interface does not prove Internet connectivity, recent traffic, or a successful connection to every reported nearby network.",
            privacy: nil
        )

    case "spairport_supported_phymodes":
        FieldExplanation(
            title: "Supported Wi‑Fi Modes",
            meaning: "This lists the IEEE 802.11 physical-layer generations supported by the Wi‑Fi hardware and driver.",
            significance: "Supported modes constrain the radio features, channel widths, modulation methods, and peak rates the Mac can negotiate with an access point.",
            interpretation: "Support does not mean the current connection uses the newest mode or reaches its theoretical speed. Access-point capability, channel conditions, regulation, and signal quality also matter.",
            privacy: nil
        )

    case "spairport_wireless_card_type":
        FieldExplanation(
            title: "Wi‑Fi Card",
            meaning: "This identifies the Wi‑Fi controller or card family reported by macOS.",
            significance: "The hardware family provides context for supported standards, firmware, antenna behavior, and model-specific diagnostics.",
            interpretation: "The controller name does not measure current performance, firmware integrity, signal quality, or network activity.",
            privacy: nil
        )

    case "spairport_wireless_country_code":
        FieldExplanation(
            title: "Wi‑Fi Regulatory Country",
            meaning: "This is the regulatory country code currently associated with the Wi‑Fi interface.",
            significance: "Country rules influence which channels, channel widths, and transmit-power limits the radio may use.",
            interpretation: "The code is radio-regulatory context, not reliable proof of the Mac's physical location or the user's residence. Access-point information and system policy can influence it.",
            privacy: "A country code provides coarse regional context. Review it before sharing if location information is sensitive."
        )

    case "spairport_wireless_locale":
        FieldExplanation(
            title: "Wi‑Fi Locale",
            meaning: "This is locale or regulatory-domain metadata reported by the Wi‑Fi stack.",
            significance: "It helps explain channel availability and radio behavior under the active regulatory configuration.",
            interpretation: "The value is implementation metadata and should not be treated as precise location evidence.",
            privacy: "Locale metadata can provide coarse regional context. Review it before public sharing."
        )

    case "spairport_wireless_firmware_version":
        FieldExplanation(
            title: "Wi‑Fi Firmware Version",
            meaning: "This is the firmware revision reported by the Wi‑Fi controller.",
            significance: "Firmware participates in radio control, association, power management, and security behavior and can help correlate model-specific issues.",
            interpretation: "The version string alone does not establish that firmware is current, vulnerable, or modified. Authoritative comparison requires the exact Mac model and macOS build.",
            privacy: nil
        )

    case "spairport_wireless_mac_address":
        FieldExplanation(
            title: "Wi‑Fi Hardware Address",
            meaning: "This is the hardware address reported for the Mac's Wi‑Fi interface.",
            significance: "Local wireless networks use a MAC address when associating and delivering link-layer frames.",
            interpretation: "macOS can use private per-network addresses, so this value may not be the address presented to every access point. It does not prove connection history or device ownership.",
            privacy: "A Wi‑Fi address can identify or correlate the Mac on local networks. Redact it from public screenshots and reports."
        )

    case "spairport_supported_channels":
        FieldExplanation(
            title: "Supported Wi‑Fi Channel",
            meaning: "This is one radio channel the current hardware and regulatory configuration report as supported.",
            significance: "The supported set determines which access-point channels the Mac can use in the 2.4 GHz, 5 GHz, or 6 GHz bands.",
            interpretation: "A listed channel is capability, not evidence that the Mac transmitted on it or that a nearby network was present.",
            privacy: nil
        )

    case "spairport_network_channel":
        FieldExplanation(
            title: "Wi‑Fi Channel",
            meaning: "This is the radio channel reported for the current or observed wireless network.",
            significance: "Channel selection affects interference, available spectrum, regulatory behavior, and potential channel width.",
            interpretation: "A channel observation does not prove association or traffic when it belongs to a nearby-network record. Channel conditions can change quickly.",
            privacy: nil
        )

    case "spairport_network_country_code":
        FieldExplanation(
            title: "Network Country Code",
            meaning: "This is the regulatory country code advertised or associated with the wireless network.",
            significance: "It can influence which channels and power rules clients apply while using the network.",
            interpretation: "An advertised country code is not authoritative location evidence and can be missing, incorrect, or inherited from access-point configuration.",
            privacy: "The code supplies coarse regional context. Review it before public sharing."
        )

    case "spairport_network_mcs":
        FieldExplanation(
            title: "Wi‑Fi MCS Index",
            meaning: "The modulation and coding scheme index summarizes how the wireless link encodes data under the current radio conditions.",
            significance: "MCS reflects a combination of modulation, coding rate, and spatial-stream behavior that influences link throughput.",
            interpretation: "A single MCS value is a point-in-time link parameter, not an Internet speed test. It can change rapidly with signal quality, interference, movement, and power state.",
            privacy: nil
        )

    case "spairport_network_phymode":
        FieldExplanation(
            title: "Wi‑Fi Physical Mode",
            meaning: "This identifies the 802.11 physical-layer mode reported for the current or observed network.",
            significance: "The mode provides context for supported radio features, channel widths, efficiency, and theoretical rate ranges.",
            interpretation: "The advertised or negotiated mode does not guarantee a particular throughput, latency, or connection quality.",
            privacy: nil
        )

    case "spairport_network_rate":
        FieldExplanation(
            title: "Wi‑Fi Transmit Rate",
            meaning: "This is the link rate reported by the Wi‑Fi stack for the current connection.",
            significance: "It provides a point-in-time indication of the radio data rate selected between the Mac and access point.",
            interpretation: "Link rate is not application throughput or Internet speed. Protocol overhead, retransmissions, interference, congestion, routing, and the upstream connection reduce real performance.",
            privacy: nil
        )

    case "spairport_network_type":
        FieldExplanation(
            title: "Wi‑Fi Network Type",
            meaning: "This describes the wireless network topology or operating type reported by the Wi‑Fi stack.",
            significance: "It helps distinguish infrastructure networks from peer-to-peer or other wireless arrangements.",
            interpretation: "The type does not authenticate the network, identify its operator, or prove that the Mac joined it.",
            privacy: nil
        )

    case "spairport_security_mode":
        FieldExplanation(
            title: "Wi‑Fi Security Mode",
            meaning: "This reports the authentication and link-encryption mode advertised or negotiated by the wireless network.",
            significance: "The mode affects how the Mac authenticates the access point and protects wireless frames from casual local interception.",
            interpretation: "A strong label does not authenticate the network owner, protect traffic beyond the access point, or prove correct configuration. For nearby-network entries it is an observation, not a connection record.",
            privacy: nil
        )

    case "spairport_signal_noise":
        FieldExplanation(
            title: "Wi‑Fi Signal and Noise",
            meaning: "This reports received signal strength and background noise measurements for the current or observed wireless network.",
            significance: "The difference between signal and noise helps explain link stability, modulation choices, retransmissions, and performance.",
            interpretation: "Measurements are point-in-time and hardware-specific. Nearby-network values do not prove association, and good radio signal does not guarantee Internet reachability.",
            privacy: nil
        )

    case "spairport_corewlan_version":
        wifiSoftwareExplanation(
            title: "CoreWLAN Version",
            meaning: "This is the version of Apple's CoreWLAN framework used by software to inspect and manage Wi‑Fi."
        )
    case "spairport_corewlankit_version":
        wifiSoftwareExplanation(
            title: "CoreWLANKit Version",
            meaning: "This is the version of supporting Apple Wi‑Fi framework components reported by system_profiler."
        )
    case "spairport_diagnostics_version":
        wifiSoftwareExplanation(
            title: "Wireless Diagnostics Version",
            meaning: "This is the version of Apple's wireless diagnostics component available on the Mac."
        )
    case "spairport_extra_version":
        wifiSoftwareExplanation(
            title: "Wi‑Fi Extra Version",
            meaning: "This is version metadata for an Apple Wi‑Fi user-interface or support component."
        )
    case "spairport_family_version":
        wifiSoftwareExplanation(
            title: "Wi‑Fi Family Version",
            meaning: "This is version metadata for the macOS Wi‑Fi framework family."
        )
    case "spairport_profiler_version":
        wifiSoftwareExplanation(
            title: "Wi‑Fi Profiler Version",
            meaning: "This is the version of the component that supplies Wi‑Fi information to system_profiler."
        )
    case "spairport_utility_version":
        wifiSoftwareExplanation(
            title: "Wi‑Fi Utility Version",
            meaning: "This is version metadata for an Apple Wi‑Fi utility component installed with macOS."
        )

    default:
        nil
    }
}

private func wifiSoftwareExplanation(title: String, meaning: String) -> FieldExplanation {
    FieldExplanation(
        title: title,
        meaning: meaning,
        significance: "The version can help correlate Wi‑Fi behavior with a particular macOS build and diagnose component mismatches after updates.",
        interpretation: "Component version strings are not security or integrity verdicts. Reliable comparison requires the installed macOS build and authoritative Apple release information.",
        privacy: nil
    )
}
