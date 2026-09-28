import Foundation

// Applications, frameworks, extensions, and install history.

let softwareArtifactValueRules: [ValueRule] = [
    ValueRule(.applications, .frameworks, field: "arch_kind") { context in
        switch context.reportedValue {
        case "arch_arm":
            .normal("Runs natively on Apple silicon.", confidence: .documented)
        case "arch_arm_i64":
            .normal("Universal: runs natively on both Apple silicon and Intel Macs.", confidence: .documented)
        case "arch_i64":
            .info(
                "Built for Intel Macs only.",
                detail: "On a Mac with Apple silicon it runs through Rosetta 2 translation, which works well but uses more power.",
                confidence: .documented
            )
        case "arch_i32", "arch_ppc":
            .info("Built for an old processor type that current macOS can't run.", confidence: .documented)
        case "arch_ios":
            .info("An iPhone or iPad app running on this Mac.", confidence: .documented)
        case "arch_other":
            .info("system_profiler didn't classify this code as Apple silicon, Intel, or iPhone and iPad code.")
        default:
            nil
        }
    },

    ValueRule(.applications, .frameworks, .extensions, field: "obtained_from") { context in
        switch context.reportedValue {
        case "apple":
            .normal("Made by Apple and included with macOS or an Apple update.", confidence: .documented)
        case "mac_app_store":
            .normal("Installed from the Mac App Store.", confidence: .documented)
        case "ios_app_store":
            .normal("Installed from the App Store as an iPhone or iPad app.", confidence: .documented)
        case "identified_developer":
            .normal(
                "From an identified developer: signed with an Apple Developer ID.",
                detail: "Gatekeeper checks this signature, and usually Apple's notarization, before the app first opens.",
                confidence: .documented
            )
        case "unknown":
            .info(
                "macOS couldn't determine where this came from. It usually isn't signed with a Developer ID.",
                detail: "Unsigned code isn't necessarily harmful; developer tools and scripts are often unsigned. Keep only software you recognize.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.installHistory, field: "package_source") { context in
        switch tokenSuffix(context.reportedValue, after: "package_source_") {
        case "apple":
            .normal("Installed by Apple, such as a macOS or security update.")
        case "other":
            .info("Installed from a third-party installer package.")
        default:
            nil
        }
    },

    ValueRule(.extensions, field: "spext_loaded") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("This extension was loaded and running when the scan ran.")
        case false?: .info("Installed, but not loaded when the scan ran.")
        case nil: nil
        }
    },

    ValueRule(.extensions, field: "spext_hasAllDependencies") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .normal("Everything this extension depends on is installed.")
        case false?: .review("Something this extension depends on is missing, so it may not load.")
        case nil: nil
        }
    },

    ValueRule(.extensions, field: "spext_has64BitIntelCode") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("Includes code for Intel Macs.")
        case false?: .info("Doesn't include code for Intel Macs.")
        case nil: nil
        }
    }
]
