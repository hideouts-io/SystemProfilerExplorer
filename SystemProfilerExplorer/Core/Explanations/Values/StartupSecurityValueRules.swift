import Foundation

// MARK: - Startup security (Apple Bridge)

// The Apple Bridge section reports the startup security policy the Mac's security
// controller enforces. Full Security with every protection on is the default; lower
// levels can only be chosen in Startup Security Utility in macOS Recovery.

let iBridgeValueRules: [ValueRule] = [
    ValueRule(.iBridge, field: "ibridge_secure_boot") { context in
        secureBootExplanation(context.reportedValue)
    },

    ValueRule(.iBridge, field: "ibridge_sb_sip") { context in
        let value: String = context.reportedValue.lowercased()

        if value.contains("custom") {
            return .review(
                "System Integrity Protection is only partly on (a custom configuration).",
                detail: "Some of its protections were turned off, which is normally done only for development or troubleshooting.",
                action: "If you didn't change it deliberately, start up in macOS Recovery and run csrutil enable in Terminal.",
                confidence: .documented
            )
        }

        switch decodeBooleanLike(value) {
        case true?:
            return .normal(
                "System Integrity Protection is on in the startup security policy, which is the default.",
                confidence: .documented
            )
        case false?:
            return .review(
                "System Integrity Protection is off in the startup security policy.",
                detail: "It is normally turned off only on purpose, for example for kernel or driver development.",
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
                confidence: .documented
            )
        case false?:
            .review(
                "The Signed System Volume is off, so macOS doesn't check that its system files are unchanged.",
                detail: "This can only be turned off from macOS Recovery with System Integrity Protection off, usually for system-level development.",
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
                confidence: .documented
            )
        case false?:
            .review(
                "Kernel code isn't locked read-only after startup (CTRR is off).",
                detail: "This protection is normally always on. It is expected to be off only with a lowered startup security policy used for kernel development.",
                action: "If you didn't lower the security policy deliberately, restore Full Security in Startup Security Utility in macOS Recovery."
            )
        case nil:
            nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_boot_args") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case true?:
            .normal("Custom startup arguments (boot-args) are filtered out, which is the default.")
        case false?:
            .info(
                "Custom startup arguments (boot-args) are allowed.",
                detail: "Developers use them to change how the kernel starts, for example for debugging. They need a lowered startup security policy.",
                action: "If you don't use custom startup arguments, restore Full Security in Startup Security Utility in macOS Recovery."
            )
        case nil:
            nil
        }
    },

    ValueRule(.iBridge, field: "ibridge_sb_other_kext") { context in
        switch decodeBooleanLike(context.reportedValue) {
        case false?:
            .normal("Kernel extensions from other developers aren't allowed to load, which is the default.", confidence: .documented)
        case true?:
            .info(
                "Kernel extensions from other developers are allowed to load.",
                detail: "This is chosen in Startup Security Utility with Reduced Security, usually for older drivers such as audio interfaces or storage hardware. Each extension still needs approval before it loads.",
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
            confidence: .documented
        )
    }

    if level.hasPrefix("reduced") {
        return .info(
            "Reduced Security: this Mac can start up older signed macOS versions, and can be allowed to load kernel extensions from other developers.",
            detail: "It can only be chosen by an administrator in Startup Security Utility in macOS Recovery, usually for older drivers or macOS versions.",
            action: "If you didn't choose it, restore Full Security in Startup Security Utility.",
            confidence: .documented
        )
    }

    if level.hasPrefix("permissive") {
        return .review(
            "Permissive Security: some startup protections are turned off, such as System Integrity Protection.",
            detail: "This level is used for kernel and system development.",
            action: "If you didn't choose it, turn System Integrity Protection back on and restore Full Security in macOS Recovery.",
            confidence: .documented
        )
    }

    if level.hasPrefix("medium") {
        return .info(
            "Medium Security: this Mac can start up any macOS version Apple has ever signed, including ones without the latest security fixes.",
            action: "If you didn't choose it, restore Full Security in Startup Security Utility in macOS Recovery.",
            confidence: .documented
        )
    }

    if level.hasPrefix("no security") {
        return .review(
            "No Security: this Mac doesn't check the operating system it starts up.",
            action: "If you didn't choose it, restore Full Security in Startup Security Utility in macOS Recovery.",
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

    switch (decodeBooleanLike(value), approval) {
    case (false?, .person):
        return .normal("No one has allowed device management (MDM) to perform privileged operations on this Mac.")
    case (false?, .enrollment):
        return .normal("Automated Device Enrollment hasn't allowed device management (MDM) to perform privileged operations on this Mac.")
    case (true?, .person):
        return .info(
            "Someone allowed device management (MDM) to perform privileged operations on this Mac, such as managing kernel extensions and software updates.",
            action: "If this Mac isn't managed by an organization you know, check System Settings › General › Device Management.",
            confidence: .likely(reasons: reasons)
        )
    case (true?, .enrollment):
        return .info(
            "This Mac's organization allowed its device management (MDM) to perform privileged operations, such as managing kernel extensions and software updates, through Automated Device Enrollment.",
            confidence: .likely(reasons: reasons)
        )
    case (nil, _):
        return nil
    }
}
