import Foundation

// MARK: - Graphics and displays

let displayValueRules: [ValueRule] = [
    ValueRule(.displays, field: "spdisplays_display_type") { context in
        tokenSuffix(context.reportedValue, after: "spdisplays_").map {
            .info("Display type: \(humanizedToken($0)).")
        }
    },

    ValueRule(.displays, field: "spdisplays_connection_type") { context in
        switch tokenSuffix(context.reportedValue, after: "spdisplays_") {
        case "internal": .info("The built-in display.")
        case "external": .info("An external display.")
        default: nil
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
        return .info("The panel has \(numbers[0].formatted()) × \(numbers[1].formatted()) pixels\(retina).")
    },

    ValueRule(.displays, field: "_spdisplays_resolution", unrecognizedValues: .ignore) { context in
        displayResolutionExplanation(context.reportedValue, pixels: context.sibling("_spdisplays_pixels"))
    },

    ValueRule(.displays, field: "spdisplays_mtlgpufamilysupport") { context in
        guard let range = context.reportedValue.range(of: #"metal(\d+)"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        let version: String = String(context.reportedValue[range].dropFirst(5))
        return .info("Supports Metal \(version), Apple's graphics and compute technology.", confidence: .documented)
    },

    ValueRule(.displays, field: "spdisplays_vendor") { context in
        tokenSuffix(context.reportedValue, after: "vendor_").map { .info("Made by \($0).") }
    },

    ValueRule(.displays, field: "sppci_device_type") { context in
        switch tokenSuffix(context.reportedValue, after: "spdisplays_") {
        case "gpu": .info("A graphics processor (GPU).")
        default: nil
        }
    },

    ValueRule(.displays, field: "sppci_bus") { context in
        switch tokenSuffix(context.reportedValue, after: "spdisplays_") {
        case "builtin": .info("Built into the Mac's chip, not a separate graphics card.")
        case "pcie": .info("Connected over PCI Express, as a separate graphics card.")
        default: nil
        }
    },

    ValueRule(.displays, field: "sppci_cores", unrecognizedValues: .ignore) { context in
        leadingInteger(context.reportedValue).map { .info("\($0) GPU cores.") }
    },

    ValueRule(.displays, field: "spdisplays_main", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true
            ? .info("The main display, which shows the menu bar and Dock.", confidence: .documented)
            : nil
    },

    ValueRule(.displays, field: "spdisplays_mirror", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true
            ? .info("This display mirrors another display.")
            : nil
    },

    ValueRule(.displays, field: "spdisplays_ambient_brightness", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true
            ? .info("Brightness adjusts automatically to the light around the Mac.", confidence: .documented)
            : nil
    }
]

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

    return .info("Looks like \(width.formatted()) × \(height.formatted())\(refresh).", detail: detail)
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

let audioValueRules: [ValueRule] = [
    ValueRule(.audio, field: "coreaudio_device_transport") { context in
        guard let transport = tokenSuffix(context.reportedValue, after: "coreaudio_device_type_") else {
            return nil
        }

        return switch transport {
        case "builtin": .info("Built into this Mac.")
        case "usb": .info("Connected over USB.")
        case "bluetooth", "bluetoothle": .info("Connected over Bluetooth.")
        case "hdmi": .info("Connected over HDMI, usually through a display or TV.")
        case "displayport": .info("Connected over DisplayPort, usually through a display.")
        case "thunderbolt": .info("Connected over Thunderbolt.")
        case "airplay": .info("An AirPlay device on the network.")
        case "virtual": .info("A virtual device created by software, such as a recording or conferencing app.")
        case "aggregate": .info("An aggregate device that combines several audio devices.")
        default: nil
        }
    },

    ValueRule(.audio, field: "coreaudio_default_audio_input_device", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? .info("The default input, used for recording unless an app chooses another.") : nil
    },

    ValueRule(.audio, field: "coreaudio_default_audio_output_device", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? .info("The default output, where sound plays unless an app chooses another.") : nil
    },

    ValueRule(.audio, field: "coreaudio_default_audio_system_device", unrecognizedValues: .ignore) { context in
        decodeBooleanLike(context.reportedValue) == true ? .info("Plays system sounds such as alerts.") : nil
    },

    ValueRule(.audio, field: "_properties") { context in
        if context.reportedValue.contains("default_audio_system_device") {
            return .info("Plays system sounds such as alerts.")
        }

        if context.reportedValue.contains("default_audio_output_device") {
            return .info("The default output, where sound plays unless an app chooses another.")
        }

        if context.reportedValue.contains("default_audio_input_device") {
            return .info("The default input, used for recording unless an app chooses another.")
        }

        return nil
    },

    ValueRule(.audio, field: "coreaudio_device_srate", unrecognizedValues: .ignore) { context in
        guard let rate = leadingInteger(context.reportedValue), rate >= 1_000 else {
            return nil
        }

        let kilohertz: String = (Double(rate) / 1_000).formatted(.number.precision(.fractionLength(0...1)))
        return .info("Sample rate \(kilohertz) kHz.")
    }
]

// MARK: - Thunderbolt and USB4

let thunderboltValueRules: [ValueRule] = [
    ValueRule(.thunderbolt, field: "receptacle_status_key") { context in
        switch tokenSuffix(context.reportedValue, after: "receptacle_") {
        case "no_devices_connected": .info("Nothing is connected to this port.")
        default: nil
        }
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
        default: nil
        }

        return .info(
            "This port supports up to \(speed) Gb/s\(standard.map { ", the speed of \($0)" } ?? "").",
            confidence: .documented
        )
    }
]
