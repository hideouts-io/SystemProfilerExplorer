import Foundation
import Testing
@testable import SystemProfilerExplorer

struct SecondWaveValueTests {
    @Test
    func displayTokensAreDecoded() {
        #expect(valueExplanation(dataType: .displays, path: ["spdisplays_display_type"], scalar: .string("spdisplays_built-in-liquid-retina-xdr"))?.summary
            == "Display type: Built-in Liquid Retina XDR.")
        #expect(valueExplanation(dataType: .displays, path: ["spdisplays_mtlgpufamilysupport"], scalar: .string("spdisplays_metal4"))?.summary
            == "Supports Metal 4, Apple's graphics and compute technology.")
        #expect(valueExplanation(dataType: .displays, path: ["spdisplays_vendor"], scalar: .string("sppci_vendor_Apple"))?.summary == "Made by Apple.")
    }

    @Test
    func retinaResolutionExplainsTheScale() throws {
        let explanation = try #require(displayResolutionExplanation("1512 x 982 @ 120.00Hz", pixels: "3024 x 1964"))

        #expect(explanation.summary == "Looks like 1,512 × 982 at 120 Hz.")
        #expect(explanation.detail?.contains("twice as many pixels") == true)
        #expect(displayResolutionExplanation("1920 x 1080 @ 60.00Hz", pixels: "1920 x 1080")?.detail == nil)
    }

    @Test
    func iPhoneNetworkLinksAreNotTreatedAsAdapters() throws {
        let iPhone: [String: ProfileValue] = [
            "_name": .string("iPhone"),
            "spethernet_product_name": .string("iPhone"),
            "spethernet_driver": .string("com.apple.driver.usb.cdc.ncm"),
            "spethernet_max_link_speed": .string("ethernet_speed_10000")
        ]
        let bus = try #require(valueExplanation(dataType: .ethernet, path: ["spethernet_bus"], scalar: .string("spethernet_usb_device"), siblings: iPhone))
        let usb = try #require(valueExplanation(dataType: .ethernet, path: ["spethernet_usb_device_speed"], scalar: .string("high_speed"), siblings: iPhone))

        #expect(bus.summary.contains("not a physical Ethernet adapter"))
        #expect(bus.confidence?.reasons.count == 2)
        #expect(usb.suggestedAction == nil)
    }

    @Test
    func slowUSBLinkUnderAFastAdapterIsNoted() throws {
        let adapter: [String: ProfileValue] = [
            "spethernet_product_name": .string("USB 10/100/1000 LAN"),
            "spethernet_max_link_speed": .string("ethernet_speed_1000")
        ]
        let usb = try #require(valueExplanation(dataType: .ethernet, path: ["spethernet_usb_device_speed"], scalar: .string("high_speed"), siblings: adapter))

        #expect(usb.detail?.contains("1 Gb/s (Gigabit Ethernet)") == true)
        #expect(usb.suggestedAction != nil)
        #expect(ethernetSpeedDescription(megabits: 2_500) == "2.5 Gb/s")
    }

    @Test
    func legacyReasonsMentionRosettaPlans() throws {
        let intelOnly = try #require(valueExplanation(dataType: .legacySoftware, path: ["reason"], scalar: .string("reason_x86_only")))
        let forced = try #require(valueExplanation(dataType: .legacySoftware, path: ["reason"], scalar: .string("reason_x86_forced_environmental")))

        #expect(intelOnly.detail?.contains("macOS 27") == true)
        #expect(intelOnly.confidence == .documented)
        #expect(forced.confidence?.reasons.isEmpty == false)
    }

    @Test
    func unsignedProfilesAreExplainedCalmly() throws {
        let unsigned = try #require(valueExplanation(dataType: .configurationProfiles, path: ["spconfigprofile_verification_state"], scalar: .string("unsigned")))

        #expect(unsigned.status == .informational)
        #expect(unsigned.suggestedAction?.contains("Profiles") == true)
    }

    @Test
    func accessibilityFeaturesAreExplainedOnlyWhenOn() {
        #expect(valueExplanation(dataType: .universalAccess, path: ["voiceover"], scalar: .string("on"))?.summary.contains("VoiceOver") == true)
        #expect(valueExplanation(dataType: .universalAccess, path: ["voiceover"], scalar: .string("off")) == nil)
    }

    @Test
    func observedSecondWaveValuesAreAllExplained() {
        let observed: [(SystemProfilerDataType, [String], String)] = [
            (.displays, ["spdisplays_connection_type"], "spdisplays_internal"),
            (.displays, ["sppci_device_type"], "spdisplays_gpu"),
            (.displays, ["sppci_bus"], "spdisplays_builtin"),
            (.audio, ["coreaudio_device_transport"], "coreaudio_device_type_builtin"),
            (.audio, ["_properties"], "coreaudio_default_audio_system_device"),
            (.thunderbolt, ["receptacle_status_key"], "receptacle_no_devices_connected"),
            (.thunderbolt, ["current_speed_key"], "Up to 40 Gb/s"),
            (.international, ["system_text_direction"], "text_direction_ltr"),
            (.international, ["system_uses_metric_system"], "value_no"),
            (.international, ["user_assistant_voice_gender"], "voice_gender_female"),
            (.universalAccess, ["display"], "black_on_white"),
            (.universalAccess, ["zoomMode"], "zoom_full_screen"),
            (.nvme, ["iocontent"], "Apple_APFS_ISC"),
            (.nvme, ["partition_map_type"], "guid_partition_map_type"),
            (.configurationProfiles, ["spconfigprofile_install_source"], "Manual"),
            (.printers, ["status"], "idle"),
            (.networkLocation, ["type"], "IEEE80211"),
            (.ethernet, ["spethernet_max_link_speed"], "ethernet_speed_10000")
        ]

        for (dataType, path, value) in observed {
            let explanation: ValueExplanation? = valueExplanation(dataType: dataType, path: path, scalar: .string(value))
            #expect(explanation != nil, "\(dataType.rawValue).\(path.joined(separator: ".")) = \(value) has no explanation")
            #expect(explanation?.status != .unknown, "\(dataType.rawValue).\(path.joined(separator: ".")) = \(value) is not yet explained")
        }
    }
}
