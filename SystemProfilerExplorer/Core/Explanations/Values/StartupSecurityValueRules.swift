import Foundation

// MARK: - Startup security (Apple Bridge)

// The Apple Bridge section reports the startup security policy the Mac's security
// controller enforces. Full Security with every protection on is the default; lower
// levels can only be chosen in Startup Security Utility in macOS Recovery.
//
// Sources: Full Security and the ibridge_sb_* values Enabled and No are seen in
// docs/value-inventory.md. Full Security, Medium Security, and No Security are keys in
// Apple's SPiBridgeReporter strings (Macs with the T2 Security Chip). Reduced Security
// and Permissive Security are the Apple silicon levels named in Apple Platform Security
// ("Startup Disk security policy control for a Mac with Apple silicon",
// https://support.apple.com/guide/security/sec7d92dc49f) and "Change security settings
// on the startup disk of a Mac with Apple silicon"
// (https://support.apple.com/guide/mac-help/mchl768f7291); their system_profiler
// spelling, "Disabled" for the protections, and "Custom Configuration" are unconfirmed.

private let restoreFullSecurity: String =
    "If you didn't choose this, start up in macOS Recovery and restore Full Security in Startup Security Utility."

let iBridgeValueRules: [ValueRule] = [
    ValueRule(.iBridge, field: "ibridge_secure_boot") { context in
        secureBootExplanation(context.reportedValue)
    },

    ValueRule(.iBridge, field: "ibridge_sb_sip") { context in
        let value: String = context.reportedValue.lowercased()
        let why: String = "System Integrity Protection stops software, even with administrator rights, from changing macOS itself."

        if value.contains("custom") {
            return .review(
                "System Integrity Protection is only partly on (a custom configuration).",
                detail: "Some of its protections were turned off, which is normally done only for development or troubleshooting.",
                why: why,
                action: "If you didn't change it deliberately, start up in macOS Recovery and run csrutil enable in Terminal.",
                confidence: .documented
            )
        }

        switch decodeBooleanLike(value) {
        case true?:
            return .normal(
                "System Integrity Protection is on in the startup security policy, which is the default.",
                detail: "The security policy this Mac starts up with keeps System Integrity Protection on.",
                why: why,
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            return .review(
                "System Integrity Protection is off in the startup security policy.",
                detail: "It is normally turned off only on purpose, for example for kernel or driver development.",
                why: "\(why) Without it, malware with administrator rights can modify macOS.",
                action: "If you didn't turn it off deliberately, start up in macOS Recovery and run csrutil enable in Terminal.",
                confidence: .documented
            )
        case nil:
            return nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_ssv") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "The Signed System Volume is on: macOS checks at startup that its system files are exactly as Apple signed them.",
                detail: "Every read from the system volume is checked against Apple's signature.",
                why: "Changed or damaged system files are caught before they can run.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .review(
                "The Signed System Volume is off, so macOS doesn't check that its system files are unchanged.",
                detail: "This can only be turned off from macOS Recovery with System Integrity Protection off, usually for system-level development.",
                why: "Changes to macOS itself, including malicious ones, wouldn't be detected.",
                action: "If you didn't turn it off deliberately, reinstall macOS or restore Full Security in Startup Security Utility.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_ctrr") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Kernel code is locked read-only after startup (CTRR), so it can't be changed while the Mac runs.",
                detail: "Apple silicon hardware locks the kernel's memory once startup finishes.",
                why: "Even an attacker who gains kernel access can't rewrite the kernel's code.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .review(
                "Kernel code isn't locked read-only after startup (CTRR is off).",
                detail: "This protection is normally always on. It is expected to be off only with a lowered startup security policy used for kernel development.",
                why: "The kernel's code could be changed while the Mac runs.",
                action: "If you didn't lower the security policy deliberately, restore Full Security in Startup Security Utility in macOS Recovery.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_boot_args") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal(
                "Custom startup arguments (boot-args) are filtered out, which is the default.",
                detail: "The security policy ignores custom kernel startup arguments.",
                why: "Startup arguments can turn off protections or change how macOS runs.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case false?:
            .info(
                "Custom startup arguments (boot-args) are allowed.",
                detail: "Developers use them to change how the kernel starts, for example for debugging. They need a lowered startup security policy.",
                why: "Startup arguments can turn off protections or change how macOS runs.",
                action: "If you don't use custom startup arguments, restore Full Security in Startup Security Utility in macOS Recovery.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_other_kext") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case false?:
            .normal(
                "Kernel extensions from other developers aren't allowed to load, which is the default.",
                detail: "Only Apple's own kernel extensions can load. Other developers' drivers use system extensions, which run outside the kernel.",
                why: "Code running in the kernel can crash or compromise the whole Mac.",
                action: "Nothing to do.",
                confidence: .documented
            )
        case true?:
            .info(
                "Kernel extensions from other developers are allowed to load.",
                detail: "This is chosen in Startup Security Utility with Reduced Security, usually for older drivers such as audio interfaces or storage hardware. Each extension still needs approval before it loads.",
                why: "Code running in the kernel can crash or compromise the whole Mac.",
                action: "If you no longer use such drivers, restore Full Security in Startup Security Utility in macOS Recovery.",
                confidence: .documented
            )
        case nil:
            nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_manual_mdm") { context in
        privilegedManagementExplanation(context.reportedValue, approvedBy: .person)
    },

    ValueRule(.iBridge, field: "ibridge_sb_device_mdm") { context in
        privilegedManagementExplanation(context.reportedValue, approvedBy: .enrollment)
    }
]

/// Reads startup security levels: `Full Security`, `Reduced Security`, and
/// `Permissive Security` on Apple silicon, and `Medium Security` and `No Security`
/// on Macs with the T2 Security Chip.
func secureBootExplanation(_ value: String) -> ValueExplanation? {
    let level: String = value.lowercased()

    if level.hasPrefix("full") {
        return .normal(
            "Full Security, the default: this Mac starts up only macOS versions that Apple currently signs and trusts.",
            detail: "At startup the Mac checks that the operating system is genuine and still trusted by Apple.",
            why: "It gives the strongest protection against tampered or outdated operating systems.",
            action: "Nothing to do.",
            confidence: .documented
        )
    }

    if level.hasPrefix("reduced") {
        return .info(
            "Reduced Security: this Mac can start up older signed macOS versions, and can be allowed to load kernel extensions from other developers.",
            detail: "It can only be chosen by an administrator in Startup Security Utility in macOS Recovery, usually for older drivers or macOS versions.",
            why: "Older macOS versions and kernel extensions can carry security problems that Full Security would block.",
            action: restoreFullSecurity,
            confidence: .documented
        )
    }

    if level.hasPrefix("permissive") {
        return .review(
            "Permissive Security: some startup protections are turned off, such as System Integrity Protection.",
            detail: "This level is used for kernel and system development.",
            why: "Protections that keep malware out of macOS itself are off.",
            action: "If you didn't choose it, turn System Integrity Protection back on and restore Full Security in macOS Recovery.",
            confidence: .documented
        )
    }

    if level.hasPrefix("medium") {
        return .info(
            "Medium Security: this Mac can start up any macOS version Apple has ever signed, including ones without the latest security fixes.",
            detail: "On a Mac with the T2 Security Chip, this is chosen in Startup Security Utility in macOS Recovery.",
            why: "An older macOS without the latest fixes could be installed and started.",
            action: restoreFullSecurity,
            confidence: .documented
        )
    }

    if level.hasPrefix("no security") {
        return .review(
            "No Security: this Mac doesn't check the operating system it starts up.",
            detail: "On a Mac with the T2 Security Chip, the startup check is turned off in Startup Security Utility.",
            why: "Any operating system, including a tampered one, can start up on this Mac.",
            action: restoreFullSecurity,
            confidence: .documented
        )
    }

    return nil
}

enum PrivilegedManagementApproval: Sendable {
    /// Approved by a person in Startup Security Utility.
    case person
    /// Approved through Automated Device Enrollment.
    case enrollment
}

private func privilegedManagementExplanation(
    _ value: String,
    approvedBy approval: PrivilegedManagementApproval
) -> ValueExplanation? {
    let reasons: [String] = [
        "The field name refers to privileged MDM operations, and Apple documents that device management can be allowed to manage kernel extensions and software updates on Macs with Reduced Security.",
        "system_profiler doesn't say which operations are allowed."
    ]
    let why: String = "Privileged management lets an organization change low-level settings on this Mac without asking you."

    switch (decodeBooleanLike(value), approval) {
    case (false?, .person):
        return .normal(
            "No one has allowed device management (MDM) to perform privileged operations on this Mac.",
            detail: "The startup security policy doesn't let a management server manage kernel extensions or software updates.",
            why: why,
            action: "Nothing to do.",
            confidence: .likely(reasons: reasons)
        )
    case (false?, .enrollment):
        return .normal(
            "Automated Device Enrollment hasn't allowed device management (MDM) to perform privileged operations on this Mac.",
            detail: "The organization that enrolled this Mac, if any, hasn't been given these rights.",
            why: why,
            action: "Nothing to do.",
            confidence: .likely(reasons: reasons)
        )
    case (true?, .person):
        return .info(
            "Someone allowed device management (MDM) to perform privileged operations on this Mac, such as managing kernel extensions and software updates.",
            detail: "This was allowed by a person in Startup Security Utility.",
            why: why,
            action: "If this Mac isn't managed by an organization you know, check System Settings › General › Device Management.",
            confidence: .likely(reasons: reasons)
        )
    case (true?, .enrollment):
        return .info(
            "This Mac's organization allowed its device management (MDM) to perform privileged operations, such as managing kernel extensions and software updates, through Automated Device Enrollment.",
            detail: "This is set by the organization that owns the Mac when it's enrolled.",
            why: why,
            action: "Nothing to do on a work or school Mac. If you own this Mac yourself, check System Settings › General › Device Management.",
            confidence: .likely(reasons: reasons)
        )
    case (nil, _):
        return nil
    }
}
