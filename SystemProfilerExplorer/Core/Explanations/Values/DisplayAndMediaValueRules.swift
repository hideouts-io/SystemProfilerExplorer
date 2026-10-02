import Foundation

// MARK: - Graphics and displays

// Sources: the values seen in docs/value-inventory.md (spdisplays_internal,
// spdisplays_yes, spdisplays_off, spdisplays_gpu, spdisplays_builtin,
// spdisplays_metal4, sppci_vendor_Apple, spdisplays_built-in-liquid-retina-xdr) and the
// keys in Apple's SPDisplaysReporter strings: spdisplays_LCD, _CRT, _retinaLCD,
// _built-in_retinaLCD, _projector, _television, _airplaydisplay; spdisplays_internal and
// _airplay; spdisplays_yes, _no, _on, _off; spdisplays_gpu and _egpu; spdisplays_builtin,
// _pcie_device, _tb_device, and _agp_device; and the older Metal family names such as
// spdisplays_mtlgpufamilymac2. spdisplays_external and a bare spdisplays_pcie are
// unconfirmed.

let displayValueRules: [ValueRule] = [
    ValueRule(.displays, field: "spdisplays_display_type") { context in
        tokenSuffix(context.reportedValue, after: "spdisplays_").map(displayTypeExplanation)
    },

    ValueRule(.displays, field: "spdisplays_connection_type") { context in
        switch tokenSuffix(context.reportedValue, after: "spdisplays_") {
        case "internal":
            .info(
                "The built-in display.",
                detail: "This is the display that's part of the Mac itself.",
                why: "Its settings, such as True Tone and automatic brightness, are set in System Settings › Displays.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "external":
            .info(
                "An external display.",
                detail: "The display is connected with a cable, directly or through an adapter or dock.",
                why: "Its resolution and refresh rate depend on the display, the cable, and the port it uses.",
                action: "Nothing to do. If the picture isn't sharp or smooth, try another cable or port.",
                confidence: .documented
            )
        case "airplay":
            .info(
                "A display connected over AirPlay.",
                detail: "The Mac sends its picture to this display or Apple TV over the network.",
                why: "AirPlay displays can lag a little and depend on the network.",
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.displays, field: "spdisplays_pixelresolution", unrecognizedValues: .ignore) { context in
        let numbers: [Int] = context.reportedValue
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }

        guard numbers.count >= 2 else {
            return nil
        }

        let retina: String = context.reportedValue.localizedCaseInsensitiveContains("retina") ? " (Retina)" : ""
        return .info(
            "The panel has \(numbers[0].formatted()) × \(numbers[1].formatted()) pixels\(retina).",
            detail: "This is the number of physical pixels, not the size things look on screen.",
            why: "More pixels at the same size make text and images sharper.",
            action: "Nothing to do.",
            confidence: .documented
        )
    },

    ValueRule(.displays, field: "_spdisplays_resolution", unrecognizedValues: .ignore) { context in
        displayResolutionExplanation(context.reportedValue, pixels: context.sibling("_spdisplays_pixels"))
    },

    ValueRule(.displays, field: "spdisplays_mtlgpufamilysupport") { context in
        metalSupportExplanation(context.reportedValue)
    },

    ValueRule(.displays, field: "spdisplays_vendor") { context in
        tokenSuffix(context.reportedValue, after: "vendor_").map { (vendor: String) -> ValueExplanation in
            let names: [String: String] = ["amd": "AMD", "ati": "ATI", "nvidia": "NVIDIA", "intel": "Intel"]
            return .info(
                "Made by \(names[vendor.lowercased()] ?? vendor).",
                detail: "This is the maker of the graphics processor.",
                why: "It tells you whose drivers and graphics features the Mac uses.",
                action: "Nothing to do.",
                confidence: .documented
            )
        }
    },

    ValueRule(.displays, field: "sppci_device_type") { context in
        switch tokenSuffix(context.reportedValue, after: "spdisplays_") {
        case "gpu":
            .info(
                "A graphics processor (GPU).",
                detail: "It draws everything on screen and speeds up graphics, video, and machine-learning work.",
                why: "GPU speed matters for games, video editing, and 3D work.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "egpu":
            .info(
                "An external graphics processor (eGPU) in a separate enclosure.",
                detail: "It's connected over Thunderbolt. Only Intel Macs support eGPUs.",
                why: "It adds graphics power, but only apps set to use it benefit.",
                action: "Eject it from the menu bar before unplugging it.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.displays, field: "sppci_bus") { context in
        switch tokenSuffix(context.reportedValue, after: "spdisplays_") {
        case "builtin":
            .info(
                "Built into the Mac's chip, not a separate graphics card.",
                detail: "The GPU is part of the main chip and shares its memory.",
                why: "It uses little power. On Apple silicon it's also fast, because it shares the chip's unified memory.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "pcie", "pcie_device":
            .info(
                "Connected over PCI Express, as a separate graphics card.",
                detail: "The GPU is a separate chip or card with its own memory.",
                why: "Separate GPUs are faster for graphics work but use more power.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "tb_device":
            .info(
                "Connected over Thunderbolt, as an external graphics processor.",
                detail: "The GPU is in an external enclosure connected by Thunderbolt.",
                why: "It adds graphics power to an Intel Mac. Apple silicon Macs don't support eGPUs.",
                action: "Eject it from the menu bar before unplugging it.",
                confidence: .documented
            )
        case "agp_device":
            .info(
                "Connected over AGP, a graphics slot used in older Macs.",
                detail: "AGP was the graphics card slot in PowerPC-era Macs.",
                why: "It only appears on very old Macs.",
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.displays, field: "sppci_cores", unrecognizedValues: .ignore) { context in
        leadingInteger(context.reportedValue).map {
            .info(
                "\($0) GPU cores.",
                detail: "The graphics processor has this many cores working in parallel.",
                why: "More GPU cores speed up graphics, video effects, and machine-learning work.",
                action: "Nothing to do.",
                confidence: .documented
            )
        }
    },

    ValueRule(.displays, field: "spdisplays_main", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "The main display, which shows the menu bar and Dock.",
                detail: "New windows and the login window appear here first.",
                why: "It's the display you work on by default.",
                action: "Nothing to do. You can choose the main display in System Settings › Displays › Arrange.",
                confidence: .documented
            )
        case false?:
            .info(
                "Not the main display.",
                detail: "Another display shows the menu bar and Dock.",
                why: "Windows open on the main display unless you move them.",
                action: "Nothing to do. You can choose the main display in System Settings › Displays › Arrange.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.displays, field: "spdisplays_mirror", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "This display mirrors another display.",
                detail: "It shows the same picture as another display.",
                why: "Mirroring is handy for presentations, but you can't use the displays for different windows.",
                action: "Nothing to do. You can turn mirroring off in System Settings › Displays.",
                confidence: .documented
            )
        case false?:
            .info(
                "This display isn't mirroring another display.",
                detail: "It shows its own picture, or it's the only display.",
                why: "Each display can show different windows.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.displays, field: "spdisplays_ambient_brightness", unrecognizedValues: .ignore) { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Brightness adjusts automatically to the light around the Mac.",
                detail: "A light sensor near the display adjusts brightness as the room gets lighter or darker.",
                why: "It keeps the screen comfortable to read and saves energy in dim light.",
                action: "Nothing to do. You can change it in System Settings › Displays.",
                confidence: .documented
            )
        case false?:
            .info(
                "Brightness doesn't adjust automatically.",
                detail: "The display stays at the brightness you set, whatever the light around it.",
                why: "The screen may be too bright in the dark or too dim in sunlight, and it can use more energy.",
                action: "Nothing to do if you prefer it. You can change it in System Settings › Displays.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
]

private func displayTypeExplanation(_ token: String) -> ValueExplanation {
    let lowercased: String = token.lowercased()
    let known: [String: (name: String, detail: String)] = [
        "lcd": ("LCD", "A standard LCD flat-panel display."),
        "crt": ("CRT", "A tube (CRT) display, as used before flat panels."),
        "retinalcd": ("Retina LCD", "A Retina display: pixels are dense enough that you can't see them at a normal viewing distance."),
        "built-in_retinalcd": ("Built-in Retina LCD", "The Mac's built-in Retina display: pixels are dense enough that you can't see them at a normal viewing distance."),
        "projector": ("Projector", "A projector."),
        "television": ("Television", "A television."),
        "airplaydisplay": ("AirPlay Display", "A display the Mac reaches over AirPlay, such as an Apple TV or AirPlay-compatible TV.")
    ]
    let why: String = "The display type affects how sharp text looks and which color and brightness features are available."

    if let type = known[lowercased] {
        return .info(
            "Display type: \(type.name).",
            detail: type.detail,
            why: why,
            action: "Nothing to do.",
            confidence: .documented
        )
    }

    return .info(
        "Display type: \(humanizedToken(token)).",
        detail: lowercased.contains("retina")
            ? "Apple's name for this display. Retina displays have pixels too small to see at a normal viewing distance."
            : "Apple's name for this display, as macOS reported it.",
        why: why,
        action: "Nothing to do.",
        confidence: .observed
    )
}

private func metalSupportExplanation(_ value: String) -> ValueExplanation? {
    let why: String = "Apps and games that use Metal need a GPU that supports the version they require."

    if let range = value.range(of: #"metal(\d+)"#, options: [.regularExpression, .caseInsensitive]) {
        let version: String = String(value[range].dropFirst(5))
        return .info(
            "Supports Metal \(version), Apple's graphics and compute technology.",
            detail: "Metal is how apps use the GPU on a Mac. Newer versions add features for games, 3D, and machine learning.",
            why: why,
            action: "Nothing to do. If an app says your Mac isn't supported, compare its Metal requirement with this.",
            confidence: .documented
        )
    }

    if let family = tokenSuffix(value, after: "mtlgpufamily") {
        let name: String = family.hasPrefix("mac")
            ? "macOS GPU family \(family.dropFirst(3))"
            : family.hasPrefix("common") ? "common GPU family \(family.dropFirst(6))" : family

        return .info(
            "Supports Metal (\(name)).",
            detail: "Older versions of macOS describe Metal support by GPU family.",
            why: why,
            action: "Nothing to do.",
            confidence: .documented
        )
    }

    return nil
}

/// Decodes values such as `1512 x 982 @ 120.00Hz`, comparing them with the panel's pixels.
func displayResolutionExplanation(_ value: String, pixels: String?) -> ValueExplanation? {
    let numbers: [Double] = value
        .components(separatedBy: CharacterSet(charactersIn: "x@ H"))
        .compactMap { Double($0.trimmingCharacters(in: .letters)) }

    guard numbers.count >= 2 else {
        return nil
    }

    let width: Int = Int(numbers[0])
    let height: Int = Int(numbers[1])
    let refresh: String = numbers.count >= 3 ? " at \(Int(numbers[2].rounded())) Hz" : ""
    var detail: String?

    if let pixels {
        let panel: [Int] = pixels.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }

        if panel.count >= 2, panel[0] == width * 2, panel[1] == height * 2 {
            detail = "The panel has twice as many pixels in each direction (\(panel[0]) × \(panel[1])), so text and images look sharper at this size."
        }
    }

    return .info(
        "Looks like \(width.formatted()) × \(height.formatted())\(refresh).",
        detail: detail,
        why: "This is how much fits on screen. Larger sizes fit more but make text smaller.",
        action: "Nothing to do. You can change it in System Settings › Displays.",
        confidence: .documented
    )
}

/// Turns tokens such as `built-in-liquid-retina-xdr` into "Built-in Liquid Retina XDR".
func humanizedToken(_ token: String) -> String {
    let acronyms: Set<String> = ["xdr", "lcd", "led", "oled", "hdr", "gpu", "usb", "hdmi", "pcie"]
    let words: [String] = token
        .replacingOccurrences(of: "built-in", with: "built~in")
        .split(whereSeparator: { $0 == "-" || $0 == "_" })
        .map { word in
            let lowercased: String = word.lowercased()

            if acronyms.contains(lowercased) {
                return lowercased.uppercased()
            }

            return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
        }

    return words.joined(separator: " ").replacingOccurrences(of: "~", with: "-")
}

// MARK: - Audio

// Sources: coreaudio_device_type_builtin, spaudio_yes, and
// coreaudio_default_audio_system_device are seen in docs/value-inventory.md. The
// transports are keys in Apple's SPAudioReporter strings: airplay, avb, bluetooth,
// builtin, displayport, firewire, hdmi, network, other, pci, thunderbolt, unknown, usb,
// virtual, and wireless. bluetoothle and aggregate are unconfirmed.

let audioValueRules: [ValueRule] = [
    ValueRule(.audio, field: "coreaudio_device_transport") { context in
        tokenSuffix(context.reportedValue, after: "coreaudio_device_type_").flatMap(audioTransportExplanation)
    },

    ValueRule(.audio, field: "coreaudio_default_audio_input_device", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? defaultAudioDeviceExplanation(.input) : nil
    },

    ValueRule(.audio, field: "coreaudio_default_audio_output_device", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? defaultAudioDeviceExplanation(.output) : nil
    },

    ValueRule(.audio, field: "coreaudio_default_audio_system_device", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? defaultAudioDeviceExplanation(.system) : nil
    },

    ValueRule(.audio, field: "_properties") { context in
        if context.reportedValue.contains("default_audio_system_device") {
            return defaultAudioDeviceExplanation(.system)
        }

        if context.reportedValue.contains("default_audio_output_device") {
            return defaultAudioDeviceExplanation(.output)
        }

        if context.reportedValue.contains("default_audio_input_device") {
            return defaultAudioDeviceExplanation(.input)
        }

        return nil
    },

    ValueRule(.audio, field: "coreaudio_device_srate", unrecognizedValues: .ignore) { context in
        guard let rate = leadingInteger(context.reportedValue), rate >= 1_000 else {
            return nil
        }

        let kilohertz: String = (Double(rate) / 1_000).formatted(.number.precision(.fractionLength(0...1)))
        return .info(
            "Sample rate \(kilohertz) kHz.",
            detail: "The device was set to take or play this many samples per second.",
            why: "48 kHz and 44.1 kHz are standard. Higher rates only help in professional recording.",
            action: "Nothing to do. You can change it in Audio MIDI Setup.",
            confidence: .documented
        )
    }
]

private enum DefaultAudioRole {
    case input, output, system
}

private func defaultAudioDeviceExplanation(_ role: DefaultAudioRole) -> ValueExplanation {
    switch role {
    case .input:
        .info(
            "The default input, used for recording unless an app chooses another.",
            detail: "Apps that record sound, such as for calls or voice memos, use this device unless set otherwise.",
            why: "If the wrong microphone is the default, others may not hear you well.",
            action: "Nothing to do. You can choose the input in System Settings › Sound.",
            confidence: .documented
        )
    case .output:
        .info(
            "The default output, where sound plays unless an app chooses another.",
            detail: "Music, videos, and calls play through this device unless an app picks another.",
            why: "If sound comes from the wrong place, this is the setting to check.",
            action: "Nothing to do. You can choose the output in System Settings › Sound.",
            confidence: .documented
        )
    case .system:
        .info(
            "Plays system sounds such as alerts.",
            detail: "Alert sounds and sound effects play through this device.",
            why: "It can differ from the output used for music and calls.",
            action: "Nothing to do. You can choose it in System Settings › Sound › Sound Effects.",
            confidence: .documented
        )
    }
}

private func audioTransportExplanation(_ transport: String) -> ValueExplanation? {
    let summary: String
    let detail: String
    var confidence: ValueConfidence = .documented

    switch transport {
    case "builtin":
        summary = "Built into this Mac."
        detail = "The Mac's own speakers, microphone, or headphone jack."
    case "usb":
        summary = "Connected over USB."
        detail = "A USB audio device, such as a headset, microphone, or audio interface."
    case "bluetooth", "bluetoothle":
        summary = "Connected over Bluetooth."
        detail = "Wireless headphones, speakers, or a headset."
        confidence = transport == "bluetooth" ? .documented : .observed
    case "hdmi":
        summary = "Connected over HDMI, usually through a display or TV."
        detail = "Sound goes to the display or TV along with the picture."
    case "displayport":
        summary = "Connected over DisplayPort, usually through a display."
        detail = "Sound goes to the display's speakers along with the picture."
    case "thunderbolt":
        summary = "Connected over Thunderbolt."
        detail = "A Thunderbolt audio interface or dock."
    case "airplay":
        summary = "An AirPlay device on the network."
        detail = "Sound is sent over the network to a speaker, Apple TV, or other AirPlay receiver."
    case "virtual":
        summary = "A virtual device created by software, such as a recording or conferencing app."
        detail = "It isn't hardware: an app created it to route or capture sound."
    case "aggregate":
        summary = "An aggregate device that combines several audio devices."
        detail = "It's set up in Audio MIDI Setup to use several devices as one."
        confidence = .observed
    case "avb":
        summary = "An AVB (Audio Video Bridging) device on the network."
        detail = "Professional network audio over Ethernet."
    case "network":
        summary = "A network audio device."
        detail = "Sound travels over the local network."
    case "firewire":
        summary = "Connected over FireWire."
        detail = "An older FireWire audio interface, usually through an adapter."
    case "pci":
        summary = "Connected over PCI Express."
        detail = "An audio card installed inside the Mac."
    case "wireless":
        summary = "A wireless audio device."
        detail = "A device that connects without a cable, other than Bluetooth or AirPlay."
    case "other":
        summary = "Connected in another way."
        detail = "macOS reported the connection as Other."
    case "unknown":
        summary = "macOS doesn't know how this device is connected."
        detail = "macOS reported the connection as Unknown."
    default:
        return nil
    }

    return .info(
        summary,
        detail: detail,
        why: "How a device connects affects its delay and sound quality. Wireless connections add a little delay.",
        action: "Nothing to do.",
        confidence: confidence
    )
}

// MARK: - Thunderbolt and USB4

// Sources: receptacle_no_devices_connected and "Up to 40 Gb/s" are seen in
// docs/value-inventory.md. receptacle_connected, the link states (trained, training,
// untrained, disabled, off, Loopback, and unknown, each followed by _link_status), and
// the speeds "Up to 10/20 Gb/s x1/x2" and "Up to 40 Gb/s x1" are keys in Apple's
// SPThunderboltReporter strings. The inventory withheld this Mac's link_status_key
// values, so their current format is unconfirmed.

let thunderboltValueRules: [ValueRule] = [
    ValueRule(.thunderbolt, field: "receptacle_status_key") { context in
        switch tokenSuffix(context.reportedValue, after: "receptacle_") {
        case "no_devices_connected":
            .info(
                "Nothing is connected to this port.",
                detail: "The port was empty when the scan ran.",
                why: "It's free for a display, drive, dock, or charger.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "connected":
            .info(
                "A device is connected to this port.",
                detail: "Something was plugged into this port when the scan ran.",
                why: "The device's details are listed under this port.",
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.thunderbolt, field: "link_status_key") { context in
        thunderboltLinkExplanation(context.reportedValue)
    },

    ValueRule(.thunderbolt, field: "current_speed_key", unrecognizedValues: .ignore) { context in
        guard let speed = context.reportedValue
            .split(whereSeparator: { !$0.isNumber })
            .compactMap({ Int($0) })
            .first else {
            return nil
        }

        let standard: String? = switch speed {
        case 120, 80: "Thunderbolt 5"
        case 40: "Thunderbolt 3, Thunderbolt 4, or USB4"
        case 20: "Thunderbolt 2"
        case 10: "the first Thunderbolt"
        default: nil
        }

        return .info(
            "This port supports up to \(speed) Gb/s\(standard.map { ", the speed of \($0)" } ?? "").",
            detail: "This is the fastest data rate the port can use. Actual speed depends on the cable and the connected device.",
            why: "Fast drives, docks, and high-resolution displays need the full speed.",
            action: "Nothing to do. For full speed, use a cable rated for it.",
            confidence: .documented
        )
    }
]

private func thunderboltLinkExplanation(_ value: String) -> ValueExplanation? {
    guard let state = value.range(of: "_link_status", options: .backwards).map({ String(value[..<$0.lowerBound]).lowercased() }) else {
        return nil
    }

    return switch state {
    case "trained":
        .normal(
            "The link is up and working.",
            detail: "The port and the connected device agreed on a working connection.",
            why: "Data can flow at the link's speed.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "training":
        .info(
            "The link was still being set up when the scan ran.",
            detail: "The port and device were negotiating a connection.",
            why: "It usually finishes within a moment of plugging in.",
            action: "If a device stays unusable, unplug it and plug it back in, or try another cable.",
            confidence: .documented
        )
    case "untrained":
        .info(
            "No working link has been set up on this port.",
            detail: "The port hasn't established a connection with a device.",
            why: "It's expected when nothing is connected. With a device plugged in, it means the connection failed.",
            action: "If a device is plugged in, try another cable or port.",
            confidence: .documented
        )
    case "disabled", "off":
        .info(
            "The link is turned off.",
            detail: "The port's Thunderbolt link isn't active.",
            why: "Ports can turn their links off to save power when nothing needs them.",
            action: "Nothing to do unless a connected device doesn't work.",
            confidence: .documented
        )
    case "loopback":
        .info(
            "The link is in loopback mode.",
            detail: "The port is connected back to itself, which is used for testing.",
            why: "It's unusual outside of testing.",
            action: "Nothing to do unless a connected device doesn't work.",
            confidence: .documented
        )
    case "unknown":
        .info(
            "macOS doesn't know this link's state.",
            detail: "The port didn't report a link state.",
            why: "It doesn't mean anything is wrong.",
            action: "Nothing to do unless a connected device doesn't work.",
            confidence: .documented
        )
    default:
        nil
    }
}

// MARK: - Hardware connection states and managed settings

let hardwareStateValueRules: [ValueRule] = [
    ValueRule(.displays, field: "spdisplays_online") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "The display was on and in use when the scan ran.",
                detail: "macOS was drawing to this display.",
                why: "It's available for windows and apps.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "The display is connected but wasn't in use when the scan ran, for example because it was off or asleep.",
                detail: "macOS could see the display but wasn't drawing to it.",
                why: "Windows can't appear on it until it wakes or turns on.",
                action: "If you expected to use it, check that it's on and set to the right input.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    // Bluetooth transports: PCIe is seen in docs/value-inventory.md; USB and UART are unconfirmed.
    ValueRule(.bluetooth, field: "controller_transport") { context in
        let why: String = "It only affects how the Bluetooth chip talks to the Mac, not the range or which devices work."

        return switch context.reportedValue.lowercased() {
        case "pcie":
            .info(
                "The Bluetooth controller is built in and connected over PCI Express.",
                detail: "The Bluetooth chip is part of the Mac's combined Wi-Fi and Bluetooth module.",
                why: why,
                action: "Nothing to do.",
                confidence: .documented
            )
        case "usb":
            .info(
                "The Bluetooth controller is connected over USB, as in older Macs and plug-in Bluetooth adapters.",
                detail: "The Bluetooth chip is connected over an internal or external USB link.",
                why: why,
                action: "Nothing to do.",
                confidence: .documented
            )
        case "uart":
            .info(
                "The Bluetooth controller is built in and connected over a serial (UART) link.",
                detail: "The Bluetooth chip uses a simple serial connection inside the Mac.",
                why: why,
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    // USB: Built-in is seen in docs/value-inventory.md.
    ValueRule(.usb, field: "USBKeyHardwareType") { context in
        switch context.reportedValue {
        case "Built-in":
            .info(
                "A USB controller built into this Mac.",
                detail: "It runs the Mac's own USB or Thunderbolt ports.",
                why: "Devices plugged into those ports are listed under it.",
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.memory, field: "dimm_type") { context in
        memoryTypeExplanation(context.reportedValue)
    },

    ValueRule(.memory, field: "dimm_status") { context in
        memorySlotStatusExplanation(context.reportedValue)
    },

    ValueRule(.memory, field: "global_ecc_state") { context in
        switch tokenSuffix(context.reportedValue, after: "ecc_") {
        case "enabled":
            .normal(
                "ECC is on: the memory detects and corrects small errors.",
                detail: "Error-correcting memory checks every read for mistakes.",
                why: "It keeps rare memory errors from corrupting data or crashing the Mac.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "disabled":
            .info(
                "ECC is off: the memory doesn't correct errors.",
                detail: "Most Macs use memory without error correction.",
                why: "It's normal for most Macs. Mac Pro and iMac Pro are the Macs that use ECC memory.",
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.memory, field: "is_memory_upgradeable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "The memory can be upgraded.",
                detail: "This Mac has memory slots you can add to or replace.",
                why: "You can add memory later if you need more.",
                action: "Nothing to do. Check Apple's memory specifications for this model before buying.",
                confidence: .documented
            )
        case false?:
            .info(
                "The memory can't be upgraded.",
                detail: "The memory is built in and can't be added to or replaced.",
                why: "The amount you have now is what this Mac will always have.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.cardReader, field: "spcardreader_link-speed", unrecognizedValues: .ignore) { context in
        cardReaderLinkExplanation(context.reportedValue)
    },

    ValueRule(.cardReader, field: "spcardreader_link-width", unrecognizedValues: .ignore) { context in
        cardReaderLinkExplanation(context.reportedValue)
    },

    // Managed preference states: always is seen in docs/value-inventory.md; often and
    // once are the other management frequencies Apple's managed preferences use.
    ValueRule(.managedClient, field: "data_state") { context in
        let why: String = "It decides whether you can change this setting yourself."

        return switch context.reportedValue.lowercased() {
        case "always":
            .info(
                "Enforced: the setting is always applied, and users can't change it.",
                detail: "An organization or administrator manages this setting.",
                why: why,
                action: "Nothing to do on a managed Mac. To change it, contact whoever manages this Mac.",
                confidence: .documented
            )
        case "often":
            .info(
                "Applied again each time someone logs in, but users can change it in between.",
                detail: "The managed value is restored at every login.",
                why: why,
                action: "Nothing to do. Changes you make last only until you log out.",
                confidence: .documented
            )
        case "once":
            .info(
                "Applied once as a starting point; users can change it afterward.",
                detail: "The managed value was set once, and later changes are kept.",
                why: why,
                action: "Nothing to do.",
                confidence: .documented
            )
        default:
            nil
        }
    }
]

/// Reads memory types such as `LPDDR5` or `DDR4`.
func memoryTypeExplanation(_ value: String) -> ValueExplanation? {
    let type: String = value.uppercased()

    if type.hasPrefix("LPDDR") {
        return .info(
            "\(value) memory, a low-power type that is built in and can't be upgraded.",
            detail: "Low-power memory is soldered in place, close to the processor.",
            why: "It saves energy and is fast, but the amount can't be changed later.",
            action: "Nothing to do.",
            confidence: .documented
        )
    }

    if type.hasPrefix("DDR") {
        return .info(
            "\(value) memory, a standard desktop and notebook memory type.",
            detail: "Some Macs with this type have slots for upgrading; others have it built in.",
            why: "Replacement or added memory must be the same type.",
            action: "Nothing to do. Check whether this model's memory is upgradeable before buying more.",
            confidence: .documented
        )
    }

    return nil
}

/// Memory slot states are keys in Apple's SPMemoryReporter strings: ok, empty,
/// mapped_out, and unknown.
private func memorySlotStatusExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "ok":
        .normal(
            "The memory in this slot is working.",
            detail: "macOS found memory in this slot and it passed its checks.",
            why: "The Mac can use all of it.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "empty":
        .info(
            "This memory slot is empty.",
            detail: "No memory module is installed in this slot.",
            why: "It's room to add memory later.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "mapped_out":
        .review(
            "This memory slot was switched off (mapped out) because of errors.",
            detail: "macOS found problems with the memory in this slot and stopped using it.",
            why: "The Mac has less memory available than is installed, and the module may be faulty.",
            action: "Reseat or replace the module in this slot, or have the Mac checked.",
            confidence: .documented
        )
    case "unknown":
        .info(
            "macOS couldn't read this memory slot's status.",
            detail: "The slot didn't report whether it's working.",
            why: "It doesn't mean anything is wrong.",
            action: "Nothing to do unless the Mac reports less memory than expected.",
            confidence: .documented
        )
    default:
        nil
    }
}

private func cardReaderLinkExplanation(_ value: String) -> ValueExplanation? {
    guard decodeBooleanLike(value) == false else {
        return nil
    }

    return .info(
        "The card reader's link was inactive when the scan ran.",
        detail: "The reader's connection to the Mac wasn't running.",
        why: "It's expected when no card is inserted. The reader starts up when you insert one.",
        action: "Nothing to do. If a card isn't recognized, remove it and insert it again.",
        confidence: .likely(reasons: [
            "Card readers usually report an inactive link when no card is inserted."
        ])
    )
}

// MARK: - Disc burning

// Sources: the macOS samples in https://github.com/glpi-project/glpi-agent
// (resources/macos/system_profiler) show burn_support (DRDeviceSupportLevelAppleShipping),
// device_media (media_none), device_readdvd (yes), interconnect (ATAPI), device_cdwrite
// (-R, -RW), device_dvdwrite (-R, -R DL, -RW, +R, +R DL, +RW), and device_strategies
// (CD-TAO, CD-SAO, CD-Raw, DVD-DAO). The other support levels and interconnects are
// constants of Apple's Disc Recording framework (DRDeviceSupportLevel… and
// DRDevicePhysicalInterconnect…), listed in
// https://developer.apple.com/library/archive/releasenotes/General/APIDiffsMacOSX10_10_3/modules/DiscRecording.html,
// and their exact spelling in system_profiler output is unconfirmed.

let discBurningValueRules: [ValueRule] = [
    ValueRule(.discBurning, field: "burn_support") { context in
        discSupportLevelExplanation(context.reportedValue)
    },

    ValueRule(.discBurning, field: "device_media") { context in
        switch context.reportedValue {
        case "media_none":
            .info(
                "There was no disc in the drive when the scan ran.",
                detail: "The drive is empty.",
                why: "Details about a disc appear here only while one is inserted.",
                action: "Nothing to do.",
                confidence: .observed
            )
        default:
            nil
        }
    },

    ValueRule(.discBurning, field: "device_readdvd") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "The drive can read DVDs as well as CDs.",
                detail: "It can play and copy from DVD discs.",
                why: "A CD-only drive can't read DVDs at all.",
                action: "Nothing to do.",
                confidence: .observed
            )
        case false?:
            .info(
                "The drive can't read DVDs, only CDs.",
                detail: "It's a CD-only drive.",
                why: "DVD discs won't work in it.",
                action: "Nothing to do. Use a DVD drive for DVDs.",
                confidence: .observed
            )
        case nil:
            nil
        }
    },

    ValueRule(.discBurning, field: "interconnect") { context in
        discInterconnectExplanation(context.reportedValue)
    },

    ValueRule(.discBurning, field: "device_cdwrite") { context in
        discWriteFormats(context.reportedValue, disc: "CD").map { formats in
            .info(
                "The drive can write \(formats).",
                detail: "R discs can be written once. RW discs can be erased and written again.",
                why: "It tells you which blank CDs to buy for this drive.",
                action: "Nothing to do.",
                confidence: .observed
            )
        }
    },

    ValueRule(.discBurning, field: "device_dvdwrite") { context in
        discWriteFormats(context.reportedValue, disc: "DVD").map { formats in
            .info(
                "The drive can write \(formats).",
                detail: "R discs can be written once and RW discs erased and written again. DL means dual-layer, which holds about twice as much. The minus and plus formats are two competing standards.",
                why: "It tells you which blank DVDs to buy for this drive.",
                action: "Nothing to do.",
                confidence: .observed
            )
        }
    },

    ValueRule(.discBurning, field: "device_strategies") { context in
        discBurnStrategies(context.reportedValue).map { strategies in
            .info(
                "Ways the drive can write a disc: \(strategies).",
                detail: "Burning apps pick one of these. Writing a whole disc in one pass makes audio CDs without gaps between tracks.",
                why: "It only matters if a burning app asks you to choose how to write.",
                action: "Nothing to do.",
                confidence: .observed
            )
        }
    }
]

private func discSupportLevelExplanation(_ value: String) -> ValueExplanation? {
    let why: String = "It decides whether the Finder and Music can burn discs with this drive."

    return switch value {
    case "DRDeviceSupportLevelAppleShipping":
        .normal(
            "A drive Apple shipped in its Macs, so macOS fully supports burning with it.",
            detail: "Apple's Disc Recording framework recognizes it as a drive Apple shipped.",
            why: why,
            action: "Nothing to do.",
            confidence: .documented
        )
    case "DRDeviceSupportLevelAppleSupported":
        .normal(
            "macOS supports burning with this drive.",
            detail: "Apple's Disc Recording framework supports the drive, though Apple didn't ship it in a Mac.",
            why: why,
            action: "Nothing to do.",
            confidence: .documented
        )
    case "DRDeviceSupportLevelVendorSupported":
        .info(
            "Burning with this drive is supported by software from the drive's maker.",
            detail: "Apple's Disc Recording framework uses support the drive's maker provides.",
            why: why,
            action: "Nothing to do. If burning fails, check the drive maker's site for a macOS update.",
            confidence: .documented
        )
    case "DRDeviceSupportLevelUnsupported":
        .info(
            "macOS doesn't support burning with this drive. It may still read discs.",
            detail: "Apple's Disc Recording framework recognizes the drive but doesn't support writing with it.",
            why: why,
            action: "If you need to burn discs, use a drive macOS supports or the drive maker's software.",
            confidence: .documented
        )
    case "DRDeviceSupportLevelNone":
        .info(
            "The drive can't burn discs on this Mac.",
            detail: "Apple's Disc Recording framework has no burning support for it, often because it's a read-only drive.",
            why: why,
            action: "Nothing to do unless you need to burn discs.",
            confidence: .documented
        )
    default:
        nil
    }
}

private func discInterconnectExplanation(_ value: String) -> ValueExplanation? {
    let summary: String
    let detail: String

    switch value.uppercased() {
    case "ATAPI":
        summary = "A drive built into the Mac, connected over ATAPI."
        detail = "ATAPI is how internal optical drives connect, over an ATA or SATA link."
    case "USB":
        summary = "An external drive connected over USB, such as Apple's USB SuperDrive."
        detail = "The drive is connected by a USB cable."
    case "FIREWIRE":
        summary = "An external drive connected over FireWire."
        detail = "FireWire was common on Macs before Thunderbolt."
    case "SCSI":
        summary = "A drive connected over SCSI, an older connection."
        detail = "SCSI drives are rare on current Macs and usually need an adapter."
    default:
        return nil
    }

    return .info(
        summary,
        detail: detail,
        why: "It shows whether the drive is inside the Mac or plugged in, which helps if the drive stops appearing.",
        action: "Nothing to do. If an external drive doesn't appear, connect it directly to the Mac.",
        confidence: .documented
    )
}

/// Turns a format list such as `-R, -R DL, -RW, +R` into words, or nil when a format is unfamiliar.
private func discWriteFormats(_ value: String, disc: String) -> String? {
    let known: Set<String> = ["-R", "-RW", "+R", "+RW", "-R DL", "+R DL", "-RAM", "+RW DL"]
    let formats: [String] = value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard !formats.isEmpty, formats.allSatisfy({ known.contains($0) }) else {
        return nil
    }

    return englishList(formats.map { "\(disc)\($0)" })
}

/// Names each burn strategy in a list such as `CD-TAO, CD-SAO, CD-Raw, DVD-DAO`, or nil
/// when one is unfamiliar.
private func discBurnStrategies(_ value: String) -> String? {
    let names: [String: String] = [
        "CD-TAO": "CD track at once",
        "CD-SAO": "CD session at once",
        "CD-Raw": "CD raw mode",
        "DVD-DAO": "DVD disc at once",
        "BD-DAO": "Blu-ray disc at once"
    ]
    let strategies: [String] = value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    let named: [String] = strategies.compactMap { names[$0] }

    guard !strategies.isEmpty, named.count == strategies.count else {
        return nil
    }

    return englishList(named)
}
