import Foundation

// MARK: - Network services

let networkValueRules: [ValueRule] = [
    ValueRule(.network, .networkLocation, field: "hardware") { context in
        switch context.reportedValue {
        case "Ethernet":
            .normal(
                "A wired-style connection: a built-in Ethernet port, a USB or Thunderbolt adapter, a Thunderbolt Bridge, or iPhone USB tethering."
            )
        case "AirPort":
            .normal("Wi-Fi. “AirPort” is the name macOS uses internally for Wi-Fi.", confidence: .documented)
        case "Modem":
            modemServiceExplanation(context)
        default:
            nil
        }
    },

    ValueRule(.network, .networkLocation, field: "type") { context in
        let value: String = context.reportedValue

        if value == "Ethernet" {
            return .normal("An Ethernet network service.")
        }

        if value == "AirPort" || value == "IEEE80211" {
            return .normal("A Wi-Fi network service.", confidence: .documented)
        }

        if value == "Bridge" {
            return .info("A network bridge, such as Thunderbolt Bridge, which connects Macs directly over a cable.")
        }

        if value.hasPrefix("PPP") {
            return .info(
                "A dial-up style connection (PPP)\(value.contains("Serial") ? " over a serial port" : "").",
                detail: "macOS creates these for modems and for USB devices that present a serial port."
            )
        }

        if value.hasPrefix("VPN") {
            let provider: String? = value
                .split(separator: "(", maxSplits: 1)
                .dropFirst()
                .first
                .map { String($0.dropLast(value.hasSuffix(")") ? 1 : 0)) }

            return .info(
                "A VPN service\(provider.map { " provided by the app \($0)" } ?? "").",
                detail: "The VPN app adds this service. It routes traffic through the VPN only while it's connected."
            )
        }

        return nil
    },

    ValueRule(.network, .networkLocation, field: "ConfigMethod") { context in
        ipConfigurationExplanation(context.reportedValue, family: context.parentKey)
    }
]

/// Explains a `Modem` network service using the rest of its record and, when collected,
/// the USB device list. Most modern "modems" are USB serial devices such as dev boards.
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
        return .info("A modem-type network service, used for dial-up or serial connections.")
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

func ipConfigurationExplanation(_ value: String, family: String?) -> ValueExplanation? {
    switch (family, value) {
    case ("IPv4", "DHCP"):
        .normal("Gets its IP address automatically from the router (DHCP), the usual setup.", confidence: .documented)
    case ("IPv4", "Manual"):
        .info(
            "The IP address was entered by hand.",
            detail: "That's intended on some networks. Elsewhere, a mistyped manual address can stop the connection from working.",
            action: "If this network should configure itself, choose Using DHCP in System Settings › Network.",
            confidence: .documented
        )
    case ("IPv4", "INFORM"):
        .info("Uses a manually entered IP address, with other settings from DHCP.", confidence: .documented)
    case ("IPv4", "BOOTP"):
        .info("Gets its address from a BOOTP server, an older method used on some managed networks.", confidence: .documented)
    case ("IPv4", "LinkLocal"):
        .info("Uses only a self-assigned 169.254 address, enough for devices on the same local network.")
    case ("IPv4", "PPP"):
        .info("The IP address is assigned by the dial-up (PPP) connection.")
    case ("IPv4", "VPN"):
        .info("The IP address is assigned by the VPN.")
    case ("IPv6", "Automatic"):
        .normal("IPv6 is configured automatically, the default.", confidence: .documented)
    case ("IPv6", "LinkLocal"):
        .info("IPv6 uses only a link-local address, for the local network.", confidence: .documented)
    case ("IPv6", "Manual"):
        .info("The IPv6 address was entered by hand.", confidence: .documented)
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
                confidence: .likely(reasons: appleDeviceLinkReasons(context, device: device))
            )
        }

        return switch tokenSuffix(context.reportedValue, after: "spethernet_") {
        case "usb_device": .info("A USB Ethernet adapter.")
        case "pcie", "pci": .info("Connected over PCI Express.")
        case "builtin", "built_in": .info("Built into this Mac.")
        default: nil
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
                confidence: .likely(reasons: appleDeviceLinkReasons(context, device: device))
            )
        }

        return .info("Supports Ethernet speeds up to \(ethernetSpeedDescription(megabits: megabits)).", confidence: .documented)
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
            action: "For full speed, connect the adapter to a faster USB or Thunderbolt port, not through a slower hub or cable.",
            confidence: .likely(reasons: [
                "The USB connection's reported speed is lower than the adapter's Ethernet speed."
            ])
        )
    }

    return .info(summary, confidence: .documented)
}

// MARK: - Wi-Fi

let wifiValueRules: [ValueRule] = [
    ValueRule(.wifi, field: "spairport_status_information") { context in
        switch tokenSuffix(context.reportedValue, after: "status_") {
        case "connected": .normal("Connected to a Wi-Fi network.")
        case "off": .info("Wi-Fi is turned off.")
        case "disconnected", "inactive", "not_associated": .info("Wi-Fi is on but not connected to a network.")
        default: nil
        }
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
                ? .normal("Connected using \(generation).", confidence: .documented)
                : .info("This network supports up to \(generation).", confidence: .documented)
        }
    },

    ValueRule(.wifi, field: "spairport_supported_phymodes", unrecognizedValues: .ignore) { context in
        wifiGeneration(context.reportedValue).map {
            .info("This Mac's Wi-Fi supports up to \($0).", confidence: .documented)
        }
    },

    ValueRule(.wifi, field: "spairport_network_type") { context in
        switch tokenSuffix(context.reportedValue, after: "network_type_") {
        case "station": .info("A regular network hosted by a router or access point.")
        case "ibss": .info("A direct computer-to-computer (ad hoc) network.")
        default: nil
        }
    },

    ValueRule(.wifi, field: "spairport_network_rate", unrecognizedValues: .ignore) { context in
        leadingInteger(context.reportedValue).map { rate in
            .info(
                "The link between this Mac and the router runs at up to \(rate.formatted()) Mbps.",
                detail: "Internet speed is usually lower, because it depends on the internet connection itself."
            )
        }
    },

    ValueRule(.wifi, field: "spairport_network_country_code", unrecognizedValues: .ignore) { context in
        wifiRegionExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_wireless_country_code", unrecognizedValues: .ignore) { context in
        wifiRegionExplanation(context.reportedValue)
    },

    ValueRule(.wifi, field: "spairport_caps_airdrop") { context in
        wifiCapabilityExplanation(context.reportedValue, feature: "AirDrop")
    },

    ValueRule(.wifi, field: "spairport_caps_autounlock") { context in
        wifiCapabilityExplanation(context.reportedValue, feature: "unlocking with Apple Watch")
    },

    ValueRule(.wifi, field: "spairport_caps_wow") { context in
        wifiCapabilityExplanation(context.reportedValue, feature: "waking over Wi-Fi (Wake on Wireless)")
    }
]

func wifiSecurityExplanation(_ value: String, isCurrentNetwork: Bool) -> ValueExplanation? {
    guard let mode = tokenSuffix(value, after: "security_mode_") else {
        return nil
    }

    let insecure: (String, String?) -> ValueExplanation = { summary, action in
        isCurrentNetwork
            ? .review(summary, action: action, confidence: .documented)
            : .info(summary, confidence: .documented)
    }

    switch mode {
    case "wpa3_personal":
        return .normal("WPA3 Personal, the newest and strongest security for home networks.", confidence: .documented)
    case "wpa3_transition":
        return .normal(
            "WPA2/WPA3 Personal: WPA3 for devices that support it, and WPA2 for older ones.",
            confidence: .documented
        )
    case "wpa2_personal":
        return .normal(
            "WPA2 Personal: secure and widely used. WPA3 is newer, if the router supports it.",
            confidence: .documented
        )
    case "wpa2_enterprise", "wpa3_enterprise", "wpa2_wpa3_enterprise":
        return .normal(
            "Enterprise security: each person signs in with their own account, as is common at work or school.",
            confidence: .documented
        )
    case "wpa_personal", "wpa_personal_mixed", "wpa_enterprise":
        return insecure(
            "The original WPA, an outdated security type.",
            "If this is your router, switch it to WPA2/WPA3 Personal."
        )
    case "wep":
        return insecure(
            "WEP, an obsolete security type that can be broken quickly.",
            "If this is your router, switch it to WPA2/WPA3 Personal."
        )
    case "none":
        return insecure(
            "An open network with no Wi-Fi encryption, so others nearby can see traffic that isn't otherwise protected.",
            "Prefer secured networks. Websites using HTTPS and VPNs still protect their own traffic."
        )
    case "owe":
        return .normal("Enhanced Open: no password, but traffic is still encrypted.", confidence: .documented)
    default:
        return nil
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
        return .info(summary, detail: detail)
    }

    let action: String? = status == .normal
        ? nil
        : "Move closer to the router or access point, or reduce obstacles between them, for faster and steadier Wi-Fi."

    return ValueExplanation(summary: summary, detail: detail, status: status, confidence: .observed, suggestedAction: action)
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

    if lowercased.contains("6ghz") {
        bandNote = "The 6 GHz band (Wi-Fi 6E and later) is the fastest and least crowded, with the shortest range."
    } else if lowercased.contains("5ghz") {
        bandNote = "The 5 GHz band is faster than 2.4 GHz, with a shorter range."
    } else if lowercased.contains("2ghz") {
        bandNote = "The 2.4 GHz band reaches farther but is slower and more crowded."
    } else {
        return nil
    }

    let band: String = wifiBand(value) ?? "2.4 GHz"

    return .info(
        "Channel \(channel) on the \(band) band\(width.map { ", \($0) wide" } ?? "").",
        detail: "\(bandNote) Wider channels carry more data but are more sensitive to interference.",
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
        confidence: .documented
    )
}

private func wifiCapabilityExplanation(_ value: String, feature: String) -> ValueExplanation? {
    switch decodeBooleanLike(value) {
    case true?: .info("This Mac's Wi-Fi supports \(feature).")
    case false?: .info("This Mac's Wi-Fi doesn't support \(feature).")
    case nil: nil
    }
}

// MARK: - Bluetooth

let bluetoothValueRules: [ValueRule] = [
    ValueRule(.bluetooth, field: "controller_state") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .normal("Bluetooth is on.")
        case false?: .info("Bluetooth is off, so wireless keyboards, mice, and headphones can't connect.")
        case nil: nil
        }
    },

    ValueRule(.bluetooth, field: "controller_discoverable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info("This Mac is visible to nearby Bluetooth devices. That normally happens only while Bluetooth settings is open.")
        case false?:
            .normal("This Mac isn't visible to nearby devices, the normal state outside Bluetooth settings.")
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
                detail: "Values closer to 0 are stronger. Walls, bodies, and distance weaken Bluetooth quickly."
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

let proxyValueRules: [ValueRule] = proxyProtocols.map { proxy -> ValueRule in
    ValueRule(.network, .networkLocation, field: proxy.field) { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "A proxy server is set for \(proxy.traffic) on this service.",
                detail: "Matching connections go through the proxy instead of straight to the destination. Organizations, schools, and some security or filtering apps set proxies.",
                action: proxySettingsAction,
                confidence: .documented
            )
        case false?:
            .normal("No proxy is set for \(proxy.traffic); connections go directly.", confidence: .documented)
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
                action: proxySettingsAction,
                confidence: .documented
            )
        case false?:
            .normal("No automatic proxy configuration file is used.", confidence: .documented)
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
                confidence: .documented
            )
        case false?:
            .normal("macOS doesn't look for proxy settings on the network.", confidence: .documented)
        case nil:
            nil
        }
    },

    ValueRule(.network, .networkLocation, field: "FTPPassive") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?: .normal("FTP uses passive mode, the default, which works better through firewalls and routers.")
        case false?: .info("FTP uses active mode, which firewalls and routers often block.")
        case nil: nil
        }
    },

    ValueRule(.network, .networkLocation, field: "ExcludeSimpleHostnames") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?: .info("Simple host names without a domain, such as intranet names, bypass any proxy.", confidence: .documented)
        case false?: .info("Simple host names without a domain are treated like other addresses when a proxy is set.", confidence: .documented)
        case nil: nil
        }
    },

    ValueRule(.networkLocation, field: "OnDemandEnabled") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?:
            .info(
                "VPN On Demand is on: the VPN can connect by itself when its rules match, for example on certain networks.",
                confidence: .documented
            )
        case false?:
            .info("VPN On Demand is off: the VPN connects only when someone or an app starts it.", confidence: .documented)
        case nil:
            nil
        }
    },

    ValueRule(.networkLocation, field: "Action", unrecognizedValues: .ignore) { context in
        guard context.pathContains("OnDemandRules") else {
            return nil
        }

        return switch context.reportedValue {
        case "Connect": .info("When this rule matches, the VPN connects automatically.", confidence: .documented)
        case "Disconnect": .info("When this rule matches, the VPN disconnects.", confidence: .documented)
        case "EvaluateConnection": .info("When this rule matches, the VPN connects only for the domains the rule lists.", confidence: .documented)
        case "Ignore": .info("When this rule matches, the VPN is left as it is: running if connected, off if not.", confidence: .documented)
        default: .unexplained(context.reportedValue)
        }
    },

    ValueRule(.networkLocation, field: "InterfaceTypeMatch", unrecognizedValues: .ignore) { context in
        switch context.reportedValue {
        case "WiFi": .info("This rule applies when the Mac is on Wi-Fi.", confidence: .documented)
        case "Ethernet": .info("This rule applies when the Mac is on a wired network.", confidence: .documented)
        case "Cellular": .info("This rule applies on a cellular connection.", confidence: .documented)
        default: nil
        }
    }
]

// MARK: - Network locations, dial-up and VPN connection settings

/// When a PPP or VPN connection ends, keyed by the setting that controls it.
private let disconnectTriggers: [(field: String, event: String)] = [
    ("DisconnectOnIdle", "the connection has been idle for a while"),
    ("DisconnectOnLogout", "the user logs out"),
    ("DisconnectOnSleep", "the Mac goes to sleep"),
    ("DisconnectOnFastUserSwitch", "another user switches in"),
    ("DisconnectOnWake", "the Mac wakes from sleep")
]

/// Dial-up (PPP) switches, with what each means when it's on and off.
private let dialUpSwitches: [(field: String, whenOn: String, whenOff: String)] = [
    ("DialOnDemand", "The connection dials automatically when an app needs the network.", "The connection dials only when someone connects it."),
    ("CommRedialEnabled", "If the line is busy, the connection redials automatically.", "If the line is busy, the connection doesn't redial."),
    ("IdleReminder", "macOS asks whether to stay connected after the connection has been idle.", "macOS doesn't ask whether to stay connected when the connection is idle."),
    ("LCPEchoEnabled", "The connection regularly checks that the other end still answers, so a dropped line is noticed.", "The connection doesn't check that the other end still answers."),
    ("VerboseLogging", "Detailed connection logging is on, which is useful for troubleshooting.", "Detailed connection logging is off."),
    ("IPCPCompressionVJ", "TCP header compression is on, which saves bandwidth on slow links.", "TCP header compression is off."),
    ("CommDisplayTerminalWindow", "A terminal window opens while dialing, for servers that need manual sign-in.", "No terminal window opens while dialing."),
    ("CommUseTerminalScript", "A script runs while dialing to sign in to the server.", "No sign-in script runs while dialing.")
]

private let disconnectRules: [ValueRule] = disconnectTriggers.map { trigger -> ValueRule in
    ValueRule(.networkLocation, field: trigger.field) { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?: .info("The connection ends when \(trigger.event).", confidence: .documented)
        case false?: .info("The connection stays up when \(trigger.event).", confidence: .documented)
        case nil: nil
        }
    }
}

private let dialUpRules: [ValueRule] = dialUpSwitches.map { setting -> ValueRule in
    ValueRule(.networkLocation, field: setting.field) { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?: .info(setting.whenOn, confidence: .documented)
        case false?: .info(setting.whenOff, confidence: .documented)
        case nil: nil
        }
    }
}

let networkLocationSettingValueRules: [ValueRule] = disconnectRules + dialUpRules + [
    ValueRule(.networkLocation, field: "spnetworklocation_isActive") { context in
        switch decodeSettingFlag(context.reportedValue) {
        case true?: .info("The location in use when the scan ran.", confidence: .documented)
        case false?: .info("A saved location that wasn't in use when the scan ran.", confidence: .documented)
        case nil: nil
        }
    },

    ValueRule(.networkLocation, field: "JoinMode") { context in
        switch context.reportedValue {
        case "Automatic": .normal("Joins known Wi-Fi networks automatically, the default.", confidence: .documented)
        case "Preferred": .info("Joins known Wi-Fi networks in the order of the preferred networks list.", confidence: .documented)
        case "Ranked": .info("Joins known Wi-Fi networks in a ranked order.", confidence: .documented)
        case "Recent": .info("Joins the most recently used known Wi-Fi network.", confidence: .documented)
        case "Strongest": .info("Joins the known Wi-Fi network with the strongest signal.", confidence: .documented)
        default: nil
        }
    },

    ValueRule(.networkLocation, field: "AuthenticationMethod") { context in
        switch context.reportedValue {
        case "Password": .info("The VPN signs in with a password.", confidence: .documented)
        case "Certificate": .info("The VPN signs in with a certificate.", confidence: .documented)
        case "SharedSecret": .info("The VPN signs in with a shared secret, a password shared by everyone who uses the server.", confidence: .documented)
        case "Hybrid": .info("The VPN checks the server's certificate and signs in with a password.", confidence: .documented)
        default: nil
        }
    },

    ValueRule(.network, field: "MediaSubType") { context in
        mediaSubtypeExplanation(context.reportedValue)
    },

    ValueRule(.networkVolumes, field: "spnetworkvolume_automounted") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info("Mounted automatically, for example by a login item, a saved server, or device management.")
        case false?:
            .info("Not mounted automatically: someone connected to it, for example with Connect to Server in the Finder.")
        case nil:
            nil
        }
    }
]

/// Reads Ethernet media subtypes such as `autoselect`, `none`, or `1000baseT`.
func mediaSubtypeExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "autoselect":
        return .normal("The link speed is negotiated automatically, the default.", confidence: .documented)
    case "none":
        return .info("No link type is set, which is usual for a service with nothing connected or no physical port.")
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
        confidence: .documented
    )
}
