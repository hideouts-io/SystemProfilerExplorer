import Foundation

func developerToolsExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)

    if path.contains("spdevtools_sdks") {
        let platform: String = sdkPlatform(path)
        return FieldExplanation(
            title: "\(platform) SDK",
            meaning: "This records an installed \(platform) software development kit version discovered with the active developer tools.",
            significance: "SDK availability determines which platform APIs, headers, libraries, simulators, and deployment targets can be used when building software.",
            interpretation: "An installed SDK does not prove that it was used to compile any particular binary, that its simulator runtime is installed, or that a connected device runs the same version.",
            privacy: nil
        )
    }

    return switch field {
    case "spinstruments_app":
        FieldExplanation(
            title: "Instruments Application",
            meaning: "This is the discovered filesystem location for Apple's Instruments performance-analysis application.",
            significance: "Its presence indicates that the developer toolchain includes the graphical profiler used for tracing CPU, memory, energy, I/O, and application behavior.",
            interpretation: "Presence does not prove Instruments was launched, granted access to protected data, or used to capture this Mac.",
            privacy: "The path can expose account names or a nonstandard toolchain location. Review it before publishing."
        )
    case "spxcode_app":
        FieldExplanation(
            title: "Xcode Application",
            meaning: "This is the filesystem location of the Xcode application associated with the reported developer toolchain.",
            significance: "It anchors compiler, SDK, simulator, signing, and build-tool interpretation to a specific Xcode installation.",
            interpretation: "The discovered application is not necessarily the command-line toolchain selected by every shell, build system, or automation environment.",
            privacy: "The path can expose account names, mounted volumes, or a custom development environment. Review it before sharing."
        )
    case "spdevtools_path":
        FieldExplanation(
            title: "Developer Directory",
            meaning: "This is the active developer directory used to locate command-line build tools and platform resources.",
            significance: "Tool selection can change compiler versions, SDK discovery, simulator support, and build results even when multiple Xcode installations are present.",
            interpretation: "This is configuration at collection time, not proof that every process or prior build used the same developer directory.",
            privacy: "A custom developer path can expose account names, volumes, projects, or internal toolchain names. Redact it when unnecessary."
        )
    case "spdevtools_version":
        FieldExplanation(
            title: "Developer Tools Version",
            meaning: "This identifies the reported Xcode or developer-tools release associated with the active toolchain.",
            significance: "The version determines compiler behavior, SDK contents, signing support, debugging capabilities, and compatibility with Apple platforms.",
            interpretation: "The label is not proof that a specific compiler binary built an artifact. Record compiler output and build provenance for that conclusion.",
            privacy: nil
        )
    default:
        nil
    }
}

func extensionExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "spext_architectures":
        return FieldExplanation(
            title: "Extension Architecture",
            meaning: "This identifies a processor architecture present in the extension's executable code.",
            significance: "The architecture determines whether the extension can load natively on the current kernel and hardware.",
            interpretation: "Architecture compatibility does not establish that the extension is loadable, approved, trusted, or currently loaded.",
            privacy: nil
        )
    case "spext_bundleid":
        return FieldExplanation(
            title: "Extension Bundle Identifier",
            meaning: "This is the reverse-DNS identifier declared by the extension bundle.",
            significance: "Bundle identifiers are used to distinguish extensions, associate policy and approvals, and correlate components with signing and vendor records.",
            interpretation: "The identifier is publisher-controlled and does not prove authorship, uniqueness, trust, or current use.",
            privacy: "Identifiers for private or internally developed extensions can reveal an organization or product name. Review before publishing."
        )
    case "spext_description", "spext_info":
        return FieldExplanation(
            title: "Extension Description",
            meaning: "This is descriptive metadata supplied by the extension bundle about its purpose or component identity.",
            significance: "It provides human-readable context when assessing an otherwise opaque bundle identifier or executable name.",
            interpretation: "Descriptive metadata is publisher-controlled and is not evidence that the claimed function is accurate or that the extension executed.",
            privacy: nil
        )
    case "spext_has64BitIntelCode":
        return softwareBooleanExplanation(
            title: "64-Bit Intel Code",
            meaning: "This reports whether the extension contains 64-bit Intel executable code.",
            significance: "The result helps identify architecture compatibility and legacy Intel-only extension inventory.",
            interpretation: "Intel code can be legitimate, and this field alone does not determine Apple-silicon compatibility, translation support, loadability, or security.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spext_hasAllDependencies":
        return softwareBooleanExplanation(
            title: "Dependencies Satisfied",
            meaning: "This reports whether System Information considers the extension's declared dependencies available.",
            significance: "Missing dependencies can prevent loading or cause a component to remain inactive.",
            interpretation: "Satisfied dependencies do not prove successful loading, approval, runtime stability, signature validity, or compatibility with the running kernel.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spext_lastModified":
        return FieldExplanation(
            title: "Extension Last Modified",
            meaning: "This is the filesystem modification timestamp reported for the extension bundle.",
            significance: "It can support timeline correlation with software installation, system updates, restoration, or manual changes.",
            interpretation: "Modification time is not installation, approval, load, or execution time and can be altered by copying or restoration.",
            privacy: nil
        )
    case "spext_load_address":
        return FieldExplanation(
            title: "Extension Load Address",
            meaning: "This is the kernel address associated with the loaded extension image in the collected report.",
            significance: "It can help correlate a loaded extension with low-level diagnostics, panic reports, and memory mappings from the same boot.",
            interpretation: "Addresses are boot-specific and affected by address randomization. A value does not prove malicious injection or remain valid after restart.",
            privacy: "Kernel address details can be security-sensitive diagnostic data. Omit them from public reports unless they are needed for the analysis."
        )
    case "spext_loadable":
        return softwareBooleanExplanation(
            title: "Extension Loadable",
            meaning: "This reports whether the extension appears eligible to load under the collected system conditions.",
            significance: "Loadability reflects compatibility and dependency checks that can distinguish installed code from code the system can activate.",
            interpretation: "Loadable is capability, not activity. It does not prove approval, loading, execution, trust, or persistence.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spext_loaded":
        return softwareBooleanExplanation(
            title: "Extension Loaded",
            meaning: "This reports whether the extension was loaded into the running kernel when System Information collected the data.",
            significance: "Loaded state is stronger runtime evidence than file presence and is relevant to driver behavior and kernel diagnostics.",
            interpretation: "Loaded does not mean malicious or currently busy, and unloaded does not prove the extension never loaded earlier in the boot. Correlate unified logs and kernel collections for history.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spext_path":
        return FieldExplanation(
            title: "Extension Path",
            meaning: "This is the filesystem location where the extension bundle was discovered.",
            significance: "Location helps distinguish Apple system content, third-party installations, staging areas, and unexpected copies.",
            interpretation: "Presence at a path does not prove loading, approval, trust, or ownership. Modern macOS also uses system extensions outside the legacy kernel-extension model.",
            privacy: "Paths can expose account names, organizations, volumes, or internal products. Redact them before publishing."
        )
    case "spext_signed_by":
        return FieldExplanation(
            title: "Extension Signer",
            meaning: "This is the code-signing identity reported for the extension.",
            significance: "Signer information can link the bundle to Apple or a Developer ID team and supports provenance review.",
            interpretation: "A signer label is not a complete validation. Verify the signature, certificate chain, team identifier, notarization, and designated requirement separately.",
            privacy: "Private development identities can reveal a person or organization. Review before sharing."
        )
    case "spext_version", "version":
        return FieldExplanation(
            title: "Extension Version",
            meaning: "This is version metadata declared by the extension bundle.",
            significance: "It helps correlate the installed extension with vendor releases, compatibility, and known defects.",
            interpretation: "The value is publisher-controlled and is not proof that the code is current, signed correctly, or loaded.",
            privacy: nil
        )
    default:
        return nil
    }
}

private func sdkPlatform(_ path: [String]) -> String {
    guard let sdkIndex: Int = path.firstIndex(of: "spdevtools_sdks"),
          path.indices.contains(sdkIndex + 1) else {
        return "Platform"
    }

    return path[sdkIndex + 1]
}
