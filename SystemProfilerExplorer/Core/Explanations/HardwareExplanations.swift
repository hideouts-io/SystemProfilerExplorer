import Foundation

func hardwareExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch path.joined(separator: ".") {
    case "activation_lock_status":
        activationLockExplanation(reportedValue: reportedValue)

    case "boot_rom_version":
        FieldExplanation(
            title: "Boot ROM Version",
            meaning: "This is the version identifier for the Mac's low-level boot firmware. On Apple silicon, firmware updates are normally delivered as part of macOS updates rather than as separate downloads.",
            significance: "The boot firmware initializes hardware and participates in the trusted startup process before macOS loads. Its version can help correlate the Mac with a particular firmware generation when diagnosing startup or update problems.",
            interpretation: "A version string by itself does not establish that firmware is current, vulnerable, or modified. A reliable comparison requires the exact Mac model, installed macOS build, and current Apple release information.",
            privacy: nil
        )

    case "chip_type":
        FieldExplanation(
            title: "Chip",
            meaning: "This identifies the main system-on-a-chip reported by macOS. On Apple silicon it combines CPU, GPU, memory controllers, media engines, and security components in one package.",
            significance: "The chip family determines the supported instruction set and materially affects performance, graphics capability, virtualization support, and operating-system compatibility.",
            interpretation: "The marketing name does not describe the exact enabled core count, memory capacity, thermal condition, or current performance. Those are separate findings.",
            privacy: nil
        )

    case "machine_model":
        FieldExplanation(
            title: "Model Identifier",
            meaning: "This is Apple's technical model identifier for the hardware family, such as Mac15,10. Software and support documentation use it to distinguish configurations that may share the same consumer-facing name.",
            significance: "The identifier is useful when checking operating-system compatibility, firmware behavior, repair information, and model-specific technical documentation.",
            interpretation: "It identifies a model family rather than this individual device. It should not be treated as a serial number or proof of the exact retail configuration.",
            privacy: nil
        )

    case "machine_name":
        FieldExplanation(
            title: "Model Name",
            meaning: "This is the consumer-facing Mac family name reported by the operating system, such as MacBook Pro or Mac mini.",
            significance: "It provides an immediately readable description of the computer category and is useful for summaries and support conversations.",
            interpretation: "Several generations and configurations can share this name. Use the model identifier and model number for more precise identification.",
            privacy: nil
        )

    case "model_number":
        FieldExplanation(
            title: "Model Number",
            meaning: "This is Apple's configuration or order identifier for the Mac as reported by the installed hardware and firmware.",
            significance: "It can help distinguish processor, memory, storage, keyboard, region, or retail configurations within the same model family.",
            interpretation: "Apple's configuration identifiers can be region-specific and are not a complete component inventory. The value should be corroborated with the other hardware fields when exact configuration matters.",
            privacy: "This value is less unique than a serial number but may narrow the device to a particular regional or custom configuration. Review it before sharing a report publicly."
        )

    case "number_processors":
        FieldExplanation(
            title: "Processor Configuration",
            meaning: "This is system_profiler's compact representation of the processor topology. On Apple silicon it commonly includes the total CPU core count and the distribution between performance and efficiency cores.",
            significance: "Core topology affects parallel workloads, responsiveness, energy use, and the resources available to virtual machines and development tools.",
            interpretation: "The compact `proc` syntax is an implementation-oriented value and is not fully documented as a stable public format. Core count alone does not measure real-world speed or current CPU utilization.",
            privacy: nil
        )

    case "os_loader_version":
        FieldExplanation(
            title: "OS Loader Version",
            meaning: "This identifies the firmware component responsible for preparing and loading the installed operating system during startup.",
            significance: "It can help diagnose startup, recovery, and operating-system update problems, especially when considered with the Boot ROM and macOS build versions.",
            interpretation: "The version is not a security verdict. A mismatch cannot be established from this value alone without authoritative model- and OS-specific reference data.",
            privacy: nil
        )

    case "physical_memory":
        FieldExplanation(
            title: "Installed Memory",
            meaning: "This is the total physical memory available in the Mac. Apple-silicon systems use unified memory shared by the CPU, GPU, and other on-chip components.",
            significance: "Memory capacity affects how many applications, browser tabs, development workloads, virtual machines, and large data sets can remain active without increased compression or swapping.",
            interpretation: "Installed capacity does not show current memory pressure, swap activity, defective memory, or the amount presently available. Those require live memory statistics and diagnostics.",
            privacy: nil
        )

    case "platform_UUID":
        FieldExplanation(
            title: "Platform UUID",
            meaning: "This is a stable identifier associated with the Mac's hardware platform. Software can use it to distinguish this installation environment from another machine.",
            significance: "It can help correlate diagnostic records, management inventories, virtual-machine configuration, and repeated scans from the same Mac.",
            interpretation: "It is an identifier, not evidence of remote management, account ownership, or compromise. Its presence in system_profiler output is expected.",
            privacy: "This value can correlate reports from the same Mac over time. Redact it before publishing or sharing a report when persistent device identification is unnecessary."
        )

    case "provisioning_UDID":
        FieldExplanation(
            title: "Provisioning UDID",
            meaning: "This is a unique device identifier used by Apple development, provisioning, and some device-management workflows to address this specific Mac.",
            significance: "Developers or administrators may use it when associating the Mac with provisioning profiles, registered devices, or management records.",
            interpretation: "The identifier's presence is normal and does not prove that the Mac is enrolled, remotely controlled, or actively associated with a developer account.",
            privacy: "This is a persistent unique device identifier. It should be redacted from public screenshots, bug reports, and repositories."
        )

    case "serial_number":
        FieldExplanation(
            title: "Serial Number",
            meaning: "This is Apple's unique manufacturing and service identifier for this physical Mac.",
            significance: "Apple and authorized service providers use it for warranty, repair, support, and exact device identification.",
            interpretation: "A valid serial number does not establish ownership, warranty status, or authenticity on its own. Those conclusions require verification through an authoritative service.",
            privacy: "This uniquely identifies the Mac. Redact it from public reports, screenshots, support posts, and source repositories unless the recipient specifically requires it."
        )

    default:
        nil
    }
}
private func activationLockExplanation(reportedValue: String) -> FieldExplanation {
    let normalizedValue: String = reportedValue.lowercased()
    let significance: String

    if normalizedValue.contains("disabled") {
        significance = "The collected value indicates that Activation Lock was not enabled at scan time. This reduces theft-deterrence protection if the Mac is lost, although it may be intentional for resale, repair, enterprise deployment, or a device that does not use Find My."
    } else if normalizedValue.contains("enabled") {
        significance = "The collected value indicates that Activation Lock was enabled at scan time, which can require the associated Apple Account before the Mac is erased and reactivated."
    } else {
        significance = "The reported state should be reviewed in the context of Find My, Apple Account, and device-management configuration because system_profiler did not express a simple enabled or disabled state."
    }

    return FieldExplanation(
        title: "Activation Lock",
        meaning: "Activation Lock is Apple's theft-deterrence control that can bind supported hardware to an Apple Account through Find My.",
        significance: significance,
        interpretation: "This is a point-in-time local report. It does not identify the associated account, prove ownership, or establish whether other startup and disk protections are enabled.",
        privacy: nil
    )
}
