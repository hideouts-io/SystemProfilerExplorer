import Foundation

// Applications, frameworks, extensions, and install history.

let softwareArtifactValueRules: [ValueRule] = [
    ValueRule(.applications, .frameworks, field: "arch_kind") { context in
        architectureExplanation(
            context.reportedValue,
            item: context.dataType == .frameworks ? "framework" : "app",
            processor: context.report.processor
        )
    },

    ValueRule(.applications, .frameworks, .extensions, field: "obtained_from") { context in
        originExplanation(context.reportedValue)
    },

    // package_source_apple and package_source_other appear in docs/value-inventory.md.
    ValueRule(.installHistory, field: "package_source") { context in
        switch tokenSuffix(context.reportedValue, after: "package_source_") {
        case "apple":
            .normal(
                "Installed by Apple, such as a macOS or security update.",
                detail: "The package came from Apple: a macOS update, a security response, or an Apple app or component.",
                why: "Apple updates keep macOS secure, and this history shows when each one was installed.",
                action: "Nothing to do."
            )
        case "other":
            .info(
                "Installed from a third-party installer package.",
                detail: "The package came from a developer other than Apple, installed with Installer or a management tool.",
                why: "Installer packages can place software anywhere on the Mac, including background items that start at login.",
                action: "Nothing to do if you recognize the software. If you don't, check System Settings › General › Login Items & Extensions for items it added."
            )
        default:
            nil
        }
    }
]

// MARK: - Architecture and origin

private let rosettaFuture: String =
    "Apple has said Rosetta 2 stays fully available through macOS 27; after that it will only be kept for some older games, so Intel-only software may stop opening in a later macOS."

/// Explains `arch_kind`, the kind of code an app or framework contains.
///
/// Sources: `arch_arm`, `arch_arm_i64`, `arch_i64`, `arch_ios`, and `arch_other` appear in
/// docs/value-inventory.md. `arch_i32` ("32-bit (Unsupported)") and `arch_i32_i64`
/// ("32/64-bit") are keys in Apple's System Information localization strings.
/// `arch_ppc` is unconfirmed: no source shows this spelling.
func architectureExplanation(_ value: String, item: String, processor: MacProcessorFamily?) -> ValueExplanation? {
    switch value {
    case "arch_arm":
        return nativeAppleSiliconExplanation(item: item, processor: processor)
    case "arch_arm_i64":
        return .normal(
            "Universal: runs natively on both Apple silicon and Intel Macs.",
            detail: "The \(item) contains code for both kinds of processor, and macOS picks \(processorPhrase(processor, appleSilicon: "the Apple silicon code on this Mac", intel: "the Intel code on this Mac", unknown: "the code that matches the Mac it runs on")).",
            why: "It runs at full speed without Rosetta 2 translation, and keeps working if you move to another kind of Mac.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "arch_i64", "arch_i32_i64":
        return intelExplanation(value, item: item, processor: processor)
    case "arch_ios":
        return .info(
            "An iPhone or iPad app running on this Mac.",
            detail: "Macs with Apple silicon can run many iPhone and iPad apps from the App Store. It runs natively, but keeps its iPhone or iPad design. system_profiler also reports this for some Mac apps whose developer didn't mark them as Mac apps, so a familiar Mac app can show up here too.",
            why: "iPhone and iPad apps can behave differently from Mac apps, for example with touch-style controls, fixed window sizes, or missing menu commands.",
            action: "Nothing to do. If the app feels awkward on the Mac, check whether the developer offers a Mac version.",
            confidence: .documented
        )
    case "arch_other":
        return .info(
            "Not Apple silicon, Intel, or iPhone code that System Information recognizes.",
            detail: "This is common for \(item)s whose main program is a script, such as a shell or Python launcher, which then starts other code.",
            why: "The label doesn't say whether the \(item) runs natively or through Rosetta 2. On its own, it isn't a sign of a problem.",
            action: "Nothing to do unless the \(item) misbehaves. If it does, check with its developer for a current version.",
            confidence: .likely(reasons: [
                "Published system_profiler output shows this value for apps whose main program is a shell script rather than compiled code.",
                "The value's name says the code is of another kind."
            ])
        )
    case "arch_i32":
        return .info(
            "32-bit Intel code, which current macOS can't run.",
            detail: "macOS Catalina (10.15) and later only run 64-bit code, so this \(item) can't open on this Mac.",
            why: "It uses disk space but can't be used here.",
            action: "Remove it, or look for a 64-bit version from its developer.",
            confidence: .documented
        )
    case "arch_ppc":
        // Unconfirmed spelling: kept so an old PowerPC app is explained if it appears.
        return .info(
            "Built for PowerPC processors, which no current Mac can run.",
            detail: "PowerPC apps stopped working in Mac OS X Lion (10.7), so this \(item) can't open on this Mac.",
            why: "It uses disk space but can't be used here.",
            action: "Remove it, or look for a current version from its developer.",
            confidence: .documented
        )
    default:
        return nil
    }
}

private func nativeAppleSiliconExplanation(item: String, processor: MacProcessorFamily?) -> ValueExplanation {
    switch processor {
    case .intel?:
        .info(
            "Built only for Macs with Apple silicon.",
            detail: "This Mac has an Intel processor, so this \(item) can't run on it.",
            why: "Opening it fails with a message that it isn't supported on this Mac.",
            action: "Check whether the developer offers an Intel or Universal version, or remove it if you don't need it.",
            confidence: .documented
        )
    case .appleSilicon?:
        .normal(
            "Runs natively on Apple silicon.",
            detail: "It runs directly on this Mac's Apple silicon chip, with no translation.",
            why: "Native code starts faster, runs faster, and uses less power than code translated by Rosetta 2.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case nil:
        .normal(
            "Runs natively on Apple silicon.",
            detail: "It runs directly on a Mac with Apple silicon, with no translation, but can't run on an Intel Mac. Scan Hardware to see which processor this Mac has.",
            why: "Native code starts faster, runs faster, and uses less power than code translated by Rosetta 2.",
            action: "Nothing to do on a Mac with Apple silicon.",
            confidence: .documented
        )
    }
}

private func intelExplanation(_ value: String, item: String, processor: MacProcessorFamily?) -> ValueExplanation {
    let kind: String = value == "arch_i32_i64"
        ? "Built for Intel Macs only, with both 32-bit and 64-bit code."
        : "Built for Intel Macs only."
    let olderCode: String = value == "arch_i32_i64" ? " Current macOS uses only its 64-bit code." : ""

    switch processor {
    case .intel?:
        return .normal(
            kind,
            detail: "It runs natively on this Mac's Intel processor.\(olderCode)",
            why: "On a Mac with Apple silicon it would need Rosetta 2 translation. \(rosettaFuture)",
            action: "Nothing to do on this Mac. Before moving to a Mac with Apple silicon, check for a Universal version.",
            confidence: .documented
        )
    case .appleSilicon?:
        return .info(
            kind,
            detail: "This Mac has Apple silicon, so the \(item) runs through Rosetta 2, which translates its Intel code.\(olderCode)",
            why: "Translated code uses more power and can be slower. \(rosettaFuture)",
            action: "Check for an Apple silicon or Universal version: look for an update, or on the developer's website.",
            confidence: .documented
        )
    case nil:
        return .info(
            kind,
            detail: "On a Mac with Apple silicon it runs through Rosetta 2, which translates its Intel code. On an Intel Mac it runs natively.\(olderCode)",
            why: "Translated code uses more power and can be slower. \(rosettaFuture)",
            action: "On a Mac with Apple silicon, check for an Apple silicon or Universal version.",
            confidence: .documented
        )
    }
}

private func processorPhrase(_ processor: MacProcessorFamily?, appleSilicon: String, intel: String, unknown: String) -> String {
    switch processor {
    case .appleSilicon?: appleSilicon
    case .intel?: intel
    case nil: unknown
    }
}

/// Explains `obtained_from`, where macOS says an app, framework, or extension came from.
///
/// Sources: `apple`, `mac_app_store`, `identified_developer`, and `unknown` are keys in
/// Apple's System Information localization strings and appear in published output.
/// `app_store` ("App Store") is also an Apple key. `ios_app_store` is unconfirmed.
func originExplanation(_ value: String) -> ValueExplanation? {
    switch value {
    case "apple":
        .normal(
            "Made by Apple and included with macOS or an Apple update.",
            detail: "It's signed by Apple and came with macOS, an Apple app, or an Apple update.",
            why: "Apple software is updated along with macOS or through the App Store.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "mac_app_store", "app_store":
        .normal(
            "Installed from the Mac App Store.",
            detail: "Apple reviewed it before it was listed, and it's signed by Apple for the App Store.",
            why: "App Store apps run in a sandbox that limits what they can reach without your permission, and they update through the App Store.",
            action: "Nothing to do. Updates come from the App Store.",
            confidence: .documented
        )
    case "ios_app_store":
        // Unconfirmed spelling.
        .normal(
            "Installed from the App Store as an iPhone or iPad app.",
            detail: "Apple reviewed it before it was listed, and it runs on this Mac as an iPhone or iPad app.",
            why: "App Store apps run in a sandbox that limits what they can reach without your permission, and they update through the App Store.",
            action: "Nothing to do. Updates come from the App Store.",
            confidence: .documented
        )
    case "identified_developer":
        .normal(
            "From an identified developer: signed with an Apple Developer ID.",
            detail: "It was downloaded from outside the App Store. Gatekeeper checks this signature, and usually Apple's notarization, before the app first opens.",
            why: "The signature shows who made it and that it hasn't changed since it was signed. Apple can revoke a Developer ID that's used for malware.",
            action: "Nothing to do if you recognize it. Its updates come from the developer, not the App Store.",
            confidence: .documented
        )
    case "unknown":
        .info(
            "macOS couldn't determine where this came from. It usually isn't signed with a Developer ID.",
            detail: "It isn't signed by Apple, the App Store, or a Developer ID, or its signature couldn't be checked. Developer tools, scripts, and things you built yourself are often like this.",
            why: "Without a trusted signature, macOS can't show who made it or confirm that it hasn't been changed. That alone doesn't mean it's harmful.",
            action: "Keep it if you know where it came from. If you don't, look at its location and remove it if you don't need it.",
            confidence: .documented
        )
    default:
        nil
    }
}

// MARK: - Fonts, frameworks, extensions, and the Secure Element

let softwareFlagValueRules: [ValueRule] = [
    // Font kinds are keys in Apple's SPFontReporter strings: truetype, opentype,
    // postscript, bitmap, and unknown. On/off flags are reported as yes and no.
    ValueRule(.fonts, field: "type") { context in
        switch context.reportedValue.lowercased() {
        case "truetype":
            .info(
                "A TrueType font, a common scalable format on Macs and PCs.",
                detail: "Its characters are stored as TrueType outlines, which scale smoothly to any size.",
                why: "Almost every app on Mac and Windows can use TrueType fonts.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "opentype":
            .info(
                "An OpenType font, the current cross-platform scalable format.",
                detail: "OpenType builds on TrueType and can hold extra typographic features, such as ligatures and alternate characters, and many languages in one file.",
                why: "It's the most widely supported font format today, so documents that use it look the same on Macs and PCs.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "postscript":
            .info(
                "A PostScript font, an older format that some newer apps no longer support.",
                detail: "It's a PostScript Type 1 font, the format desktop publishing used before OpenType.",
                why: "Several apps, including Adobe's since 2023, no longer support Type 1 fonts, so documents that use it may show a substitute font.",
                action: "If an app can't use it, look for an OpenType version from the font's vendor."
            )
        case "bitmap":
            .info(
                "A bitmap font, drawn from fixed-size pixel images rather than scalable outlines.",
                detail: "Its characters are pixel images made for particular sizes.",
                why: "It looks sharp only at the sizes it was made for, and blocky when enlarged or printed.",
                action: "Nothing to do. If text looks blocky, choose an outline font instead.",
                confidence: .documented
            )
        case "unknown":
            .info(
                "macOS couldn't tell what format this font file uses.",
                detail: "System Information didn't recognize the file as TrueType, OpenType, PostScript, or bitmap.",
                why: "Apps may not be able to use a font whose format isn't recognized.",
                action: "Open Font Book, select the font, and choose Validate Font to check the file.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.fonts, field: "enabled") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Turned on, so apps can use it.",
                detail: "It's active in Font Book, so it appears in apps' font menus.",
                why: "Only fonts that are turned on can be used in documents.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Turned off in Font Book, so apps can't use it.",
                detail: "It's installed but turned off, so it doesn't appear in font menus. Documents that use it show a substitute font.",
                why: "Turning off fonts you don't use keeps font menus short, but documents that need this font won't look as designed.",
                action: "Turn it back on in Font Book if you need it.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.fonts, field: "valid") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "The font file passed macOS's checks.",
                detail: "macOS checked the file's structure and found no problems.",
                why: "A valid font displays and prints as its designer intended.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "macOS found a problem in this font file.",
                detail: "The file's structure didn't pass macOS's checks, for example because it's damaged or incomplete.",
                why: "A damaged font can display incorrectly or make some apps behave unexpectedly.",
                action: "Open Font Book, select the font, and choose Validate Font to see the problem.",
                confidence: .documented
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
                detail: "More than one font file provides this typeface, for example an older and a newer version.",
                why: "Apps may use either copy, so text can look slightly different from one app or document to another.",
                action: "Font Book can find duplicates and turn off or remove the extra copies.",
                confidence: .documented
            )
        case false?:
            .normal(
                "No other copy of this typeface is installed.",
                detail: "Only one font file provides this typeface.",
                why: "Every app uses the same version of it.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.fonts, field: "copy_protected") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "The font is marked copy-protected, so some apps won't copy or export it.",
                detail: "Its maker set a flag asking apps not to copy the font's data.",
                why: "Apps that honor the flag may refuse to include it in PDFs or exported files, so documents can look different elsewhere.",
                action: "If you share documents that use it, check the font's license, or use another font.",
                confidence: .documented
            )
        case false?:
            .normal(
                "The font isn't copy-protected.",
                detail: "Its maker didn't set a flag restricting copying.",
                why: "Apps can include it when exporting documents, as far as its license allows.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.fonts, field: "embeddable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "Its license lets apps embed it in documents such as PDFs, so they look the same on other devices.",
                detail: "The font's embedding permission allows apps to include it in the files they create.",
                why: "People who open your documents see this font even if they don't have it installed.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Its license doesn't allow embedding in documents, so a PDF may show another font on other devices.",
                detail: "The font's embedding permission tells apps not to include it in the files they create.",
                why: "Documents you share can look different for people who don't have this font installed.",
                action: "For documents you share, choose a font that allows embedding.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.fonts, field: "outline") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "An outline font, which stays sharp at any size.",
                detail: "Its characters are stored as outlines that are drawn at whatever size is needed.",
                why: "Text stays crisp on screen and in print, at any size.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Not an outline font: it's drawn from fixed-size bitmaps, which can look blocky when enlarged.",
                detail: "Its characters are stored as pixel images made for particular sizes.",
                why: "It looks sharp only at the sizes it was made for.",
                action: "Nothing to do. For large or printed text, choose an outline font.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.frameworks, field: "private_framework") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "A private framework: Apple uses it inside macOS and doesn't support other apps using it.",
                detail: "It's shared code that parts of macOS load, not something you open. Apple doesn't publish it for other developers.",
                why: "Private frameworks can change or disappear in any macOS update, which is why apps that rely on them sometimes break after updating.",
                action: "Nothing to do. It belongs to macOS; don't remove it.",
                confidence: .documented
            )
        case false?:
            .info(
                "A public framework that apps are meant to use.",
                detail: "It's shared code that apps can load. Its developer, often Apple, publishes it for other software to build on.",
                why: "Many apps may depend on it, so removing or replacing it can stop them from opening.",
                action: "Nothing to do. If it isn't Apple's, it usually came with an app or a driver you installed.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.secureElement, field: "se_in_restricted_mode") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case false?:
            .normal(
                "The Secure Element isn't in restricted mode.",
                detail: "The chip that stores Apple Pay cards reports that it works without restrictions.",
                why: "Apple Pay and other features that use it can work normally.",
                action: "Nothing to do.",
                confidence: .likely(reasons: [
                    "Apple doesn't document this field. The Secure Element holds Apple Pay credentials, so limits on it would affect those features."
                ])
            )
        case true?:
            .info(
                "The Secure Element is in restricted mode, so some of its features, such as Apple Pay, may be unavailable.",
                detail: "The chip that stores Apple Pay cards reports that it's restricted.",
                why: "Apple Pay on this Mac may not work.",
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
            .normal(
                "The Secure Element runs production-signed software, as Macs sold to customers do.",
                detail: "Its software is signed for retail devices.",
                why: "Apple Pay can trust it.",
                action: "Nothing to do.",
                confidence: .likely(reasons: [
                    "Apple doesn't document this field. Its name and the other Secure Element fields suggest it reports production versus development signing."
                ])
            )
        case false?:
            .info(
                "The Secure Element's software isn't production-signed, which is expected only on development or prototype hardware.",
                detail: "Its software is signed for development use.",
                why: "Apple Pay may not work on development hardware.",
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
