import Foundation

/// Readable names for record and group names that system_profiler reports as internal
/// tokens, such as `sppower_ac_charger_information`. Only known names are changed:
/// other names, including framework and app names that contain underscores, are real
/// names and stay exactly as reported.
private let knownRecordNames: [String: String] = [
    "hardware_overview": "Hardware Overview",
    "os_overview": "macOS",
    "spbattery_information": "Battery",
    "sppower_information": "Power Settings",
    "sppower_hwconfig_information": "Power Hardware",
    "sppower_ac_charger_information": "Power Adapter",
    "sppower_events_info": "Power Events",
    "sppower_scheduled_events_info": "Scheduled Power Events",
    "spfirewall_settings": "Firewall Settings",
    "spdevtools_info": "Developer Tools",
    "spconfigprofile_section_deviceconfigprofiles": "Device Profiles",
    "ua_info": "Accessibility Settings",
    "system_settings": "System Language and Region",
    "user_settings": "Your Language and Region",
    "recovery_os_settings": "Recovery Language and Region",
    "coreaudio_device": "Audio Devices",
    "log_tree_name": "Diagnostic Logs",
    "summary_tree_name": "Overview",
    "asl_messages_description": "System Log Messages (ASL)",
    "ioreg_output_description": "I/O Registry Output",
    "nvram_output_description": "NVRAM Output",
    "cups_access_log_description": "Printing (CUPS) Access Log",
    "fsck_hfs_log_description": "Disk Check (fsck_hfs) Log",
    "per_user_fsck_hfs_log_description": "Per-User Disk Check (fsck_hfs) Log",
    "wifi_log_description": "Wi-Fi Log"
]

func friendlyReportGroupName(_ name: String) -> String {
    if let known = knownRecordNames[name] {
        return known
    }

    // thunderboltusb4_bus_0 → Thunderbolt/USB4 Bus 0
    if let bus = tokenSuffix(name, after: "thunderboltusb4_bus_"), Int(bus) != nil {
        return "Thunderbolt/USB4 Bus \(bus)"
    }

    // kernel_log_description → Kernel Log
    if name.hasSuffix("_log_description"), isEnumeratedToken(name) {
        return displayName(for: String(name.dropLast("_log_description".count))) + " Log"
    }

    return name
}

/// The label shown and searched for a record or array item.
func recordDisplayLabel(_ value: ProfileValue, fallback: String) -> String {
    value.preferredName.map(friendlyReportGroupName) ?? fallback
}
