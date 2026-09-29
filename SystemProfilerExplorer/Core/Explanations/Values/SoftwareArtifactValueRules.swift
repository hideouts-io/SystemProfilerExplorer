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

// MARK: - Fonts, frameworks, extensions, and the Secure Element

let softwareFlagValueRules: [ValueRule] = [
    ValueRule(.fonts, field: "type") { context in
        switch context.reportedValue.lowercased() {
        case "truetype": .info("A TrueType font, a common scalable format on Macs and PCs.", confidence: .documented)
        case "opentype": .info("An OpenType font, the current cross-platform scalable format.", confidence: .documented)
        case "postscript": .info("A PostScript font, an older format that some newer apps no longer support.")
        case "bitmap": .info("A bitmap font, drawn from fixed-size pixel images rather than scalable outlines.", confidence: .documented)
        default: nil
        }
    },

    ValueRule(.fonts, field: "enabled") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .normal("Turned on, so apps can use it.")
        case false?: .info("Turned off in Font Book, so apps can't use it.", action: "Turn it back on in Font Book if you need it.")
        case nil: nil
        }
    },

    ValueRule(.fonts, field: "valid") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal("The font file passed macOS's checks.")
        case false?:
            .info(
                "macOS found a problem in this font file.",
                detail: "A damaged font can display incorrectly or make some apps behave unexpectedly.",
                action: "Open Font Book, select the font, and choose Validate Font to see the problem."
            )
        case nil:
            nil
        }
    },

    ValueRule(.fonts, field: "duplicate") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Another copy of this typeface is installed.",
                action: "Font Book can find duplicates and turn off or remove the extra copies."
            )
        case false?:
            .normal("No other copy of this typeface is installed.")
        case nil:
            nil
        }
    },

    ValueRule(.fonts, field: "copy_protected") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("The font is marked copy-protected, so some apps won't copy or export it.")
        case false?: .normal("The font isn't copy-protected.")
        case nil: nil
        }
    },

    ValueRule(.fonts, field: "embeddable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("Its license lets apps embed it in documents such as PDFs, so they look the same on other devices.")
        case false?: .info("Its license doesn't allow embedding in documents, so a PDF may show another font on other devices.")
        case nil: nil
        }
    },

    ValueRule(.fonts, field: "outline") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?: .info("An outline font, which stays sharp at any size.", confidence: .documented)
        case false?: .info("Not an outline font: it's drawn from fixed-size bitmaps, which can look blocky when enlarged.", confidence: .documented)
        case nil: nil
        }
    },

    ValueRule(.frameworks, field: "private_framework") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info("A private framework: Apple uses it inside macOS and doesn't support other apps using it.", confidence: .documented)
        case false?:
            .info("A public framework that apps are meant to use.", confidence: .documented)
        case nil:
            nil
        }
    },

    ValueRule(.extensions, field: "spext_loadable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal("macOS can load this extension.")
        case false?:
            .info(
                "macOS reports that this extension can't be loaded here.",
                detail: "Common reasons are that it wasn't built for this Mac, it hasn't been approved, or the startup security policy doesn't allow it."
            )
        case nil:
            nil
        }
    },

    ValueRule(.extensions, field: "spext_architectures") { context in
        switch context.reportedValue.lowercased() {
        case "arm64e": .info("Contains code for Apple silicon (arm64e), which kernel extensions need on those Macs.", confidence: .documented)
        case "arm64": .info("Contains code for Apple silicon (arm64).", confidence: .documented)
        case "x86_64": .info("Contains code for Intel Macs (x86_64).", confidence: .documented)
        case "i386": .info("Contains 32-bit Intel code, which current macOS can't run.", confidence: .documented)
        default: nil
        }
    },

    ValueRule(.secureElement, field: "se_in_restricted_mode") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case false?:
            .normal("The Secure Element isn't in restricted mode.")
        case true?:
            .info(
                "The Secure Element is in restricted mode, so some of its features, such as Apple Pay, may be unavailable.",
                action: "If Apple Pay or other secure features don't work, contact Apple Support.",
                confidence: .likely(reasons: [
                    "Apple doesn't document this field. The Secure Element holds Apple Pay credentials, so limits on it would affect those features."
                ])
            )
        case nil:
            nil
        }
    },

    ValueRule(.secureElement, field: "se_prod_signed") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal("The Secure Element runs production-signed software, as Macs sold to customers do.")
        case false?:
            .info(
                "The Secure Element's software isn't production-signed, which is expected only on development or prototype hardware.",
                action: "If this is an ordinary retail Mac, contact Apple Support.",
                confidence: .likely(reasons: [
                    "Apple doesn't document this field. Its name and the other Secure Element fields suggest it reports production versus development signing."
                ])
            )
        case nil:
            nil
        }
    }
]
