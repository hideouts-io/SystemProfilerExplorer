import Foundation

func applicationExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    softwareArtifactExplanation(
        path: path,
        reportedValue: reportedValue,
        artifactTitle: "Application",
        artifactMeaning: "an application bundle discovered by System Information"
    )
}

func frameworkExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)

    if field == "private_framework" {
        return softwareBooleanExplanation(
            title: "Private Framework",
            meaning: "This reports whether the framework is categorized as an implementation-private framework rather than a public developer API.",
            significance: "Private frameworks support macOS and bundled software internally and are not intended as stable interfaces for third-party applications.",
            interpretation: "Private does not mean malicious, secret, untrusted, or encrypted. It describes API support status, and the collected state does not prove the framework was loaded.",
            reportedValue: reportedValue,
            privacy: nil
        )
    }

    return softwareArtifactExplanation(
        path: path,
        reportedValue: reportedValue,
        artifactTitle: "Framework",
        artifactMeaning: "a reusable framework bundle discovered by System Information"
    )
}

func preferencePaneExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    softwareArtifactExplanation(
        path: path,
        reportedValue: reportedValue,
        artifactTitle: "Preference Pane",
        artifactMeaning: "a settings pane bundle discovered by System Information"
    )
}

func startupItemExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    softwareArtifactExplanation(
        path: path,
        reportedValue: reportedValue,
        artifactTitle: "Startup Item",
        artifactMeaning: "a legacy startup-item bundle discovered by System Information"
    )
}

private func softwareArtifactExplanation(
    path: [String],
    reportedValue: String,
    artifactTitle: String,
    artifactMeaning: String
) -> FieldExplanation? {
    switch softwareField(path) {
    case "arch_kind", "architectures":
        return FieldExplanation(
            title: "Supported Architecture",
            meaning: "This identifies a processor architecture supported by \(artifactMeaning), such as Apple silicon or Intel code.",
            significance: "Architecture determines whether the code runs natively, requires translation, or is incompatible with the current Mac.",
            interpretation: "A listed architecture does not prove the code ran, loaded successfully, or is trustworthy. Universal bundles can contain more than one architecture.",
            privacy: nil
        )
    case "info":
        return FieldExplanation(
            title: "\(artifactTitle) Information",
            meaning: "This is descriptive metadata supplied by \(artifactMeaning), commonly from its bundle information.",
            significance: "The text can distinguish similarly named components and provide vendor- or function-specific context.",
            interpretation: "Bundle metadata is publisher-controlled and is not an integrity, authorship, or execution verdict.",
            privacy: nil
        )
    case "lastModified":
        return FieldExplanation(
            title: "Last Modified",
            meaning: "This is the filesystem modification timestamp reported for \(artifactMeaning).",
            significance: "It can help correlate installation, update, restoration, or manual file activity with other timeline evidence.",
            interpretation: "Modification time is not installation time or execution time and can change during copying, restoration, package updates, or deliberate timestamp manipulation.",
            privacy: nil
        )
    case "obtained_from":
        return FieldExplanation(
            title: "Obtained From",
            meaning: "This is macOS metadata describing the apparent distribution source or trust category for \(artifactMeaning).",
            significance: "It helps distinguish Apple, identified-developer, App Store, and other provenance categories during software inventory review.",
            interpretation: "The category is not a complete chain-of-custody record and does not prove the file is safe, current, or unchanged. Validate code signatures and provenance separately.",
            privacy: nil
        )
    case "path":
        return FieldExplanation(
            title: "\(artifactTitle) Path",
            meaning: "This is the filesystem location where System Information found \(artifactMeaning).",
            significance: "Location distinguishes system, shared, user, removable-volume, and nonstandard installations and provides a target for further read-only inspection.",
            interpretation: "Presence at a path does not prove execution, persistence, trust, or ownership. Symlinks, firmlinks, snapshots, and mounted volumes can affect path interpretation.",
            privacy: "Filesystem paths can expose account names, organizations, projects, mounted shares, and personal folder structure. Redact them before publishing."
        )
    case "signed_by":
        return FieldExplanation(
            title: "Code-Signing Authority",
            meaning: "This is an identity or certificate-chain entry macOS reports for the code signature associated with \(artifactMeaning).",
            significance: "Signing information supports provenance checks and can link code to an Apple or Developer ID signing identity.",
            interpretation: "A valid-looking signer name does not prove the code is benign, notarized, currently trusted, or unchanged. Verify the actual signature and designated requirement with code-signing tools.",
            privacy: "Signing identities are often public, but private organizational or development certificates can identify a team or individual. Review before sharing."
        )
    case "version":
        return FieldExplanation(
            title: "\(artifactTitle) Version",
            meaning: "This is the version metadata reported by \(artifactMeaning).",
            significance: "Version information helps correlate installed components with vendor releases, compatibility requirements, and known defects.",
            interpretation: "Version metadata is publisher-controlled and may be missing, malformed, or independent of the executable build. It is not proof that the component ran or is patched.",
            privacy: nil
        )
    default:
        return nil
    }
}
