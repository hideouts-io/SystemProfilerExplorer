import Foundation

// MARK: - Network services

// Sources: hardware and service types are System Configuration constants
// (SCSchemaDefinitions.h and SCNetworkConfiguration.h): Ethernet, AirPort, FireWire and
// Modem for hardware; Ethernet, IEEE80211, Bridge, Bond, VLAN, 6to4, IPSec, PPP and VPN
// for service types, with PPP subtypes PPPSerial, PPPoE, L2TP and PPTP. Configuration
// methods are the IPv4 and IPv6 ConfigMethod constants. The values in
// docs/value-inventory.md confirm the spellings used in reports.

let networkValueRules: [ValueRule] = [
    ValueRule(.network, .networkLocation, field: "hardware") { context in
        switch context.reportedValue {
        case "Ethernet":
            .normal(
                "A wired-style connection: a built-in Ethernet port, a USB or Thunderbolt adapter, a Thunderbolt Bridge, or iPhone USB tethering.",
                detail: "macOS uses the Ethernet type for any interface that behaves like a network port, not only a physical Ethernet socket.",
                why: "Wired connections are usually faster and steadier than Wi-Fi.",
                action: "Nothing to do. The service's name and interface say which port or adapter it is.",
                confidence: .documented
            )
        case "AirPort":
            .normal(
                "Wi-Fi. “AirPort” is the name macOS uses internally for Wi-Fi.",
                detail: "This service uses the Mac's Wi-Fi hardware; the name comes from Apple's original Wi-Fi products.",
                why: "The Wi-Fi network the Mac joins and its security apply to this service.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "FireWire":
            .info(
                "Networking over FireWire, used to connect older Macs with a FireWire cable.",
                detail: "Only older Macs have FireWire ports. The service carries traffic only while a FireWire cable connects two computers.",
                why: "It does nothing on its own, and it isn't used for internet access.",
                action: "Nothing to do. You can remove the service in System Settings › Network if you never use it.",
                confidence: .documented
            )
        case "Modem":
            modemServiceExplanation(context)
        default:
            nil
        }
    },

    ValueRule(.network, .networkLocation, field: "type") { context in
        serviceTypeExplanation(context.reportedValue)
    },

    ValueRule(.network, .networkLocation, field: "ConfigMethod") { context in
        ipConfigurationExplanation(context.reportedValue, family: context.parentKey)
    }
]

private let vpnWhy: String =
    "Traffic goes through the VPN only while it's connected, and whoever runs the VPN server can see the traffic it carries."

/// Explains a network service type such as `Ethernet`, `PPP (PPPSerial)`, or `VPN (com.example.vpn)`.
func serviceTypeExplanation(_ value: String) -> ValueExplanation? {
    switch value {
    case "Ethernet":
        return .normal(
            "An Ethernet network service.",
            detail: "It carries traffic over an Ethernet-type interface: a port, an adapter, or a USB link that behaves like one.",
            why: "Wired connections are usually faster and steadier than Wi-Fi.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "AirPort", "IEEE80211":
        return .normal(
            "A Wi-Fi network service.",
            detail: "It carries traffic over the Mac's Wi-Fi hardware. macOS names Wi-Fi “AirPort” or “IEEE80211” internally.",
            why: "Wi-Fi settings, such as which networks the Mac joins, belong to this service.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "Bridge":
        return .info(
            "A network bridge, such as Thunderbolt Bridge, which connects Macs directly over a cable.",
            detail: "A bridge joins several interfaces into one network. macOS creates Thunderbolt Bridge on Macs with Thunderbolt ports.",
            why: "It lets two Macs connected by a Thunderbolt cable share files quickly without a router. It doesn't affect internet access.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "Bond":
        return .info(
            "A link aggregate (bond) that combines several Ethernet ports into one connection.",
            detail: "Traffic is spread across the combined ports, and the connection keeps working if one of them fails.",
            why: "Bonds are set up on purpose, usually on servers, for speed or redundancy.",
            action: "Nothing to do if you set it up. Otherwise, review it under Manage Virtual Interfaces in System Settings › Network.",
            confidence: .documented
        )
    case "VLAN":
        return .info(
            "A virtual LAN (VLAN) on an Ethernet port.",
            detail: "It tags traffic so it joins a separate logical network over the same cable.",
            why: "VLANs are set up on purpose, usually on managed networks.",
            action: "Nothing to do if your network uses VLANs. Otherwise, review it under Manage Virtual Interfaces in System Settings › Network.",
            confidence: .documented
        )
    case "6to4":
        return .info(
            "A 6to4 tunnel that carries IPv6 traffic over IPv4.",
            detail: "6to4 was a way to reach IPv6 sites before internet providers offered IPv6 directly.",
            why: "6to4 is obsolete and rarely works today, so it's usually a leftover setting.",
            action: "Remove the service in System Settings › Network unless you set it up on purpose.",
            confidence: .documented
        )
    case "IPSec":
        return .info(
            "An IPSec VPN service (Cisco IPSec).",
            detail: "macOS's built-in VPN client uses this service to connect to an IPSec VPN server.",
            why: vpnWhy,
            action: "Nothing to do if you use this VPN. If you don't recognize it, review it in System Settings › VPN.",
            confidence: .documented
        )
    default:
        break
    }

    if value.hasPrefix("PPP") {
        return pppServiceExplanation(subtype: parenthesizedPart(of: value))
    }

    if value.hasPrefix("VPN") {
        let provider: String? = parenthesizedPart(of: value)

        return .info(
            "A VPN service\(provider.map { " provided by the app \($0)" } ?? "").",
            detail: "The VPN app adds this service. It routes traffic through the VPN only while it's connected.",
            why: vpnWhy,
            action: "Nothing to do if you use this VPN. If you don't recognize it, check the app it names and remove the VPN in System Settings › VPN.",
            confidence: .documented
        )
    }

    return nil
}

/// Returns the text inside the parentheses of values such as `PPP (PPPSerial)`.
private func parenthesizedPart(of value: String) -> String? {
    guard let open = value.firstIndex(of: "("), value.hasSuffix(")") else {
        return nil
    }

    let inner: String = String(value[value.index(after: open)..<value.index(before: value.endIndex)])
    return inner.isEmpty ? nil : inner
}

private func pppServiceExplanation(subtype: String?) -> ValueExplanation? {
    switch subtype {
    case "PPPSerial"?, nil:
        .info(
            "A dial-up style connection (PPP)\(subtype == nil ? "" : " over a serial port").",
            detail: "macOS creates these for modems and for USB devices that present a serial port.",
            why: "It carries traffic only while a connection is configured and started, so on its own it does nothing.",
            action: "Nothing to do if you use it. If you don't, you can remove it in System Settings › Network.",
            confidence: .documented
        )
    case "PPPoE"?:
        .info(
            "A PPP over Ethernet (PPPoE) connection, used by some DSL and fiber providers.",
            detail: "The Mac signs in to the internet provider itself over Ethernet, instead of leaving that to a router.",
            why: "Internet access through this service depends on the provider's account name and password stored in it.",
            action: "Nothing to do if your provider needs PPPoE on this Mac. In most homes the router handles it instead.",
            confidence: .documented
        )
    case "L2TP"?:
        .info(
            "An L2TP over IPSec VPN service.",
            detail: "macOS's built-in VPN client uses this service to connect to an L2TP VPN server.",
            why: vpnWhy,
            action: "Nothing to do if you use this VPN. If you don't recognize it, review it in System Settings › VPN.",
            confidence: .documented
        )
    case "PPTP"?:
        .info(
            "A PPTP VPN service, an old VPN type macOS no longer supports.",
            detail: "macOS removed its PPTP client in macOS Sierra, so this service can't connect.",
            why: "PPTP's encryption can be broken, which is why Apple removed it.",
            action: "Remove the service, and ask the VPN's administrator for a supported VPN type.",
            confidence: .documented
        )
    default:
        nil
    }
}

/// Explains a network service with Modem hardware using the rest of its record and, when
/// collected, the USB device list. Most modern "modems" are USB serial devices such as dev boards.
func modemServiceExplanation(_ context: ValueContext) -> ValueExplanation {
    let serviceName: String = context.sibling("_name") ?? ""
    let interface: String = context.sibling("interface") ?? ""
    let serviceType: String = context.sibling("type") ?? ""
    let deviceFamily: String? = knownSerialDeviceFamily(serviceName)
    var reasons: [String] = []

    if interface.hasPrefix("usbmodem") {
        reasons.append("Its interface name starts with “usbmodem”, which macOS uses for USB serial (CDC-ACM) ports.")
    }

    if serviceType.contains("Serial") {
        reasons.append("Its type is a dial-up (PPP) connection over a serial port.")
    }

    if let deviceFamily {
        reasons.append("The service name “\(serviceName)” matches \(deviceFamily).")
    }

    guard !reasons.isEmpty else {
        return .info(
            "A modem-type network service, used for dial-up or serial connections.",
            detail: "macOS adds a service like this for a phone-line modem, or for a device that presents itself as one.",
            why: "It does nothing unless a connection is configured and started.",
            action: "Nothing to do if you use it. Otherwise, you can remove the service in System Settings › Network."
        )
    }

    let summary: String = deviceFamily.map {
        "A USB serial device, probably \($0), not a phone-line or cellular modem."
    } ?? "A USB serial device, not a phone-line or cellular modem."

    var detail: String = "macOS adds a network service like this when a device with a USB serial port is plugged in. The service stays in Network settings after the device is unplugged, and it does nothing unless someone configures a connection."

    if let usbDeviceNames = context.report.usbDeviceNames {
        let isConnected: Bool = usbDevice(named: serviceName, in: usbDeviceNames)
        detail += isConnected
            ? " A matching USB device is connected right now."
            : " No matching USB device is connected right now, so this service is left over from an earlier connection."
    } else {
        detail += " Scan Hardware to check whether the device is connected right now."
    }

    return .info(
        summary,
        detail: detail,
        why: "It can't reach the internet by itself, and it sends no traffic unless a connection is set up for it.",
        action: "Nothing, if you use such a device. If you don't recognize it, you can remove the service in System Settings › Network.",
        confidence: .likely(reasons: reasons)
    )
}

private let serialDeviceFamilies: [(marker: String, description: String)] = [
    ("nrf5", "a Nordic Semiconductor nRF5 board or dongle"),
    ("nrf9", "a Nordic Semiconductor nRF9 board"),
    ("arduino", "an Arduino board"),
    ("esp32", "an ESP32 board"),
    ("pico", "a Raspberry Pi Pico"),
    ("cp210", "a Silicon Labs USB-to-serial adapter"),
    ("ft232", "an FTDI USB-to-serial adapter"),
    ("ftdi", "an FTDI USB-to-serial adapter"),
    ("ch340", "a CH340 USB-to-serial adapter")
]

func knownSerialDeviceFamily(_ name: String) -> String? {
    // Name the exact Nordic part when the service name includes it, such as "nRF52".
    if let range = name.range(of: #"(?i)\bnrf\d{2}"#, options: .regularExpression) {
        return "a Nordic Semiconductor nRF\(name[range].dropFirst(3)) board or dongle"
    }

    let lowercased: String = name.lowercased()
    return serialDeviceFamilies.first { lowercased.contains($0.marker) }?.description
}

/// Matches a network service name such as "nRF52 USB Product" against USB device names,
/// using the service name's first word so vendor suffixes don't prevent a match.
private func usbDevice(named serviceName: String, in deviceNames: [String]) -> Bool {
    guard let firstWord = serviceName.split(separator: " ").first.map(String.init), firstWord.count >= 3 else {
        return false
    }

    return deviceNames.contains { $0.localizedCaseInsensitiveContains(firstWord) }
}

private let dynamicAddressWhy: String = "The service has an address only while that connection is up."

func ipConfigurationExplanation(_ value: String, family: String?) -> ValueExplanation? {
    switch (family, value) {
    case ("IPv4", "DHCP"):
        .normal(
            "Gets its IP address automatically from the router (DHCP), the usual setup.",
            detail: "The router or another DHCP server gives this service its address, subnet, router, and usually its DNS servers.",
            why: "This is how most home and office networks work, and it avoids two devices using the same address.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case ("IPv4", "Manual"):
        .info(
            "The IP address was entered by hand.",
            detail: "That's intended on some networks. Elsewhere, a mistyped manual address can stop the connection from working.",
            why: "A manual address has to match the network. If it doesn't, or another device uses it too, the connection fails.",
            action: "If this network should configure itself, choose Using DHCP in System Settings › Network.",
            confidence: .documented
        )
    case ("IPv4", "INFORM"):
        .info(
            "Uses a manually entered IP address, with other settings from DHCP.",
            detail: "The address was typed in, and the network's DHCP server supplies the rest, such as DNS servers.",
            why: "It's used when a device needs a fixed address but should still get other settings automatically.",
            action: "Nothing to do if this address was assigned to this Mac.",
            confidence: .documented
        )
    case ("IPv4", "BOOTP"):
        .info(
            "Gets its address from a BOOTP server, an older method used on some managed networks.",
            detail: "BOOTP is the older protocol that DHCP replaced.",
            why: "It's rare today. Outside a managed network that needs it, it's usually an old setting.",
            action: "Unless your network needs BOOTP, choose Using DHCP in System Settings › Network.",
            confidence: .documented
        )
    case ("IPv4", "LinkLocal"):
        .info(
            "Uses only a self-assigned 169.254 address, enough for devices on the same local network.",
            detail: "The service gives itself an address and doesn't ask a router for one.",
            why: "It can reach devices on the same local network, but not the internet.",
            action: "If you need internet access over this service, choose Using DHCP in System Settings › Network.",
            confidence: .documented
        )
    case ("IPv4", "Automatic"):
        .normal(
            "macOS chooses how to get the IP address automatically.",
            detail: "macOS picks the method that fits the connection, usually DHCP.",
            why: "It works on most networks without any setup.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case ("IPv4", "PPP"):
        .info(
            "The IP address is assigned by the dial-up (PPP) connection.",
            detail: "The dial-up, PPPoE, or VPN connection gets its address when it connects.",
            why: dynamicAddressWhy,
            action: "Nothing to do.",
            confidence: .documented
        )
    case ("IPv4", "VPN"):
        .info(
            "The IP address is assigned by the VPN.",
            detail: "The VPN server gives this service its address when the VPN connects.",
            why: dynamicAddressWhy,
            action: "Nothing to do.",
            confidence: .documented
        )
    case ("IPv6", "Automatic"):
        .normal(
            "IPv6 is configured automatically, the default.",
            detail: "The Mac creates its IPv6 addresses from what the router announces, or gets them by DHCPv6.",
            why: "The Mac uses IPv6 whenever the network offers it, with no setup.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case ("IPv6", "LinkLocal"):
        .info(
            "IPv6 uses only a link-local address, for the local network.",
            detail: "The service has only an fe80:: address, which works between devices on the same network.",
            why: "It can't reach IPv6 sites on the internet. IPv4 still works if it's configured.",
            action: "If your network offers IPv6, choose Automatically in System Settings › Network.",
            confidence: .documented
        )
    case ("IPv6", "Manual"):
        .info(
            "The IPv6 address was entered by hand.",
            detail: "The IPv6 address, prefix length, and router were typed in.",
            why: "A manual IPv6 address has to match the network. If it doesn't, IPv6 connections fail.",
            action: "If this network should configure itself, choose Automatically in System Settings › Network.",
            confidence: .documented
        )
    case ("IPv6", "RouterAdvertisement"):
        .normal(
            "IPv6 is configured from the router's announcements.",
            detail: "The Mac builds its IPv6 address from the prefix the router announces.",
            why: "It works on most IPv6 networks without any setup.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case ("IPv6", "6to4"):
        .info(
            "IPv6 is tunneled over IPv4 (6to4).",
            detail: "6to4 carried IPv6 traffic inside IPv4 before internet providers offered IPv6 directly.",
            why: "6to4 is obsolete and rarely works today.",
            action: "Choose Automatically in System Settings › Network unless you set up 6to4 on purpose.",
            confidence: .documented
        )
    default:
        nil
    }
}

// MARK: - Ethernet

let ethernetValueRules: [ValueRule] = [
    ValueRule(.ethernet, field: "spethernet_bus") { context in
        if let device = connectedAppleDevice(context) {
            return .info(
                "A network link to \(device) connected over USB, not a physical Ethernet adapter.",
                detail: "macOS creates links like this for Personal Hotspot over USB and for services such as Finder syncing and Xcode.",
                why: "It appears whenever the device is plugged in and trusted, and goes away when it's unplugged.",
                action: "Nothing to do.",
                confidence: .likely(reasons: appleDeviceLinkReasons(context, device: device))
            )
        }

        let why: String = "How the adapter connects can limit its speed."

        return switch tokenSuffix(context.reportedValue, after: "spethernet_") {
        case "usb_device":
            .info(
                "A USB Ethernet adapter.",
                detail: "The Ethernet port is on an adapter or dock connected over USB.",
                why: "\(why) USB adapters depend on the USB port and cable they use.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "pcie", "pci", "pci_device":
            .info(
                "Connected over PCI Express.",
                detail: "The Ethernet controller is a chip or card connected directly over PCI Express.",
                why: "\(why) PCI Express gives the controller its full speed.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "builtin", "built_in":
            .info(
                "Built into this Mac.",
                detail: "The Ethernet port is part of the Mac itself.",
                why: "\(why) Built-in ports run at their full rated speed.",
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.ethernet, field: "spethernet_max_link_speed") { context in
        guard let megabits = tokenSuffix(context.reportedValue, after: "speed_").flatMap({ Int($0) }) else {
            return nil
        }

        if let device = connectedAppleDevice(context) {
            return .info(
                "Reported as \(ethernetSpeedDescription(megabits: megabits)), a nominal figure for the link to \(device).",
                detail: "Actual speed depends on the USB connection and on the device itself.",
                why: "The figure doesn't describe a real network cable.",
                action: "Nothing to do.",
                confidence: .likely(reasons: appleDeviceLinkReasons(context, device: device))
            )
        }

        return .info(
            "Supports Ethernet speeds up to \(ethernetSpeedDescription(megabits: megabits)).",
            detail: "This is the fastest speed the adapter can use. The actual speed depends on the cable and the router or switch.",
            why: "Your network connection can't be faster than the slowest part of the link.",
            action: "Nothing to do. For full speed, use a cable and switch rated for it.",
            confidence: .documented
        )
    },

    ValueRule(.ethernet, field: "spethernet_usb_device_speed") { context in
        usbLinkExplanation(
            context.reportedValue,
            adapterMegabits: connectedAppleDevice(context) == nil
                ? context.sibling("spethernet_max_link_speed")
                    .flatMap { tokenSuffix($0, after: "speed_") }
                    .flatMap { Int($0) }
                : nil
        )
    }
]

/// Returns "an iPhone" or "an iPad" when an Ethernet entry is really a USB link to one.
private func connectedAppleDevice(_ context: ValueContext) -> String? {
    let product: String = [context.sibling("spethernet_product_name"), context.sibling("_name")]
        .compactMap { $0 }
        .joined(separator: " ")

    if product.localizedCaseInsensitiveContains("iPhone") { return "an iPhone" }
    if product.localizedCaseInsensitiveContains("iPad") { return "an iPad" }
    return nil
}

private func appleDeviceLinkReasons(_ context: ValueContext, device: String) -> [String] {
    var reasons: [String] = ["The entry's product name is \(device.replacingOccurrences(of: "an ", with: ""))."]

    if let driver = context.sibling("spethernet_driver"),
       driver.contains("cdc.ncm") || driver.contains("USBEthernetHost") {
        reasons.append("It uses \(driver), a driver for USB network links rather than an Ethernet chip.")
    }

    return reasons
}

func ethernetSpeedDescription(megabits: Int) -> String {
    switch megabits {
    case 10: "10 Mb/s"
    case 100: "100 Mb/s (Fast Ethernet)"
    case 1_000: "1 Gb/s (Gigabit Ethernet)"
    case let speed where speed >= 1_000 && speed % 1_000 == 0: "\(speed / 1_000) Gb/s"
    case let speed where speed > 1_000: "\((Double(speed) / 1_000).formatted()) Gb/s"
    default: "\(megabits) Mb/s"
    }
}

/// Explains the USB link an adapter uses, and whether it may limit the adapter's speed.
func usbLinkExplanation(_ value: String, adapterMegabits: Int?) -> ValueExplanation? {
    let links: [String: (name: String, megabits: Int)] = [
        "low_speed": ("USB Low Speed", 1),
        "full_speed": ("USB Full Speed", 12),
        "high_speed": ("USB 2.0 High Speed", 480),
        "super_speed": ("USB 5 Gb/s", 5_000),
        "super_speed_plus": ("USB 10 Gb/s", 10_000),
        "super_speed_plus_by_2": ("USB 20 Gb/s", 20_000)
    ]

    guard let link = links[value] else {
        return nil
    }

    let summary: String = "Connected at \(link.name) (up to \(ethernetSpeedDescription(megabits: link.megabits)))."

    if let adapterMegabits, adapterMegabits > link.megabits {
        return .info(
            summary,
            detail: "The adapter supports \(ethernetSpeedDescription(megabits: adapterMegabits)), but its USB connection runs at up to \(ethernetSpeedDescription(megabits: link.megabits)), which can limit its speed.",
            why: "The network can't be faster than the USB link the adapter uses.",
            action: "For full speed, connect the adapter to a faster USB or Thunderbolt port, not through a slower hub or cable.",
            confidence: .likely(reasons: [
                "The USB connection's reported speed is lower than the adapter's Ethernet speed."
            ])
        )
    }

    return .info(
        summary,
        detail: "This is the USB speed the device negotiated with the Mac.",
        why: "A device can't send data faster than its USB link allows.",
        action: "Nothing to do.",
        confidence: .documented
    )
}

// MARK: - Wi-Fi

// Sources: the values seen in docs/value-inventory.md (spairport_status_connected,
// the four security modes, spairport_network_type_station, spairport_caps_supported,
// FCC, US) and the keys in Apple's SPAirPortReporter strings: spairport_status_
// connected, _off, _disassociated and _inactive; spairport_security_mode_none, _wep,
// _wep40, _wep128, _8021x, _wps, _wpa_personal, _wpa_enterprise, _wpa2_personal,
// _wpa2_personal_mixed, _wpa2_enterprise, _wpa2_enterprise_mixed and _wpa3_personal;
// spairport_network_type_station, _ibss and _sharing; spairport_caps_supported and
// _unsupported. Published output shows the locales ETSI and RoW. Unconfirmed
// spellings, kept because older versions of this app matched them: status
// disconnected and not_associated; security modes wpa_personal_mixed, wpa3_enterprise,
// wpa2_wpa3_enterprise and owe; locale MKK. Signal bands are common Wi-Fi guidance.

let wifiValueRules: [ValueRule] = [
    ValueRule(.wifi, field: "spairport_status_information") { context in
        wifiStatusExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_security_mode") { context in
        wifiSecurityExplanation(
            context.reportedValue,
            isCurrentNetwork: context.pathContains("spairport_current_network_information")
        )
    },

    ValueRule(.wifi, field: "spairport_signal_noise", unrecognizedValues: .ignore) { context in
        wifiSignalExplanation(
            context.reportedValue,
            isCurrentNetwork: context.pathContains("spairport_current_network_information")
        )
    },

    ValueRule(.wifi, field: "spairport_network_channel", unrecognizedValues: .ignore) { context in
        wifiChannelExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_network_phymode", unrecognizedValues: .ignore) { context in
        wifiGeneration(context.reportedValue).map { generation in
            context.pathContains("spairport_current_network_information")
                ? .normal(
                    "Connected using \(generation).",
                    detail: "This is the Wi-Fi standard this Mac and the router agreed on for the current connection.",
                    why: "Newer standards are faster and cope better with busy networks. The connection uses the newest standard both sides support.",
                    action: "Nothing to do. If it's older than your router supports, check the router's settings or move closer to it.",
                    confidence: .documented
                )
                : .info(
                    "This network supports up to \(generation).",
                    detail: "This is the newest Wi-Fi standard the nearby network advertised when the scan ran.",
                    why: "It's a network this Mac could see, not necessarily one it uses.",
                    action: "Nothing to do.",
                    confidence: .documented
                )
        }
    },

    ValueRule(.wifi, field: "spairport_supported_phymodes", unrecognizedValues: .ignore) { context in
        wifiGeneration(context.reportedValue).map {
            .info(
                "This Mac's Wi-Fi supports up to \($0).",
                detail: "This is the list of Wi-Fi standards the Mac's Wi-Fi hardware can use. The newest one is named here.",
                why: "A connection can't be faster than the older of this and the router's newest standard.",
                action: "Nothing to do.",
                confidence: .documented
            )
        }
    },

    ValueRule(.wifi, field: "spairport_network_type") { context in
        wifiNetworkTypeExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_network_rate", unrecognizedValues: .ignore) { context in
        leadingInteger(context.reportedValue).map { rate in
            .info(
                "The link between this Mac and the router runs at up to \(rate.formatted()) Mbps.",
                detail: "Internet speed is usually lower, because it depends on the internet connection itself.",
                why: "This rate changes all the time with signal strength and interference. It's the ceiling for traffic inside your network, such as backups and file sharing.",
                action: "Nothing to do. If it's much lower than usual, check the signal and move closer to the router.",
                confidence: .documented
            )
        }
    },

    ValueRule(.wifi, field: "spairport_network_country_code", unrecognizedValues: .ignore) { context in
        wifiRegionExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_wireless_country_code", unrecognizedValues: .ignore) { context in
        wifiRegionExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_wireless_locale") { context in
        wifiLocaleExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_caps_airdrop") { context in
        wifiCapabilityExplanation(
            context.reportedValue,
            feature: "AirDrop",
            why: "AirDrop sends files directly to nearby Apple devices over Wi-Fi."
        )
    },

    ValueRule(.wifi, field: "spairport_caps_autounlock") { context in
        wifiCapabilityExplanation(
            context.reportedValue,
            feature: "unlocking with Apple Watch",
            why: "Auto Unlock uses Wi-Fi to measure how close your Apple Watch is before it unlocks the Mac."
        )
    },

    ValueRule(.wifi, field: "spairport_caps_wow") { context in
        wifiCapabilityExplanation(
            context.reportedValue,
            feature: "waking over Wi-Fi (Wake on Wireless)",
            why: "It lets other devices wake the Mac over Wi-Fi to reach shared files, printers, or screen sharing."
        )
    },

    ValueRule(.wifi, field: "spairport_caps_awdl") { context in
        wifiCapabilityExplanation(
            context.reportedValue,
            feature: "Apple Wireless Direct Link (used by AirPlay screen mirroring, AirDrop, and Sidecar)",
            why: "These features connect directly to nearby Apple devices, without going through a router."
        )
    }
]

private func wifiStatusExplanation(_ value: String) -> ValueExplanation? {
    switch tokenSuffix(value, after: "status_") {
    case "connected":
        .normal(
            "Connected to a Wi-Fi network.",
            detail: "Wi-Fi was on and joined to a network when the scan ran.",
            why: "The Mac can reach the network and, through it, the internet.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "off":
        .info(
            "Wi-Fi is turned off.",
            detail: "The Wi-Fi radio was off when the scan ran, so it can't see or join networks.",
            why: "The Mac needs another connection, such as Ethernet, to reach the network. AirDrop and some Continuity features also need Wi-Fi.",
            action: "If you expected Wi-Fi to be on, turn it on in Control Center or System Settings › Wi-Fi.",
            confidence: .documented
        )
    case "disassociated", "disconnected", "not_associated":
        .info(
            "Wi-Fi is on but not connected to a network.",
            detail: "The Wi-Fi radio was on, but it wasn't joined to any network when the scan ran.",
            why: "Without a network, the Mac can't use Wi-Fi to reach the internet.",
            action: "If you expected a connection, choose a network in System Settings › Wi-Fi. If it keeps dropping, check the password and the router.",
            confidence: .documented
        )
    case "inactive":
        .info(
            "The Wi-Fi network service is inactive.",
            detail: "Wi-Fi hardware is present, but its service is turned off or deactivated in Network settings.",
            why: "macOS won't use Wi-Fi for network traffic while its service is inactive.",
            action: "If you want to use Wi-Fi, check that the Wi-Fi service is active in System Settings › Network.",
            confidence: .documented
        )
    default:
        nil
    }
}

func wifiSecurityExplanation(_ value: String, isCurrentNetwork: Bool) -> ValueExplanation? {
    guard let mode = tokenSuffix(value, after: "security_mode_") else {
        return nil
    }

    let networkName: String = isCurrentNetwork ? "the network this Mac is connected to" : "this nearby network"
    let subject: String = isCurrentNetwork ? "The network this Mac is connected to" : "This nearby network"
    let weak: (String, String, String) -> ValueExplanation = { summary, detail, why in
        isCurrentNetwork
            ? .review(
                summary,
                detail: detail,
                why: why,
                action: "If this is your router, switch it to WPA2/WPA3 Personal (or WPA3 Personal). Otherwise, prefer another network or use a VPN.",
                confidence: .documented
            )
            : .info(
                summary,
                detail: detail,
                why: "\(why) It's only a nearby network, so it doesn't affect this Mac unless it joins.",
                action: "Nothing to do unless you plan to join it.",
                confidence: .documented
            )
    }
    let strong: (String, String, String) -> ValueExplanation = { summary, detail, why in
        .normal(
            summary,
            detail: detail,
            why: why,
            action: "Nothing to do.",
            confidence: .documented
        )
    }

    switch mode {
    case "wpa3_personal":
        return strong(
            "WPA3 Personal, the newest and strongest security for home networks.",
            "Traffic on \(networkName) is encrypted with WPA3, which resists password-guessing attacks better than WPA2.",
            "It's the security type Apple recommends for Wi-Fi routers."
        )
    case "wpa3_transition":
        return strong(
            "WPA2/WPA3 Personal: WPA3 for devices that support it, and WPA2 for older ones.",
            "\(subject) accepts both WPA3 and WPA2, so each device uses the best one it supports.",
            "It's the mode Apple recommends for routers that still have older devices on them."
        )
    case "wpa2_personal":
        return strong(
            "WPA2 Personal: secure and widely used. WPA3 is newer, if the router supports it.",
            "Traffic on \(networkName) is encrypted with WPA2 and a shared password.",
            "WPA2 is secure with a strong password. WPA3 adds protection against password guessing."
        )
    case "wpa2_personal_mixed":
        return weak(
            "WPA/WPA2 Personal: the router still accepts the outdated original WPA.",
            "\(subject) allows both WPA2 and the original WPA, which is no longer considered secure.",
            "Allowing the original WPA weakens the network and can slow it down."
        )
    case "wpa2_enterprise", "wpa3_enterprise", "wpa2_wpa3_enterprise":
        return strong(
            "Enterprise security: each person signs in with their own account, as is common at work or school.",
            "\(subject) checks each person's own user name and password or certificate instead of a shared password.",
            "Each person's traffic is encrypted separately, and the organization can remove one person's access without changing a shared password."
        )
    case "wpa2_enterprise_mixed":
        return weak(
            "WPA/WPA2 Enterprise: the network still accepts the outdated original WPA.",
            "Each person signs in with their own account, but the network also allows the original WPA.",
            "Allowing the original WPA weakens the network's encryption."
        )
    case "wpa_personal", "wpa_personal_mixed", "wpa_enterprise":
        return weak(
            "The original WPA, an outdated security type.",
            "\(subject) uses the first version of WPA, from 2003.",
            "Its encryption has known weaknesses, and Apple recommends against it."
        )
    case "wep", "wep40", "wep128", "8021x":
        let wepDetail: String = switch mode {
        case "wep40": "\(subject) uses WEP encryption with a 40-bit key."
        case "wep128": "\(subject) uses WEP encryption with a 128-bit key."
        case "8021x": "\(subject) uses 802.1X sign-in with WEP encryption."
        default: "\(subject) uses WEP encryption."
        }
        return weak(
            "WEP, an obsolete security type that can be broken quickly.",
            wepDetail,
            "WEP can be cracked in minutes, so it offers almost no protection."
        )
    case "wps":
        return weak(
            "Wi-Fi Protected Setup (WPS), a push-button or PIN way of joining.",
            "\(subject) was advertising WPS when the scan ran. macOS doesn't use WPS to join networks.",
            "The WPS PIN method can be guessed, which can reveal the network's password."
        )
    case "none":
        return weak(
            "An open network with no Wi-Fi encryption, so others nearby can see traffic that isn't otherwise protected.",
            "\(subject) has no password and no Wi-Fi encryption.",
            "Anyone nearby can see traffic that isn't protected in another way. Websites using HTTPS and VPNs still protect their own traffic."
        )
    case "owe":
        return strong(
            "Enhanced Open: no password, but traffic is still encrypted.",
            "\(subject) is open to anyone, but each device's traffic is encrypted separately.",
            "It protects against others nearby reading your traffic, though it can't prove the network is the one you expect."
        )
    default:
        return nil
    }
}

private func wifiNetworkTypeExplanation(_ value: String) -> ValueExplanation? {
    switch tokenSuffix(value, after: "network_type_") {
    case "station":
        .info(
            "A regular network hosted by a router or access point.",
            detail: "Apple calls this an infrastructure network: devices connect through a central router or access point.",
            why: "It's the usual kind of Wi-Fi network at home, at work, and in public places.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "ibss":
        .info(
            "A direct computer-to-computer (ad hoc) network.",
            detail: "Devices connect directly to each other without a router. Current macOS can no longer create these networks.",
            why: "Ad hoc networks usually have weak or no security and don't provide internet access on their own.",
            action: "If you don't recognize it, don't join it.",
            confidence: .documented
        )
    case "sharing":
        .info(
            "A network created by Internet Sharing on a Mac.",
            detail: "A Mac is sharing its internet connection over Wi-Fi, acting as a small router.",
            why: "Other devices get internet access through that Mac, which must stay awake and connected.",
            action: "If it's this Mac and you didn't mean to share, turn off Internet Sharing in System Settings › General › Sharing.",
            confidence: .documented
        )
    default:
        nil
    }
}

/// Signal bands are common Wi-Fi guidance, not an Apple specification.
func wifiSignalExplanation(_ value: String, isCurrentNetwork: Bool) -> ValueExplanation? {
    let numbers: [Int] = value
        .components(separatedBy: "/")
        .compactMap { leadingInteger($0) }

    guard let signal = numbers.first else {
        return nil
    }

    let noiseNote: String = numbers.count > 1 ? ", \(signal - numbers[1]) dB above background noise" : ""
    let detail: String = "Signal strength is measured in dBm; values closer to 0 are stronger. These bands are common Wi-Fi guidance, not an Apple specification."
    let (quality, status): (String, ValueStatus) = wifiSignalQuality(signal)

    let summary: String = "\(quality) signal (\(signal) dBm\(noiseNote))."

    guard isCurrentNetwork else {
        return .info(
            summary,
            detail: detail,
            why: "This is how strongly a nearby network reached this Mac. It only matters if you plan to join that network.",
            action: "Nothing to do.",
            confidence: .observed
        )
    }

    let why: String = status == .normal
        ? "A strong signal gives the fastest, steadiest connection this network can offer."
        : "A weak signal lowers speed and can make the connection drop, especially for video calls."
    let action: String = status == .normal
        ? "Nothing to do."
        : "Move closer to the router or access point, or reduce obstacles between them, for faster and steadier Wi-Fi."

    return ValueExplanation(
        summary: summary,
        detail: detail,
        significance: why,
        status: status,
        confidence: .observed,
        suggestedAction: action
    )
}

/// Common Wi-Fi guidance for received signal strength in dBm.
func wifiSignalQuality(_ signal: Int) -> (quality: String, status: ValueStatus) {
    switch signal {
    case (-50)...: ("Excellent", .normal)
    case (-60)..<(-50): ("Good", .normal)
    case (-67)..<(-60): ("Fair", .normal)
    case (-75)..<(-67): ("Weak", .informational)
    default: ("Poor", .worthReviewing)
    }
}

/// Returns the band in a channel value such as `36 (5GHz, 160MHz)`.
func wifiBand(_ channel: String) -> String? {
    let lowercased: String = channel.lowercased()

    if lowercased.contains("6ghz") { return "6 GHz" }
    if lowercased.contains("5ghz") { return "5 GHz" }
    if lowercased.contains("2ghz") { return "2.4 GHz" }
    return nil
}

/// Decodes values such as `36 (5GHz, 160MHz)`.
func wifiChannelExplanation(_ value: String) -> ValueExplanation? {
    guard let channel = leadingInteger(value) else {
        return nil
    }

    let lowercased: String = value.lowercased()
    let width: String? = value
        .components(separatedBy: CharacterSet(charactersIn: " ,()"))
        .first { $0.lowercased().hasSuffix("mhz") }
        .map { "\($0.dropLast(3)) MHz" }
    let bandNote: String
    let why: String

    if lowercased.contains("6ghz") {
        bandNote = "The 6 GHz band (Wi-Fi 6E and later) is the fastest and least crowded, with the shortest range."
        why = "It gives the most speed close to the router, but walls weaken it quickly."
    } else if lowercased.contains("5ghz") {
        bandNote = "The 5 GHz band is faster than 2.4 GHz, with a shorter range."
        why = "It's the usual choice for speed in the same room or nearby rooms."
    } else if lowercased.contains("2ghz") {
        bandNote = "The 2.4 GHz band reaches farther but is slower and more crowded."
        why = "It's shared with many other networks and devices, such as Bluetooth and microwave ovens, so it's often slower."
    } else {
        return nil
    }

    let band: String = wifiBand(value) ?? "2.4 GHz"

    return .info(
        "Channel \(channel) on the \(band) band\(width.map { ", \($0) wide" } ?? "").",
        detail: "\(bandNote) Wider channels carry more data but are more sensitive to interference.",
        why: why,
        action: "Nothing to do. The router chooses the channel; if Wi-Fi is slow, letting it choose automatically usually works best.",
        confidence: .documented
    )
}

/// Returns the newest Wi-Fi generation in a PHY mode list such as `802.11a/n/ac/ax`.
func wifiGeneration(_ value: String) -> String? {
    let modes: Set<String> = Set(
        value
            .replacingOccurrences(of: "802.11", with: "")
            .components(separatedBy: CharacterSet(charactersIn: "/ ,"))
            .map { $0.lowercased() }
    )
    let generations: [(mode: String, name: String)] = [
        ("be", "Wi-Fi 7 (802.11be)"),
        ("ax", "Wi-Fi 6 (802.11ax)"),
        ("ac", "Wi-Fi 5 (802.11ac)"),
        ("n", "Wi-Fi 4 (802.11n)"),
        ("g", "802.11g"),
        ("a", "802.11a"),
        ("b", "802.11b")
    ]

    return generations.first { modes.contains($0.mode) }?.name
}

private func wifiRegionExplanation(_ code: String) -> ValueExplanation? {
    guard code.count == 2,
          let region = Locale(identifier: "en_US").localizedString(forRegionCode: code) else {
        return nil
    }

    return .info(
        "Wi-Fi region: \(region). It sets which channels and transmit power are allowed.",
        detail: "macOS works out the country from nearby routers and, when allowed, Location Services.",
        why: "Each country allows different Wi-Fi channels and power levels, so the region decides which networks and bands the Mac can use.",
        action: "Nothing to do. If it names the wrong country, some networks may be hidden; turning Wi-Fi off and on usually makes macOS check again.",
        confidence: .documented
    )
}

private func wifiLocaleExplanation(_ value: String) -> ValueExplanation? {
    let summary: String
    let confidence: ValueConfidence

    switch value.uppercased() {
    case "FCC":
        summary = "Wi-Fi follows the United States (FCC) rules for channels and transmit power."
        confidence = .documented
    case "ETSI":
        summary = "Wi-Fi follows the European (ETSI) rules for channels and transmit power."
        confidence = .documented
    case "MKK", "JAPAN":
        summary = "Wi-Fi follows the Japanese (MKK) rules for channels and transmit power."
        confidence = .documented
    case "ROW":
        summary = "Wi-Fi follows a general set of rules for channels and transmit power used outside specific regions."
        confidence = .observed
    default:
        return nil
    }

    return .info(
        summary,
        detail: "The locale is the group of radio rules the Wi-Fi hardware applies. It's set from the Wi-Fi country code.",
        why: "It decides which channels and power levels the Mac may use, so a network on a channel outside these rules won't appear.",
        action: "Nothing to do.",
        confidence: confidence
    )
}

private func wifiCapabilityExplanation(_ value: String, feature: String, why: String) -> ValueExplanation? {
    switch decodeBooleanLike(value) {
    case true?:
        .info(
            "This Mac's Wi-Fi supports \(feature).",
            detail: "The Wi-Fi hardware reports that it can do this.",
            why: why,
            action: "Nothing to do.",
            confidence: .documented
        )
    case false?:
        .info(
            "This Mac's Wi-Fi doesn't support \(feature).",
            detail: "The Wi-Fi hardware reports that it can't do this, usually because it's older or not made by Apple.",
            why: why,
            action: "Nothing to do, unless you need this feature on this Mac.",
            confidence: .documented
        )
    case nil:
        nil
    }
}

// MARK: - Bluetooth

// Sources: attrib_on and attrib_off are seen in docs/value-inventory.md. Discoverability
// is described in https://support.apple.com/guide/mac-help/blth1004.

let bluetoothValueRules: [ValueRule] = [
    ValueRule(.bluetooth, field: "controller_state") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Bluetooth is on.",
                detail: "The Bluetooth radio was on when the scan ran.",
                why: "Wireless keyboards, mice, headphones, and Continuity features such as Handoff and AirDrop can work.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Bluetooth is off, so wireless keyboards, mice, and headphones can't connect.",
                detail: "The Bluetooth radio was off when the scan ran.",
                why: "Continuity features such as Handoff, AirDrop, and Unlock with Apple Watch also need Bluetooth.",
                action: "If you expected Bluetooth to be on, turn it on in Control Center or System Settings › Bluetooth.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.bluetooth, field: "controller_discoverable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "This Mac is visible to nearby Bluetooth devices. That normally happens only while Bluetooth settings is open.",
                detail: "Nearby devices can find this Mac by name to pair with it.",
                why: "Being visible is needed for pairing, but it also shows the Mac's name to people nearby.",
                action: "Nothing to do. It stops when you close Bluetooth settings.",
                confidence: .documented
            )
        case false?:
            .normal(
                "This Mac isn't visible to nearby devices, the normal state outside Bluetooth settings.",
                detail: "Devices that are already paired can still connect.",
                why: "Staying hidden keeps the Mac's name private and avoids unwanted pairing requests.",
                action: "Nothing to do. To pair a new device, open System Settings › Bluetooth.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.bluetooth, field: "controller_vendorID", unrecognizedValues: .ignore) { context in
        bluetoothVendorExplanation(context.reportedValue)
    },

    ValueRule(.bluetooth, field: "device_vendorID", unrecognizedValues: .ignore) { context in
        bluetoothVendorExplanation(context.reportedValue)
    },

    ValueRule(.bluetooth, field: "device_rssi", unrecognizedValues: .ignore) { context in
        leadingInteger(context.reportedValue).map { rssi in
            let quality: String = rssi >= -60 ? "Strong" : rssi >= -80 ? "Fair" : "Weak"
            return .info(
                "\(quality) signal (\(rssi) dBm) when the device was last seen.",
                detail: "Values closer to 0 are stronger. Walls, bodies, and distance weaken Bluetooth quickly.",
                why: "A weak signal can make audio skip or a keyboard or mouse lag.",
                action: "Nothing to do. If the device drops out, move it closer to the Mac.",
                confidence: .observed
            )
        }
    }
]

private func bluetoothVendorExplanation(_ value: String) -> ValueExplanation? {
    // Values look like "0x004C" or "0x004C (Apple)".
    var reportedName: String?

    if let open = value.firstIndex(of: "("), value.hasSuffix(")") {
        reportedName = String(value[value.index(after: open)..<value.index(before: value.endIndex)])
    }

    return vendorExplanation(value, kind: .bluetooth, reportedName: reportedName)
}

// MARK: - Proxies and VPN On Demand

// Sources: proxy, VPN On Demand, PPP, AirPort join mode, and VPN authentication keys and
// values are System Configuration constants (SCSchemaDefinitions.h) and appear in
// docs/value-inventory.md or Apple's System Information strings. On Demand rule actions
// and interface types come from Apple's VPN On Demand documentation (Device Management,
// VPN.OnDemandRulesElement).

/// Reads on/off settings that network configuration stores as `yes`/`no`, `true`/`false`,
/// or the numbers 1 and 0.
func decodeSettingFlag(_ value: String) -> Bool? {
    if let decoded = decodeBooleanLike(value) {
        return decoded
    }

    switch value.trimmingCharacters(in: .whitespaces) {
    case "1": return true
    case "0": return false
    default: return nil
    }
}

private let proxyProtocols: [(field: String, traffic: String)] = [
    ("HTTPEnable", "web traffic (HTTP)"),
    ("HTTPSEnable", "secure web traffic (HTTPS)"),
    ("SOCKSEnable", "traffic from apps that use a SOCKS proxy"),
    ("FTPEnable", "FTP file transfers"),
    ("GopherEnable", "Gopher, an old protocol that's rarely used today"),
    ("RTSPEnable", "streaming media (RTSP)")
]

private let proxySettingsAction: String =
    "If you didn't set up a proxy and your organization doesn't use one, check the Proxies settings for this service in System Settings › Network."

private let proxyWhy: String =
    "A proxy can see, log, and filter the traffic it carries, so it should be one that you or your organization set up."

let proxyValueRules: [ValueRule] = proxyProtocols.map { proxy -> ValueRule in
    ValueRule(.network, .networkLocation, field: proxy.field) { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "A proxy server is set for \(proxy.traffic) on this service.",
                detail: "Matching connections go through the proxy instead of straight to the destination. Organizations, schools, and some security or filtering apps set proxies.",
                why: proxyWhy,
                action: proxySettingsAction,
                confidence: .documented
            )
        case false?:
            .normal(
                "No proxy is set for \(proxy.traffic); connections go directly.",
                detail: "This kind of traffic goes straight to its destination, not through a proxy server.",
                why: "That's the usual setup at home and on most networks.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
} + [
    ValueRule(.network, .networkLocation, field: "ProxyAutoConfigEnable") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "Proxy settings come from an automatic configuration (PAC) file.",
                detail: "The file decides, for each address, whether to use a proxy. Organizations often set this up.",
                why: proxyWhy,
                action: proxySettingsAction,
                confidence: .documented
            )
        case false?:
            .normal(
                "No automatic proxy configuration file is used.",
                detail: "macOS doesn't load a PAC file to decide which connections use a proxy.",
                why: "That's the usual setup outside organizations that manage their network.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.network, .networkLocation, field: "ProxyAutoDiscoveryEnable") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "macOS looks for proxy settings published on the network (WPAD).",
                detail: "This is useful on managed networks. On other networks, it lets the network suggest a proxy.",
                why: "Any network this Mac joins can then point its traffic at a proxy, which is only wanted on networks you trust.",
                action: "If you don't use a network that needs it, turn off Auto Proxy Discovery in the service's Proxies settings.",
                confidence: .documented
            )
        case false?:
            .normal(
                "macOS doesn't look for proxy settings on the network.",
                detail: "Networks this Mac joins can't suggest a proxy through WPAD.",
                why: "That's the default, and it means only proxies set on this Mac are used.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.network, .networkLocation, field: "FTPPassive") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .normal(
                "FTP uses passive mode, the default, which works better through firewalls and routers.",
                detail: "In passive mode the Mac opens every FTP connection itself.",
                why: "Routers and firewalls usually allow connections the Mac opens, so FTP transfers keep working.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "FTP uses active mode, which firewalls and routers often block.",
                detail: "In active mode the FTP server opens a connection back to the Mac for each transfer.",
                why: "Routers and firewalls often block those incoming connections, so FTP transfers can fail.",
                action: "If FTP transfers fail, turn on Use Passive FTP Mode (PASV) in the service's Proxies settings.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.network, .networkLocation, field: "ExcludeSimpleHostnames") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "Simple host names without a domain, such as intranet names, bypass any proxy.",
                detail: "Names like “printer” or “intranet” are reached directly, while full names like “www.example.com” use the proxy.",
                why: "Local devices and intranet sites keep working when the proxy can't reach them.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Simple host names without a domain are treated like other addresses when a proxy is set.",
                detail: "Names like “printer” or “intranet” go through the proxy like any other address.",
                why: "If a proxy is set and can't reach local names, local devices and intranet sites may not open.",
                action: "Nothing to do unless local names fail through the proxy. Then turn on Exclude simple hostnames in the Proxies settings.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.networkLocation, field: "OnDemandEnabled") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "VPN On Demand is on: the VPN can connect by itself when its rules match, for example on certain networks.",
                detail: "The On Demand rules below it decide when the VPN connects or disconnects.",
                why: "Traffic can go through the VPN without anyone starting it, which organizations use to protect work traffic.",
                action: "Nothing to do if you or your organization set this up. Review the rules if the VPN connects when you don't expect it.",
                confidence: .documented
            )
        case false?:
            .info(
                "VPN On Demand is off: the VPN connects only when someone or an app starts it.",
                detail: "Any On Demand rules for this VPN aren't used.",
                why: "Traffic goes through the VPN only while someone has connected it.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.networkLocation, field: "Action", unrecognizedValues: .ignore) { context in
        guard context.pathContains("OnDemandRules") else {
            return nil
        }

        return onDemandActionExplanation(context.reportedValue) ?? .unexplained(context.reportedValue)
    },

    ValueRule(.networkLocation, field: "InterfaceTypeMatch", unrecognizedValues: .ignore) { context in
        let connection: String? = switch context.reportedValue {
        case "WiFi": "on Wi-Fi"
        case "Ethernet": "on a wired network"
        case "Cellular": "on a cellular connection"
        default: nil
        }

        return connection.map {
            .info(
                "This rule applies when the Mac is \($0).",
                detail: "The rule's action is taken only while the Mac's main connection is \($0).",
                why: "It lets the VPN behave differently depending on how the Mac is connected.",
                action: "Nothing to do.",
                confidence: .documented
            )
        }
    }
]

private func onDemandActionExplanation(_ value: String) -> ValueExplanation? {
    let summary: String
    let detail: String

    switch value {
    case "Connect":
        summary = "When this rule matches, the VPN connects automatically."
        detail = "Once the rule's conditions are met, macOS starts the VPN without asking."
    case "Disconnect":
        summary = "When this rule matches, the VPN disconnects."
        detail = "Once the rule's conditions are met, macOS stops the VPN and keeps it off."
    case "EvaluateConnection":
        summary = "When this rule matches, the VPN connects only for the domains the rule lists."
        detail = "macOS checks each connection's destination and starts the VPN only for the listed domains."
    case "Ignore":
        summary = "When this rule matches, the VPN is left as it is: running if connected, off if not."
        detail = "macOS neither starts nor stops the VPN because of this rule."
    default:
        return nil
    }

    return .info(
        summary,
        detail: detail,
        why: "On Demand rules decide, without anyone's input, when traffic goes through the VPN.",
        action: "Nothing to do if you or your organization set up these rules.",
        confidence: .documented
    )
}

// MARK: - Network locations, dial-up and VPN connection settings

/// When a PPP or VPN connection ends, keyed by the setting that controls it.
private let disconnectTriggers: [(field: String, event: String)] = [
    ("DisconnectOnIdle", "the connection has been idle for a while"),
    ("DisconnectOnLogout", "the user logs out"),
    ("DisconnectOnSleep", "the Mac goes to sleep"),
    ("DisconnectOnFastUserSwitch", "another user switches in"),
    ("DisconnectOnWake", "the Mac wakes from sleep")
]

/// A dial-up (PPP) switch: what it means when on and off, what it controls, and why that matters.
private struct DialUpSwitch: Sendable {
    let field: String
    let whenOn: String
    let whenOff: String
    let controls: String
    let why: String
}

private let dialUpSwitches: [DialUpSwitch] = [
    DialUpSwitch(
        field: "DialOnDemand",
        whenOn: "The connection dials automatically when an app needs the network.",
        whenOff: "The connection dials only when someone connects it.",
        controls: "This setting decides whether apps can start the connection by themselves.",
        why: "Automatic dialing can connect without anyone noticing, which matters where calls or connection time cost money."
    ),
    DialUpSwitch(
        field: "CommRedialEnabled",
        whenOn: "If the line is busy, the connection redials automatically.",
        whenOff: "If the line is busy, the connection doesn't redial.",
        controls: "This setting decides what happens when the number is busy.",
        why: "Redialing saves trying again by hand, but keeps calling until it gets through."
    ),
    DialUpSwitch(
        field: "IdleReminder",
        whenOn: "macOS asks whether to stay connected after the connection has been idle.",
        whenOff: "macOS doesn't ask whether to stay connected when the connection is idle.",
        controls: "This setting decides whether macOS checks in when nothing has been sent for a while.",
        why: "The reminder helps avoid leaving a paid connection open by mistake."
    ),
    DialUpSwitch(
        field: "LCPEchoEnabled",
        whenOn: "The connection regularly checks that the other end still answers, so a dropped line is noticed.",
        whenOff: "The connection doesn't check that the other end still answers.",
        controls: "This setting sends small keep-alive messages (LCP echo) during the connection.",
        why: "Without the checks, a dropped connection can look connected until something fails."
    ),
    DialUpSwitch(
        field: "VerboseLogging",
        whenOn: "Detailed connection logging is on, which is useful for troubleshooting.",
        whenOff: "Detailed connection logging is off.",
        controls: "This setting decides how much the connection writes to its log.",
        why: "Detailed logs help find connection problems, but grow faster."
    ),
    DialUpSwitch(
        field: "IPCPCompressionVJ",
        whenOn: "TCP header compression is on, which saves bandwidth on slow links.",
        whenOff: "TCP header compression is off.",
        controls: "This setting uses Van Jacobson compression for TCP headers.",
        why: "Compression helps on slow dial-up lines. A few servers don't support it."
    ),
    DialUpSwitch(
        field: "CommDisplayTerminalWindow",
        whenOn: "A terminal window opens while dialing, for servers that need manual sign-in.",
        whenOff: "No terminal window opens while dialing.",
        controls: "This setting shows a terminal while the connection is made.",
        why: "Only some older dial-up servers need you to type a sign-in by hand."
    ),
    DialUpSwitch(
        field: "CommUseTerminalScript",
        whenOn: "A script runs while dialing to sign in to the server.",
        whenOff: "No sign-in script runs while dialing.",
        controls: "This setting runs a script that answers the server's sign-in prompts.",
        why: "Only some older dial-up servers need a script to sign in."
    ),
    DialUpSwitch(
        field: "ACSPEnabled",
        whenOn: "The connection accepts routes and search domains sent by the server.",
        whenOff: "The connection doesn't accept routes and search domains from the server.",
        controls: "This setting turns on Apple's client-server extension to PPP (ACSP), which lets a server send extra network settings.",
        why: "Server-sent routes decide which traffic goes through the connection."
    ),
    DialUpSwitch(
        field: "CCPEnabled",
        whenOn: "Data compression is negotiated for this connection.",
        whenOff: "Data compression isn't negotiated for this connection.",
        controls: "This setting uses the PPP Compression Control Protocol (CCP).",
        why: "Compression can speed up slow links when both ends support it."
    ),
    DialUpSwitch(
        field: "CCPMPPE40Enabled",
        whenOn: "40-bit MPPE encryption is allowed for this connection.",
        whenOff: "40-bit MPPE encryption isn't allowed for this connection.",
        controls: "MPPE is the encryption old PPTP VPNs used; 40-bit keys are very weak.",
        why: "40-bit encryption can be broken easily, so it offers little protection."
    ),
    DialUpSwitch(
        field: "CCPMPPE128Enabled",
        whenOn: "128-bit MPPE encryption is allowed for this connection.",
        whenOff: "128-bit MPPE encryption isn't allowed for this connection.",
        controls: "MPPE is the encryption old PPTP VPNs used.",
        why: "MPPE, even with 128-bit keys, is no longer considered secure."
    ),
    DialUpSwitch(
        field: "IPCPUsePeerDNS",
        whenOn: "The connection uses the DNS servers the other end provides.",
        whenOff: "The connection doesn't use DNS servers from the other end.",
        controls: "This setting decides where names are looked up while connected.",
        why: "Using the provider's or VPN's DNS servers keeps name lookups working over the connection."
    ),
    DialUpSwitch(
        field: "LCPCompressionACField",
        whenOn: "PPP address and control field compression is on.",
        whenOff: "PPP address and control field compression is off.",
        controls: "This setting drops two fixed header bytes from each PPP frame.",
        why: "It saves a little bandwidth on slow links."
    ),
    DialUpSwitch(
        field: "LCPCompressionPField",
        whenOn: "PPP protocol field compression is on.",
        whenOff: "PPP protocol field compression is off.",
        controls: "This setting shortens a header field in each PPP frame.",
        why: "It saves a little bandwidth on slow links."
    ),
    DialUpSwitch(
        field: "UseSessionTimer",
        whenOn: "The connection ends after a set session time.",
        whenOff: "The connection has no session time limit.",
        controls: "This setting limits how long one connection can last (Session Timer).",
        why: "A time limit avoids long, costly connections, but disconnects even during use."
    )
]

private let disconnectRules: [ValueRule] = disconnectTriggers.map { trigger -> ValueRule in
    ValueRule(.networkLocation, field: trigger.field) { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "The connection ends when \(trigger.event).",
                detail: "macOS disconnects this dial-up or VPN connection automatically when \(trigger.event).",
                why: "It keeps the connection from staying open when it isn't needed, but it has to be reconnected afterward.",
                action: "Nothing to do unless it disconnects when you don't want it to. Then change it in the connection's options.",
                confidence: .documented
            )
        case false?:
            .info(
                "The connection stays up when \(trigger.event).",
                detail: "macOS leaves this dial-up or VPN connection connected when \(trigger.event).",
                why: "The connection stays available without reconnecting, and traffic keeps using it.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
}

private let dialUpRules: [ValueRule] = dialUpSwitches.map { setting -> ValueRule in
    ValueRule(.networkLocation, field: setting.field) { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                setting.whenOn,
                detail: setting.controls,
                why: setting.why,
                action: "Nothing to do unless you want it off. Change it in the connection's advanced options.",
                confidence: .documented
            )
        case false?:
            .info(
                setting.whenOff,
                detail: setting.controls,
                why: setting.why,
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
}

let networkLocationSettingValueRules: [ValueRule] = disconnectRules + dialUpRules + [
    ValueRule(.networkLocation, field: "spnetworklocation_isActive") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "The location in use when the scan ran.",
                detail: "A network location is a saved set of network settings. This one was active, so its services were the ones in use.",
                why: "The settings in this location are the ones that applied to this Mac's connections.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "A saved location that wasn't in use when the scan ran.",
                detail: "A network location is a saved set of network settings. This one is stored but wasn't active.",
                why: "Its settings don't apply until someone switches to it.",
                action: "Nothing to do. You can remove locations you no longer use in System Settings › Network.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.networkLocation, field: "JoinMode") { context in
        let summary: String
        let detail: String

        switch context.reportedValue {
        case "Automatic":
            return .normal(
                "Joins known Wi-Fi networks automatically, the default.",
                detail: "macOS picks among the Wi-Fi networks this Mac has joined before.",
                why: "The Mac reconnects to familiar networks without being asked.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "Preferred":
            summary = "Joins known Wi-Fi networks in the order of the preferred networks list."
            detail = "macOS tries known networks in the order they're listed."
        case "Ranked":
            summary = "Joins known Wi-Fi networks in a ranked order."
            detail = "macOS tries known networks by their ranking."
        case "Recent":
            summary = "Joins the most recently used known Wi-Fi network."
            detail = "macOS prefers the known network it used last."
        case "Strongest":
            summary = "Joins the known Wi-Fi network with the strongest signal."
            detail = "macOS prefers whichever known network it hears best."
        default:
            return nil
        }

        return .info(
            summary,
            detail: detail,
            why: "It decides which network the Mac joins when several known networks are in range.",
            action: "Nothing to do unless the Mac joins the wrong network. Then reorder or remove networks in Wi-Fi settings.",
            confidence: .documented
        )
    },

    ValueRule(.networkLocation, field: "AuthenticationMethod") { context in
        let summary: String
        let detail: String

        switch context.reportedValue {
        case "Password":
            summary = "The VPN signs in with a password."
            detail = "The VPN account's user name and password are used to connect."
        case "Certificate":
            summary = "The VPN signs in with a certificate."
            detail = "A certificate stored in the keychain identifies this Mac or user to the VPN server."
        case "SharedSecret":
            summary = "The VPN signs in with a shared secret, a password shared by everyone who uses the server."
            detail = "The same secret is given to every user of the VPN server."
        case "Hybrid":
            summary = "The VPN checks the server's certificate and signs in with a password."
            detail = "The server proves who it is with a certificate, and the user signs in with a password."
        default:
            return nil
        }

        return .info(
            summary,
            detail: detail,
            why: "Certificates are the strongest of these methods. A shared secret known to many people protects the least.",
            action: "Nothing to do. The VPN's administrator decides the sign-in method.",
            confidence: .documented
        )
    },

    ValueRule(.network, field: "MediaSubType") { context in
        mediaSubtypeExplanation(context.reportedValue)
    },

    ValueRule(.network, field: "MediaOptions") { context in
        mediaOptionExplanation(context.reportedValue)
    },

    ValueRule(.networkVolumes, field: "spnetworkvolume_automounted") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Mounted automatically, for example by a login item, a saved server, or device management.",
                detail: "The volume was connected without anyone choosing it in the Finder at the time.",
                why: "Files on it may be opened or backed up without anyone connecting it by hand.",
                action: "Nothing to do if you recognize the server. Check your login items if you don't.",
                confidence: .documented
            )
        case false?:
            .info(
                "Not mounted automatically: someone connected to it, for example with Connect to Server in the Finder.",
                detail: "A person connected this volume by hand.",
                why: "It stays connected until it's ejected or the Mac restarts.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
]

/// Reads Ethernet media subtypes such as `autoselect`, `none`, or `1000baseT`.
func mediaSubtypeExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "autoselect":
        return .normal(
            "The link speed is negotiated automatically, the default.",
            detail: "The Mac and the device at the other end of the cable agree on the fastest speed both support.",
            why: "Negotiation gives the best speed without any setup.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "none":
        return .info(
            "No link type is set, which is usual for a service with nothing connected or no physical port.",
            detail: "The service doesn't report a cable speed, for example because nothing is plugged in or it's a virtual interface.",
            why: "It has no effect on connections that are working.",
            action: "Nothing to do."
        )
    default:
        break
    }

    guard value.lowercased().contains("baset"), let megabits = leadingInteger(value) else {
        return nil
    }

    let unit: Int = value.lowercased().contains("gbaset") ? 1_000 : 1
    return .info(
        "The link speed is set by hand to \(ethernetSpeedDescription(megabits: megabits * unit)) instead of being negotiated.",
        detail: "A fixed speed that doesn't match the other end can make the connection slow or unreliable.",
        why: "Both ends of the cable must use the same speed and duplex, or the link drops packets.",
        action: "Unless your network needs a fixed speed, set Configure to Automatically in the service's Hardware settings.",
        confidence: .documented
    )
}

/// Reads Ethernet media options: `full-duplex`, `half-duplex`, and `flow-control`.
func mediaOptionExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "full-duplex":
        .normal(
            "Full duplex: the link sends and receives at the same time.",
            detail: "Data can flow both ways on the cable at once.",
            why: "Full duplex is the normal mode for modern Ethernet and gives the best speed.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "half-duplex":
        .info(
            "Half duplex: the link sends or receives, but not both at once.",
            detail: "Data flows one way at a time, as on old hubs.",
            why: "Half duplex is slower, and if the other end uses full duplex the link drops packets.",
            action: "Unless your network needs it, set the service's Ethernet configuration to Automatically.",
            confidence: .documented
        )
    case "flow-control":
        .info(
            "Flow control is on: either end can ask the other to pause briefly.",
            detail: "When one side can't keep up, it can signal the other to wait.",
            why: "It avoids lost packets when one side is busier, at the cost of short pauses.",
            action: "Nothing to do.",
            confidence: .documented
        )
    default:
        nil
    }
}
