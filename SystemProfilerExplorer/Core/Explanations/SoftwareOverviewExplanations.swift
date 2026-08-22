import Foundation

func softwareOverviewExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)

    return switch field {
    case "boot_mode":
        FieldExplanation(
            title: "Boot Mode",
            meaning: "This reports the startup mode macOS used for the current boot, such as a normal startup or a diagnostic and reduced-service mode.",
            significance: "The boot mode changes which drivers, startup items, caches, and services are available, so it is essential context when interpreting the rest of the report.",
            interpretation: "This is the mode reported for the current session. It does not explain why that mode was selected or prove that startup completed without errors.",
            privacy: nil
        )
    case "boot_volume":
        FieldExplanation(
            title: "Boot Volume",
            meaning: "This is the mounted volume macOS identifies as the source of the running operating system.",
            significance: "It anchors software, filesystem, and recovery analysis to the volume that supplied the active system installation.",
            interpretation: "A volume name is not a device identifier and does not by itself show which physical store, APFS snapshot, or sealed system version supplied every file.",
            privacy: "A custom volume name can contain a person, organization, project, or asset identifier. Review it before publishing the report."
        )
    case "kernel_version":
        FieldExplanation(
            title: "Kernel Version",
            meaning: "This is the Darwin/XNU kernel build string for the running macOS session.",
            significance: "It gives precise low-level build context for driver compatibility, crash analysis, security research, and comparison with Apple release information.",
            interpretation: "The string is version evidence, not an integrity or patch-completeness verdict. A security assessment still needs authoritative release data and the installed OS build.",
            privacy: nil
        )
    case "local_host_name":
        FieldExplanation(
            title: "Local Host Name",
            meaning: "This is the Bonjour-style name the Mac advertises or uses for local-network service discovery.",
            significance: "It helps correlate the computer with local sharing, discovery, logs, DHCP records, and peer-to-peer services.",
            interpretation: "The name is user-configurable and is not proof of ownership, account identity, remote access, or a stable device identity.",
            privacy: "Local host names frequently contain a person's name, organization, role, or asset label. Redact them from public reports."
        )
    case "os_version":
        FieldExplanation(
            title: "macOS Version",
            meaning: "This reports the installed macOS product version and build associated with the running system.",
            significance: "The exact build determines available features, bundled components, compatibility, and which Apple security updates should apply.",
            interpretation: "A version string does not prove that every system file is intact or that all supplemental security data is current. Compare it with authoritative Apple release information.",
            privacy: nil
        )
    case "secure_vm":
        softwareBooleanExplanation(
            title: "Secure Virtual Memory",
            meaning: "This reports the operating system's secure virtual-memory status as exposed by System Information.",
            significance: "Virtual-memory protections reduce the risk that sensitive process memory remains recoverable from swap storage without appropriate protection.",
            interpretation: "This legacy summary field is not a complete encryption or memory-security assessment and should be interpreted in the context of the macOS version and FileVault state.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "system_integrity":
        softwareBooleanExplanation(
            title: "System Integrity Protection",
            meaning: "This reports the high-level System Integrity Protection state visible to System Information.",
            significance: "SIP restricts modification of protected system locations and limits powerful operations, including for the root account.",
            interpretation: "The summary is not a complete policy audit. Individual SIP capabilities, authenticated-root state, recovery configuration, and runtime integrity require their own evidence.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "uptime":
        FieldExplanation(
            title: "System Uptime",
            meaning: "This is the elapsed time since the current macOS boot began.",
            significance: "Uptime establishes the current session's time span and helps distinguish recent changes from state that has persisted across a restart.",
            interpretation: "Uptime is not evidence that the Mac was continuously active or attended. Sleep, wake, clock changes, and hibernation need separate timeline evidence.",
            privacy: nil
        )
    case "user_name":
        FieldExplanation(
            title: "Current User",
            meaning: "This identifies the user account associated with the System Information report context.",
            significance: "The account provides context for user-scoped preferences, installed software visibility, locale settings, and accessible resources.",
            interpretation: "The reported account does not prove who was physically present, who initiated every process, or whether another account or remote session was active.",
            privacy: "Account names can directly identify a person or organization. Redact them from reports shared outside the intended investigation."
        )
    default:
        nil
    }
}

func softwareField(_ path: [String]) -> String {
    path.last(where: { $0 != "[]" }) ?? ""
}

func softwareBooleanExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String,
    privacy: String?
) -> FieldExplanation {
    let state: String = softwareStateDescription(reportedValue)

    return FieldExplanation(
        title: title,
        meaning: meaning,
        significance: "\(significance) The collected state is \(state).",
        interpretation: interpretation,
        privacy: privacy
    )
}

private func softwareStateDescription(_ reportedValue: String) -> String {
    switch reportedValue.lowercased() {
    case "yes", "true", "enabled": "enabled"
    case "no", "false", "disabled": "disabled"
    default: "reported as \(reportedValue)"
    }
}
