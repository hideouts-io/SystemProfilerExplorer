import Foundation

func secureElementExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "ctl_fw":
        return secureElementVersionExplanation(
            title: "Controller Firmware",
            component: "controller firmware",
            significance: "It can help correlate secure-element communication behavior with hardware and operating-system releases."
        )
    case "ctl_hw":
        return FieldExplanation(
            title: "Controller Hardware",
            meaning: "This identifies the hardware revision or implementation of the controller used to communicate with the secure element.",
            significance: "Controller hardware provides model-specific context for diagnostics, firmware compatibility, and supported capabilities.",
            interpretation: "The identifier does not expose secret key material and is not an integrity, compromise, or attestation verdict.",
            privacy: nil
        )
    case "ctl_info":
        return FieldExplanation(
            title: "Controller Information",
            meaning: "This is descriptive status or identity information reported for the secure-element controller.",
            significance: "It provides context for the communication layer between macOS and the embedded security component.",
            interpretation: "Descriptive controller information is not proof that transactions occurred, credentials were accessed, or the controller is trusted and current.",
            privacy: nil
        )
    case "ctl_mw":
        return secureElementVersionExplanation(
            title: "Controller Middleware",
            component: "controller middleware",
            significance: "The middleware version helps correlate the macOS software layer that communicates with the secure element."
        )
    case "se_device":
        return FieldExplanation(
            title: "Secure Element Device",
            meaning: "This identifies the secure-element device or device class represented by System Information.",
            significance: "It distinguishes the embedded security component whose platform, firmware, and operating-system details follow.",
            interpretation: "Device presence does not prove that a payment, credential, key operation, or other secure transaction occurred.",
            privacy: nil
        )
    case "se_fw":
        return secureElementVersionExplanation(
            title: "Secure Element Firmware",
            component: "secure-element firmware",
            significance: "It provides build context for device-specific behavior and compatibility with the controller and macOS."
        )
    case "se_hw":
        return FieldExplanation(
            title: "Secure Element Hardware",
            meaning: "This identifies the secure element's reported hardware revision or implementation.",
            significance: "Hardware revision can determine supported security capabilities and applicable firmware or platform diagnostics.",
            interpretation: "The identifier is not secret key material and does not prove authenticity, tampering, compromise, or successful attestation.",
            privacy: nil
        )
    case "se_id":
        return FieldExplanation(
            title: "Secure Element Identifier",
            meaning: "This is an identifier reported for the embedded secure-element instance.",
            significance: "It can support exact device correlation in diagnostics and hardware service workflows.",
            interpretation: "An identifier does not expose stored secrets or prove that a credential or transaction was used. It should not be treated as a standalone trust verdict.",
            privacy: "A persistent hardware identifier can correlate this Mac or component across reports. Redact it from public output."
        )
    case "se_in_restricted_mode":
        return secureElementStateExplanation(
            title: "Restricted Mode",
            meaning: "This reports whether the secure element is operating in a restricted mode represented by the platform.",
            significance: "Restricted mode can limit available operations and is useful context for service, provisioning, and security diagnostics.",
            interpretation: "The state does not by itself explain why the mode is active, establish compromise, or identify which operation is restricted. Correlate authoritative diagnostics.",
            reportedValue: reportedValue
        )
    case "se_info":
        return FieldExplanation(
            title: "Secure Element Information",
            meaning: "This is descriptive status or identity metadata reported for the secure element.",
            significance: "It provides human-readable context for the device, platform, firmware, and operating-system fields.",
            interpretation: "The text is not an attestation, integrity proof, transaction log, or evidence that stored credentials were accessed.",
            privacy: "Review descriptive identifiers before publishing because they may correlate a particular hardware instance."
        )
    case "se_os_id":
        return FieldExplanation(
            title: "Secure Element OS Identifier",
            meaning: "This identifies the secure-element operating-system implementation or build family.",
            significance: "The identifier helps correlate platform behavior and firmware compatibility with a particular secure-element OS line.",
            interpretation: "It is not the macOS version and does not prove patch status, authenticity, compromise, or successful attestation.",
            privacy: nil
        )
    case "se_os_version":
        return secureElementVersionExplanation(
            title: "Secure Element OS Version",
            component: "secure-element operating system",
            significance: "It provides version context for embedded security services and compatibility analysis."
        )
    case "se_plt":
        return FieldExplanation(
            title: "Secure Element Platform",
            meaning: "This identifies the secure-element platform or product family represented by the hardware.",
            significance: "Platform context helps determine which capabilities, firmware lines, and diagnostics apply.",
            interpretation: "A platform label is not an integrity verdict and does not reveal whether any credential, payment, or cryptographic operation occurred.",
            privacy: nil
        )
    case "se_prod_signed":
        return secureElementStateExplanation(
            title: "Production Signed",
            meaning: "This reports whether the secure-element software is represented as using production signing rather than a development configuration.",
            significance: "Production signing is relevant to release provenance and expected platform security policy.",
            interpretation: "The summary field is not a complete cryptographic verification or attestation result and does not prove the entire system is uncompromised.",
            reportedValue: reportedValue
        )
    default:
        return nil
    }
}

func smartCardExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)

    guard field.hasPrefix("#") else {
        return nil
    }

    return FieldExplanation(
        title: "Smart Card Detail",
        meaning: "This is a numbered detail reported by the macOS Smart Card inventory for the surrounding reader, token, or support record.",
        significance: "The detail can help distinguish discovered smart-card components and correlate them with local reader and token diagnostics.",
        interpretation: "A reported entry does not prove that a card is currently inserted, authenticated, used to sign in, or accessed by a process. The surrounding record and collection time are essential.",
        privacy: "Smart-card inventory can expose token, reader, certificate, or organizational identity context. Treat numbered details as sensitive unless reviewed."
    )
}

private func secureElementVersionExplanation(
    title: String,
    component: String,
    significance: String
) -> FieldExplanation {
    FieldExplanation(
        title: title,
        meaning: "This is the version or build identifier reported for the \(component).",
        significance: significance,
        interpretation: "A version string is not an integrity, vulnerability, authenticity, compromise, or patch-completeness verdict. Compare it with authoritative model- and OS-specific information.",
        privacy: nil
    )
}

private func secureElementStateExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String
) -> FieldExplanation {
    softwareBooleanExplanation(
        title: title,
        meaning: meaning,
        significance: significance,
        interpretation: interpretation,
        reportedValue: reportedValue,
        privacy: nil
    )
}
