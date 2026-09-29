import Foundation

// MARK: - Extensions

// Sources: the values seen in docs/value-inventory.md (spext_yes, spext_satisfied,
// spext_no, yes, arm64e) and the keys in Apple's SPExtensionsReporter strings:
// spext_yes, spext_no, spext_satisfied, spext_incomplete, spext_apple,
// spext_identified_developer, spext_unknown, spext_not_signed, spext_notarized,
// spext_arch_arm, spext_arch_x86, spext_arch_ppc, and spext_universal. Architecture
// names are the standard Mach-O names.

let extensionValueRules: [ValueRule] = [
    ValueRule(.extensions, field: "spext_loaded") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .info(
                "This extension was loaded and running when the scan ran.",
                detail: "macOS had loaded its code when System Information collected this report.",
                why: "Loaded extensions run with high privileges, so they can affect the whole Mac's stability and security.",
                action: "Nothing to do if you recognize it. If a third-party extension is unfamiliar, check which app or driver installed it.",
                confidence: .documented
            )
        case false?:
            .info(
                "Installed, but not loaded when the scan ran.",
                detail: "The extension is on disk, but its code wasn't running. macOS loads many extensions only when the hardware or feature that needs them is in use.",
                why: "An extension that isn't loaded has no effect until something needs it.",
                action: "Nothing to do. If a device that needs it doesn't work, check whether it's waiting for approval in System Settings › Privacy & Security.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.extensions, field: "spext_hasAllDependencies") { context in
        switch tokenSuffix(context.reportedValue, after: "spext_") ?? context.reportedValue.lowercased() {
        case "satisfied", "yes":
            .normal(
                "Everything this extension depends on is installed.",
                detail: "Every other extension it needs in order to load is present.",
                why: "It can load whenever the feature or device that needs it is used.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case "incomplete", "no":
            .review(
                "Something this extension depends on is missing, so it may not load.",
                detail: "One or more extensions it needs aren't installed or couldn't be found.",
                why: "The device or feature it supports may stop working.",
                action: "Update or reinstall the app or driver that installed it, or remove it if you no longer use it.",
                confidence: .documented
            )
        default:
            nil
        }
    },

    ValueRule(.extensions, field: "spext_has64BitIntelCode") { context in
        intelCodeExplanation(context.reportedValue, processor: context.report.processor)
    },

    ValueRule(.extensions, field: "spext_loadable") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "macOS can load this extension.",
                detail: "It's built for this kind of Mac, and nothing in the security policy stops it from loading.",
                why: "It can run when the device or feature that needs it is used.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "macOS reports that this extension can't be loaded here.",
                detail: "Common reasons are that it wasn't built for this Mac, it hasn't been approved, or the startup security policy doesn't allow it.",
                why: "The device or feature that needs it won't work until it can load.",
                action: "If you use the hardware or app it belongs to, check for an update and approve it in System Settings › Privacy & Security if asked. Otherwise, you can remove the app that installed it.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.extensions, field: "spext_architectures") { context in
        extensionArchitectureExplanation(context.reportedValue)
    },

    ValueRule(.extensions, field: "spext_runtime_environment") { context in
        extensionKindExplanation(context.reportedValue)
    },

    ValueRule(.extensions, field: "spext_obtained_from") { context in
        let origin: String = tokenSuffix(context.reportedValue, after: "spext_") ?? context.reportedValue

        if origin == "not_signed" {
            return .info(
                "The extension isn't signed.",
                detail: "It has no code signature, so macOS can't confirm who made it.",
                why: "Current macOS won't load an unsigned kernel extension, and unsigned code can't be checked for changes.",
                action: "Remove it unless you know where it came from, for example from your own development work.",
                confidence: .documented
            )
        }

        return originExplanation(origin)
    },

    ValueRule(.extensions, field: "spext_notarized") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Notarized: Apple checked this extension for malware before it was distributed.",
                detail: "Its developer submitted it to Apple, and Apple's automated check found no known malware.",
                why: "Gatekeeper expects software from outside the App Store to be notarized.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Not notarized.",
                detail: "Apple hasn't checked this version for malware. Apple's own extensions and older third-party ones often aren't notarized.",
                why: "Notarization is one of the checks that tells you software from outside the App Store came from its developer unchanged.",
                action: "If it's a third-party extension you don't recognize, check which app installed it.",
                confidence: .documented
            )
        case nil:
            nil
        }
    }
]

private func intelCodeExplanation(_ value: String, processor: MacProcessorFamily?) -> ValueExplanation? {
    switch (decodeBooleanLike(value), processor) {
    case (true?, _):
        .info(
            "Includes code for Intel Macs.",
            detail: "The extension contains 64-bit Intel (x86_64) code.",
            why: "It can load on Intel Macs. On a Mac with Apple silicon, only its Apple silicon code is used.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case (false?, .intel?):
        .info(
            "Doesn't include code for Intel Macs, and this Mac has an Intel processor.",
            detail: "Without 64-bit Intel code, the extension can't load on this Mac.",
            why: "The device or feature that needs it won't work here.",
            action: "Check for a version of the extension, or of the app that installed it, that supports Intel Macs.",
            confidence: .documented
        )
    case (false?, _):
        .info(
            "Doesn't include code for Intel Macs.",
            detail: "The extension has no 64-bit Intel code, so it's built only for Macs with Apple silicon.",
            why: "It can't load on an Intel Mac, which only matters if you move it to one.",
            action: "Nothing to do on a Mac with Apple silicon.",
            confidence: .documented
        )
    case (nil, _):
        nil
    }
}

func extensionArchitectureExplanation(_ value: String) -> ValueExplanation? {
    switch value.lowercased() {
    case "arm64e":
        .info(
            "Contains code for Apple silicon (arm64e), which kernel extensions need on those Macs.",
            detail: "arm64e is Apple silicon code that uses pointer authentication.",
            why: "Kernel extensions on a Mac with Apple silicon must include arm64e code to load.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "arm64":
        .info(
            "Contains code for Apple silicon (arm64).",
            detail: "arm64 is Apple silicon code without pointer authentication.",
            why: "It's enough for most system extensions, but kernel extensions on Apple silicon need arm64e.",
            action: "Nothing to do unless the extension fails to load. Then check for an update.",
            confidence: .documented
        )
    case "x86_64":
        .info(
            "Contains code for Intel Macs (x86_64).",
            detail: "x86_64 is 64-bit Intel code.",
            why: "It lets the extension load on Intel Macs. On a Mac with Apple silicon this part isn't used.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "i386":
        .info(
            "Contains 32-bit Intel code, which current macOS can't run.",
            detail: "i386 is 32-bit Intel code. macOS stopped loading 32-bit code in macOS Catalina (10.15).",
            why: "This part of the extension is never used. If it's the only architecture listed, the extension can't load.",
            action: "If this is its only architecture, update or remove the extension.",
            confidence: .documented
        )
    default:
        nil
    }
}

private func extensionKindExplanation(_ value: String) -> ValueExplanation? {
    switch tokenSuffix(value, after: "spext_") ?? value {
    case "arch_arm":
        .info(
            "Built for Apple silicon.",
            detail: "The extension contains Apple silicon code only.",
            why: "It loads natively on a Mac with Apple silicon, but not on an Intel Mac.",
            action: "Nothing to do on a Mac with Apple silicon.",
            confidence: .documented
        )
    case "arch_x86":
        .info(
            "Built for Intel Macs.",
            detail: "The extension contains Intel code only.",
            why: "Rosetta 2 can't translate kernel code, so an Intel-only kernel extension can't load on a Mac with Apple silicon.",
            action: "On a Mac with Apple silicon, check for an updated version from its developer.",
            confidence: .documented
        )
    case "universal":
        .normal(
            "Universal: contains code for both Apple silicon and Intel Macs.",
            detail: "The extension includes a version for each kind of processor.",
            why: "It can load on either kind of Mac.",
            action: "Nothing to do.",
            confidence: .documented
        )
    case "arch_ppc":
        .info(
            "Built for PowerPC processors, which no current Mac can run.",
            detail: "The extension contains PowerPC code only.",
            why: "It can't load on this Mac.",
            action: "Remove it, or the app that installed it, if you no longer need it.",
            confidence: .documented
        )
    default:
        nil
    }
}
