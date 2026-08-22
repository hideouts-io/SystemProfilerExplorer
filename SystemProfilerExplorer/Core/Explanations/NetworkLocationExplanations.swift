import Foundation

func networkLocationExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    if let commonExplanation: FieldExplanation = networkExplanation(
        path: path,
        reportedValue: reportedValue
    ) {
        return commonExplanation
    }

    let field: String = semanticNetworkField(path)

    return switch field {
    case "spnetworklocation_isActive":
        networkBooleanExplanation(
            title: "Active Network Location",
            meaning: "This reports whether the network location was the active collection of network-service settings when the scan ran.",
            significance: "Only the active location normally supplies the Mac's current service order and location-specific network configuration.",
            interpretation: "An inactive location is retained configuration, not evidence of current connectivity or recent use.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "JoinMode":
        FieldExplanation(
            title: "Wi‑Fi Join Mode",
            meaning: "This describes how the network service is configured to join wireless networks, such as preferring known networks or requiring explicit selection.",
            significance: "Join policy influences whether the Mac can associate automatically when eligible Wi‑Fi networks become available.",
            interpretation: "The policy does not prove that a network was joined or identify which network was selected at a particular time.",
            privacy: nil
        )

    case "ACSPEnabled":
        networkBooleanExplanation(
            title: "PPP Address and Control Compression",
            meaning: "This reports whether Address-and-Control-Field-Compression negotiation is enabled for the PPP service.",
            significance: "The legacy PPP option can reduce per-packet framing overhead on compatible links.",
            interpretation: "The setting is negotiation policy, not proof that a PPP connection was established or that the peer accepted compression.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "CommDisplayTerminalWindow":
        networkBooleanExplanation(
            title: "Display PPP Terminal",
            meaning: "This controls whether a terminal window is shown during legacy PPP connection setup.",
            significance: "A visible terminal can support interactive modem or connection scripts that require user input.",
            interpretation: "The setting does not prove that a terminal appeared or that a PPP session was attempted.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "CommRedialCount":
        numericPolicyExplanation(
            title: "PPP Redial Attempts",
            meaning: "This is the configured number of times the PPP service may retry a failed connection.",
            significance: "The limit controls persistence when a modem, tunnel, or remote endpoint does not connect.",
            interpretation: "The configured count is not an activity log and does not show how many attempts actually occurred."
        )

    case "CommRedialEnabled":
        networkBooleanExplanation(
            title: "PPP Redial",
            meaning: "This controls whether the PPP service automatically retries after a connection failure.",
            significance: "Automatic redial can restore a legacy dial-up or PPP link without repeated manual action.",
            interpretation: "An enabled policy does not prove that a failure or redial occurred.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "CommRedialInterval":
        numericPolicyExplanation(
            title: "PPP Redial Interval",
            meaning: "This is the configured delay between automatic PPP redial attempts.",
            significance: "The interval limits how quickly the service retries an unavailable endpoint.",
            interpretation: "The value is policy, not evidence that the timer ran or a connection was attempted."
        )

    case "CommUseTerminalScript":
        networkBooleanExplanation(
            title: "PPP Terminal Script",
            meaning: "This controls whether the service uses an interactive terminal script during PPP connection setup.",
            significance: "Terminal scripts can automate legacy modem commands or login exchanges before PPP negotiation.",
            interpretation: "An enabled setting does not prove the script executed successfully or that credentials were transmitted.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "DialOnDemand":
        networkBooleanExplanation(
            title: "PPP Dial on Demand",
            meaning: "This controls whether eligible network activity may initiate the PPP connection automatically.",
            significance: "On-demand dialing can make a legacy or tunnel service available without a manual connect action.",
            interpretation: "The setting is authorization to attempt a connection, not proof that traffic triggered one.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "DisconnectOnFastUserSwitch":
        disconnectPolicyExplanation(
            title: "Disconnect on Fast User Switch",
            meaning: "This controls whether the service disconnects when macOS switches to another logged-in user.",
            reportedValue: reportedValue
        )

    case "DisconnectOnIdle":
        disconnectPolicyExplanation(
            title: "Disconnect When Idle",
            meaning: "This controls whether the service disconnects after the configured period without qualifying activity.",
            reportedValue: reportedValue
        )

    case "DisconnectOnLogout":
        disconnectPolicyExplanation(
            title: "Disconnect on Logout",
            meaning: "This controls whether the service disconnects when the current user logs out.",
            reportedValue: reportedValue
        )

    case "DisconnectOnSleep":
        disconnectPolicyExplanation(
            title: "Disconnect on Sleep",
            meaning: "This controls whether the service disconnects as the Mac enters sleep.",
            reportedValue: reportedValue
        )

    case "DisconnectOnWake":
        disconnectPolicyExplanation(
            title: "Disconnect after Wake",
            meaning: "This controls whether an existing service session is disconnected or reset after the Mac wakes.",
            reportedValue: reportedValue
        )

    case "DisconnectOnIdleTimer":
        numericPolicyExplanation(
            title: "Idle Disconnect Timer",
            meaning: "This is the inactivity interval used by an enabled disconnect-when-idle policy.",
            significance: "The timer determines how long the service can remain idle before macOS requests disconnection.",
            interpretation: "It is configured policy, not evidence that the session became idle or disconnected."
        )

    case "DisconnectOnWakeTimer":
        numericPolicyExplanation(
            title: "Wake Disconnect Timer",
            meaning: "This is the delay associated with a configured disconnect-after-wake policy.",
            significance: "The timer controls when macOS evaluates or performs the wake-related service reset.",
            interpretation: "The value is policy and does not prove that the Mac woke or that a VPN session was disconnected."
        )

    case "IPCPCompressionVJ":
        networkBooleanExplanation(
            title: "PPP TCP Header Compression",
            meaning: "This controls negotiation of Van Jacobson TCP header compression for the PPP service.",
            significance: "The legacy option can reduce header overhead on slow serial-style links when both peers support it.",
            interpretation: "An enabled setting does not prove negotiation succeeded or that compressed traffic occurred.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "IdleReminder":
        networkBooleanExplanation(
            title: "PPP Idle Reminder",
            meaning: "This controls whether macOS presents a reminder when a PPP service remains idle.",
            significance: "The reminder can help a user decide whether to keep or close a connection that may consume metered or limited resources.",
            interpretation: "An enabled reminder does not prove that an alert appeared or that the connection was idle.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "IdleReminderTimer":
        numericPolicyExplanation(
            title: "PPP Idle Reminder Timer",
            meaning: "This is the idle interval before an enabled PPP reminder may be presented.",
            significance: "It controls how long inactivity is tolerated before prompting the user.",
            interpretation: "The configured timer is not an activity record and does not show whether a reminder was displayed."
        )

    case "LCPEchoEnabled":
        networkBooleanExplanation(
            title: "PPP Link Echo",
            meaning: "This controls whether PPP Link Control Protocol echo requests are used to test peer responsiveness.",
            significance: "Echo monitoring can detect a link that appears connected but no longer receives responses from its peer.",
            interpretation: "An enabled setting does not prove echo packets were sent, lost, or that the link failed.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "LCPEchoFailure":
        numericPolicyExplanation(
            title: "PPP Echo Failure Limit",
            meaning: "This is the number of unanswered LCP echo checks tolerated before the PPP link may be considered failed.",
            significance: "The threshold balances failure detection against transient packet loss.",
            interpretation: "It is a configured limit, not a count of observed failures."
        )

    case "LCPEchoInterval":
        numericPolicyExplanation(
            title: "PPP Echo Interval",
            meaning: "This is the configured interval between PPP Link Control Protocol echo checks.",
            significance: "The interval affects how quickly an unresponsive peer can be detected.",
            interpretation: "The value does not show whether monitoring was active or how the peer responded."
        )

    case "Logfile":
        FieldExplanation(
            title: "PPP Log File",
            meaning: "This is the configured filesystem path for logging associated with the PPP service.",
            significance: "The path identifies where diagnostic records may be written when logging is enabled.",
            interpretation: "A configured path does not prove the file exists, contains retained history, or captured a particular connection.",
            privacy: "Log paths can contain usernames, service names, or organizational details. Review them before sharing."
        )

    case "VerboseLogging":
        networkBooleanExplanation(
            title: "Verbose Network Logging",
            meaning: "This controls whether the service requests more detailed diagnostic logging.",
            significance: "Verbose logs can provide additional negotiation and failure context during troubleshooting.",
            interpretation: "An enabled setting does not prove that logs were retained or that they contain traffic payloads. Retention and permissions require separate inspection.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "AuthenticationMethod":
        FieldExplanation(
            title: "VPN Authentication Method",
            meaning: "This describes the configured method used to authenticate the VPN connection or its user.",
            significance: "Authentication method determines which credentials, certificates, tokens, or platform services participate in establishing the tunnel.",
            interpretation: "Configuration does not prove authentication succeeded, identify the credential owner, or establish that a VPN session was active.",
            privacy: nil
        )

    case "DesignatedRequirement":
        FieldExplanation(
            title: "VPN Provider Code Requirement",
            meaning: "This is an Apple code-signing requirement used to identify the software authorized to provide the VPN service.",
            significance: "The requirement helps macOS bind a network extension configuration to software with an expected signing identity.",
            interpretation: "A configured requirement is an authorization constraint, not proof that the provider ran, connected, or is currently trustworthy. Signature verification requires the installed binary.",
            privacy: "The requirement can disclose developer-team identifiers and product identities. Review it before public sharing."
        )

    case "NEProviderBundleIdentifier":
        FieldExplanation(
            title: "VPN Provider Bundle Identifier",
            meaning: "This identifies the Network Extension component configured to implement the VPN service.",
            significance: "It links the network configuration to a specific installed application or system provider.",
            interpretation: "Presence in configuration does not prove the provider is installed, running, connected, or responsible for current traffic.",
            privacy: "The identifier reveals installed or configured VPN software. Review it before sharing."
        )

    case "OnDemandEnabled":
        networkBooleanExplanation(
            title: "VPN On Demand",
            meaning: "This controls whether macOS may automatically start the VPN when matching network conditions or destination rules are met.",
            significance: "On-demand policy can enforce or simplify tunnel use without requiring a manual connect action.",
            interpretation: "An enabled setting is authorization to evaluate rules, not proof that a rule matched or that a VPN connection was established.",
            reportedValue: reportedValue,
            privacy: nil
        )

    case "Action":
        FieldExplanation(
            title: "VPN On-Demand Action",
            meaning: "This describes the action macOS should take when an on-demand VPN rule matches.",
            significance: "The action determines whether the system attempts, evaluates, ignores, or disconnects the tunnel under the rule's conditions.",
            interpretation: "A configured action does not prove the rule matched or that the requested connection transition succeeded.",
            privacy: nil
        )

    case "InterfaceTypeMatch":
        FieldExplanation(
            title: "VPN Rule Interface Type",
            meaning: "This identifies the network-interface category to which an on-demand VPN rule applies.",
            significance: "It lets policy distinguish conditions such as Wi‑Fi, Ethernet, or cellular-style connectivity.",
            interpretation: "The match condition is policy, not evidence that the interface was active or that the rule executed.",
            privacy: nil
        )

    case "RemoteAddress":
        FieldExplanation(
            title: "VPN Remote Address",
            meaning: "This is the configured hostname or address of the remote VPN endpoint.",
            significance: "The endpoint is the remote infrastructure the provider attempts to contact when establishing the tunnel.",
            interpretation: "Configuration does not prove the endpoint resolved, authenticated, accepted a connection, or carried traffic. DNS and connection logs are needed for activity.",
            privacy: "The endpoint can disclose an employer, organization, service provider, or private infrastructure. Redact it when sharing is unnecessary."
        )

    default:
        nil
    }
}

private func disconnectPolicyExplanation(
    title: String,
    meaning: String,
    reportedValue: String
) -> FieldExplanation {
    networkBooleanExplanation(
        title: title,
        meaning: meaning,
        significance: "The policy affects how long PPP or VPN state is retained across the associated user or power transition.",
        interpretation: "The setting is not proof that the triggering event occurred or that a connection was active at the time.",
        reportedValue: reportedValue,
        privacy: nil
    )
}

private func numericPolicyExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String
) -> FieldExplanation {
    FieldExplanation(
        title: title,
        meaning: meaning,
        significance: significance,
        interpretation: interpretation,
        privacy: nil
    )
}
