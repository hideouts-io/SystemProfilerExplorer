import Foundation

func firewallExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)

    if path.contains("spfirewall_applications") {
        return FieldExplanation(
            title: "Application Firewall Rule",
            meaning: "This is the incoming-connection policy macOS Application Firewall reports for the application or signed component identified by the source field.",
            significance: "Per-application rules determine whether a listening application may accept unsolicited inbound connections when the Application Firewall is enforcing policy.",
            interpretation: "A rule is configuration, not proof that the application is running, listening, reachable, remotely controlled, or that any connection occurred. Outbound traffic and packet-filter policy are separate.",
            privacy: "The application identifier can reveal installed security, sharing, remote-access, development, or organization-specific software. Review rules before publishing."
        )
    }

    return switch field {
    case "spfirewall_globalstate":
        securityStateExplanation(
            title: "Application Firewall State",
            meaning: "This reports the global state of macOS Application Firewall, which controls unsolicited incoming connections to applications and services.",
            significance: "The collected state affects whether per-application allow and deny rules are enforced for supported inbound traffic.",
            interpretation: "This is not a complete network-firewall verdict. Packet Filter, content filters, endpoint security products, router policy, IPv6, listening sockets, and sharing services require separate checks.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spfirewall_loggingenabled":
        securityStateExplanation(
            title: "Firewall Logging",
            meaning: "This reports whether macOS Application Firewall logging is enabled.",
            significance: "Logging can preserve evidence about firewall decisions and support troubleshooting of blocked or accepted inbound attempts.",
            interpretation: "Enabled logging does not guarantee complete history. Retention, log levels, privacy controls, rotation, and subsystem behavior determine what evidence remains.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spfirewall_stealthenabled":
        securityStateExplanation(
            title: "Stealth Mode",
            meaning: "This reports whether Application Firewall stealth mode is enabled, reducing responses to certain unsolicited probes when no service is listening.",
            significance: "Stealth mode can make some reconnaissance less informative by suppressing selected diagnostic responses.",
            interpretation: "Stealth mode does not make the Mac invisible and is not a substitute for service hardening or firewall policy. Required protocol traffic and allowed services can still respond.",
            reportedValue: reportedValue,
            privacy: nil
        )
    default:
        nil
    }
}

func configurationProfileExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "spconfigprofile_RemovalDisallowed":
        return securityStateExplanation(
            title: "Profile Removal Restricted",
            meaning: "This reports whether the configuration profile declares that ordinary user removal is disallowed or restricted.",
            significance: "Removal restrictions help administrators preserve required security, network, identity, and management settings.",
            interpretation: "A restriction is policy metadata, not proof that removal is impossible under every administrative, recovery, enrollment, or erase workflow.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "spconfigprofile_description":
        return FieldExplanation(
            title: "Profile Description",
            meaning: "This is human-readable descriptive metadata supplied by the configuration profile publisher.",
            significance: "It can explain the profile's intended purpose, owner, deployment, or affected settings.",
            interpretation: "The description is publisher-controlled and does not prove the stated purpose, signature validity, management authority, or current enforcement.",
            privacy: "Descriptions can contain organization, tenant, user, device, or deployment details. Review them before sharing."
        )
    case "spconfigprofile_install_date":
        return FieldExplanation(
            title: "Profile Installation Date",
            meaning: "This is the installation timestamp reported for the configuration profile.",
            significance: "It helps correlate policy changes with enrollment, management actions, software behavior, and other timeline evidence.",
            interpretation: "The timestamp does not identify who approved installation, prove continuous enforcement, or show whether the profile was replaced or reinstalled.",
            privacy: "Management timestamps can reveal device-use and administrative activity patterns. Review before publishing."
        )
    case "spconfigprofile_install_source":
        return FieldExplanation(
            title: "Profile Installation Source",
            meaning: "This describes the source or management channel associated with installation of the configuration profile.",
            significance: "It can distinguish local installation, enrollment, device management, and other deployment contexts.",
            interpretation: "A source label is not complete provenance and does not prove the current manager remains connected, authorized, or responsible for every payload.",
            privacy: "The source can identify an organization, management service, tenant, server, or enrollment method. Redact it from public reports."
        )
    case "spconfigprofile_profile_identifier", "spconfigprofile_payload_identifier":
        return FieldExplanation(
            title: path.contains("spconfigprofile_payload_identifier") ? "Payload Identifier" : "Profile Identifier",
            meaning: "This is the reverse-DNS-style identifier declared for the configuration profile or one of its payloads.",
            significance: "Identifiers distinguish policy objects and help correlate installed settings with management exports and deployment records.",
            interpretation: "The identifier is publisher-controlled and is not proof of signature validity, ownership, active enforcement, or a live management connection.",
            privacy: "Identifiers often reveal organizations, products, tenants, or internal policy names. Review them before sharing."
        )
    case "spconfigprofile_profile_uuid", "spconfigprofile_payload_uuid":
        return FieldExplanation(
            title: path.contains("spconfigprofile_payload_uuid") ? "Payload UUID" : "Profile UUID",
            meaning: "This is the unique identifier declared for the profile or payload instance.",
            significance: "The UUID supports exact correlation between installed objects, management records, logs, and replacement versions.",
            interpretation: "A UUID is correlation metadata, not authentication, integrity proof, or evidence that the payload is currently effective.",
            privacy: "Persistent UUIDs can correlate the same managed object across reports and systems. Redact them when that linkage is unnecessary."
        )
    case "spconfigprofile_verification_state":
        return FieldExplanation(
            title: "Profile Verification State",
            meaning: "This reports the verification status macOS assigned to the configuration profile when represented by System Information.",
            significance: "Verification provides context about whether macOS could validate profile signing or trust information.",
            interpretation: "A verified label does not mean every payload is safe or appropriate, and an unverified label does not by itself prove tampering. Inspect the signature chain and management provenance.",
            privacy: nil
        )
    case "spconfigprofile_version", "spconfigprofile_payload_version":
        return FieldExplanation(
            title: path.contains("spconfigprofile_payload_version") ? "Payload Version" : "Profile Version",
            meaning: "This is the format or revision value declared for the configuration profile or payload.",
            significance: "It supports correlation between installed policy objects and the versions retained by an administrator or management service.",
            interpretation: "The value is not the macOS version, does not prove a newer policy exists, and is not an integrity or enforcement verdict.",
            privacy: nil
        )
    case "spconfigprofile_payload_display_name":
        return FieldExplanation(
            title: "Payload Display Name",
            meaning: "This is the human-readable name assigned to a configuration payload.",
            significance: "It helps identify the policy domain or service configured by a nested payload.",
            interpretation: "The name is publisher-controlled and does not prove the payload's actual effect, trust, or current enforcement.",
            privacy: "Display names can reveal organizations, users, networks, services, or internal policy names. Review before publishing."
        )
    case "spconfigprofile_payload_data":
        return FieldExplanation(
            title: "Payload Data",
            meaning: "This is configuration content carried by a profile payload and exposed by System Information.",
            significance: "Payload data contains the settings macOS or an application may apply, including security, identity, network, restriction, and management policy.",
            interpretation: "Configured data is authorization or policy, not proof of successful application, current use, network contact, or compromise. Interpret it using the payload type and authoritative management records.",
            privacy: "Payload data can contain certificates, account names, server addresses, network identifiers, restrictions, and other sensitive policy. Do not publish it without careful redaction."
        )
    default:
        return nil
    }
}

func managedClientExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "data_keyValue":
        return FieldExplanation(
            title: "Managed Preference Value",
            meaning: "This is a value delivered through macOS managed-client policy for the named preference or setting.",
            significance: "Managed values can enforce or preconfigure application, account, security, network, and user-experience behavior.",
            interpretation: "A delivered value is policy evidence, not proof that the target application read it, that the setting took effect, or that related network activity occurred.",
            privacy: "Managed values can contain identities, servers, network configuration, certificates, organization details, and security policy. Treat them as sensitive."
        )
    case "data_source":
        return FieldExplanation(
            title: "Managed Preference Source",
            meaning: "This identifies the source associated with the managed preference record.",
            significance: "Source context helps correlate a setting with a configuration profile, management authority, local policy, or preference domain.",
            interpretation: "A source label does not prove the source is still connected, that the record is current, or that it caused observed system behavior.",
            privacy: "Sources can identify an organization, management system, profile, user, or internal policy domain. Review before sharing."
        )
    case "data_state":
        return FieldExplanation(
            title: "Managed Preference State",
            meaning: "This reports the management state or enforcement context associated with the preference record.",
            significance: "The state helps distinguish mandatory, recommended, active, or otherwise categorized managed settings.",
            interpretation: "The label describes policy representation and is not proof that an application complied or that the setting remained effective throughout the reporting period.",
            privacy: nil
        )
    default:
        return nil
    }
}

private func securityStateExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String,
    privacy: String?
) -> FieldExplanation {
    let state: String = switch reportedValue.lowercased() {
    case "1", "yes", "true", "enabled": "enabled"
    case "0", "no", "false", "disabled": "disabled"
    default: "reported as \(reportedValue)"
    }

    return FieldExplanation(
        title: title,
        meaning: meaning,
        significance: "\(significance) The collected state is \(state).",
        interpretation: interpretation,
        privacy: privacy
    )
}
