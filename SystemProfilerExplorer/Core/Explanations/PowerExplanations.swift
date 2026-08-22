import Foundation

func powerExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    guard let field: String = path.last else {
        return nil
    }

    return switch field {
    case "sppower_battery_state_of_charge":
        FieldExplanation(
            title: "Battery Charge",
            meaning: "This is the battery's estimated state of charge as a percentage of its currently usable full-charge capacity.",
            significance: "It shows how much portable runtime remains relative to the battery's present capacity and is the value normally reflected by the menu-bar battery indicator.",
            interpretation: "Charge percentage is an estimate that can move as workload, temperature, calibration, and battery age change. It is not the same as battery health or original design capacity.",
            privacy: nil
        )

    case "sppower_battery_fully_charged":
        booleanPowerExplanation(
            title: "Fully Charged",
            meaning: "This reports whether the battery-management system currently considers the battery fully charged.",
            significance: "It helps distinguish a battery that has completed charging from one that is still accepting power or being intentionally held below 100 percent by battery-health management.",
            interpretation: "A false value is normal whenever charge is below the managed target. Optimized charging can deliberately pause charging, so this is not a charger or battery fault by itself.",
            reportedValue: reportedValue
        )

    case "sppower_battery_is_charging":
        booleanPowerExplanation(
            title: "Battery Charging",
            meaning: "This reports whether electrical energy is actively being added to the battery at scan time.",
            significance: "It distinguishes an attached power adapter from active charging and helps diagnose cases where external power is present but battery charge is not increasing.",
            interpretation: "Charging can pause because the battery is full, temperature is outside the preferred range, optimized charging is active, or the current workload consumes the available adapter power. A single false reading is not proof of a fault.",
            reportedValue: reportedValue
        )

    case "sppower_battery_at_warn_level":
        booleanPowerExplanation(
            title: "Low-Battery Warning",
            meaning: "This reports whether macOS considers the remaining battery charge low enough to be in its warning range.",
            significance: "The warning state signals that portable runtime is limited and that unsaved work may be at risk if external power is not connected.",
            interpretation: "The threshold and remaining runtime are estimates. A false value only means the warning threshold was not active at collection time; it does not describe battery health.",
            reportedValue: reportedValue
        )

    case "sppower_battery_cycle_count":
        FieldExplanation(
            title: "Battery Cycle Count",
            meaning: "A charge cycle represents cumulative use equal to 100 percent of battery capacity, even when that use occurs across several partial discharges and recharges.",
            significance: "Cycle count is one indicator of accumulated battery use and is useful when evaluating age, warranty questions, or an unexpected reduction in runtime.",
            interpretation: "Cycle count is not a health verdict. Battery condition also depends on age, temperature history, chemistry, maximum capacity, and internal diagnostics; compare limits only with Apple's guidance for the exact model.",
            privacy: nil
        )

    case "sppower_battery_health":
        batteryHealthExplanation(reportedValue: reportedValue)

    case "sppower_battery_health_maximum_capacity":
        FieldExplanation(
            title: "Maximum Battery Capacity",
            meaning: "This estimates the battery's present full-charge capacity as a percentage of the capacity it had when new.",
            significance: "A lower percentage generally means less unplugged runtime under comparable workloads and provides useful context alongside cycle count and the reported health condition.",
            interpretation: "The estimate can change as battery management recalibrates. It should not be interpreted as the current charge level, a precise remaining lifetime, or proof that replacement is required without model-specific service guidance.",
            privacy: nil
        )

    case "sppower_battery_serial_number":
        FieldExplanation(
            title: "Battery Serial Number",
            meaning: "This is the identifier reported by the installed battery pack or its management electronics.",
            significance: "It can help service personnel distinguish a particular battery assembly and correlate replacement or diagnostic history.",
            interpretation: "The value does not establish battery authenticity, warranty status, health, or whether the battery is original to the Mac.",
            privacy: "This identifier can distinguish the installed battery pack. Redact it from public screenshots, reports, and repositories unless a trusted service recipient specifically requires it."
        )

    case "sppower_battery_device_name":
        batteryMetadataExplanation(
            title: "Battery Controller",
            meaning: "This is the device name reported by the battery-management controller.",
            significance: "It identifies the controller family used to monitor cells, charging, temperature, and safety limits.",
            interpretation: "A controller name is implementation metadata, not a consumer battery model or health result."
        )

    case "sppower_battery_firmware_version":
        batteryMetadataExplanation(
            title: "Battery Firmware Version",
            meaning: "This is the firmware revision reported by the battery-management electronics.",
            significance: "The revision can help correlate controller behavior during model-specific service or engineering diagnostics.",
            interpretation: "The value alone does not establish that firmware is current, vulnerable, or modified; an authoritative comparison requires the exact Mac and battery assembly."
        )

    case "sppower_battery_hardware_revision":
        batteryMetadataExplanation(
            title: "Battery Hardware Revision",
            meaning: "This is the hardware revision exposed by the battery-management assembly.",
            significance: "It can distinguish engineering revisions that may behave differently during diagnostics or service.",
            interpretation: "It is not a battery-health measurement and may use a vendor-specific encoding."
        )

    case "sppower_battery_cell_revision":
        batteryMetadataExplanation(
            title: "Battery Cell Revision",
            meaning: "This is revision metadata associated with the battery cells or cell configuration.",
            significance: "It can provide manufacturing context when service documentation distinguishes cell revisions.",
            interpretation: "The code is vendor-specific and does not reveal present capacity, safety, or cell balance on its own."
        )

    case "sppower_battery_pack_lot_code":
        batteryMetadataExplanation(
            title: "Battery Pack Lot Code",
            meaning: "This is manufacturing-lot metadata reported for the battery pack.",
            significance: "Lot information can assist a manufacturer or service provider when correlating production batches.",
            interpretation: "A blank, zero, or unfamiliar code is not evidence of tampering or failure; vendors may not populate this field consistently."
        )

    case "sppower_battery_pcb_lot_code":
        batteryMetadataExplanation(
            title: "Battery Controller Board Lot Code",
            meaning: "This is manufacturing-lot metadata for the battery pack's printed circuit board or controller assembly.",
            significance: "It can help correlate a controller board with a production batch during specialized service analysis.",
            interpretation: "The encoding is vendor-specific and is not a health, ownership, or authenticity result."
        )

    case "Current Power Source":
        booleanPowerExplanation(
            title: "Current Power Source",
            meaning: "Within a power-settings group, this marks the source that macOS was using when the scan ran.",
            significance: "It identifies which group of energy settings applied at collection time and helps explain differences between battery and adapter behavior.",
            interpretation: "This point-in-time value can change immediately when power is connected or removed and does not indicate whether the battery is actively charging.",
            reportedValue: reportedValue
        )

    case "System Sleep Timer":
        timerExplanation(
            title: "System Sleep Timer",
            meaning: "This is the configured idle interval before macOS may put the computer into system sleep for this power source.",
            significance: "The setting affects energy use, background availability, and how quickly the Mac becomes inactive when unattended.",
            interpretation: "The configured timer does not prove that sleep occurred. Applications, assertions, media playback, sharing services, and hardware can delay or prevent sleep."
        )

    case "Display Sleep Timer":
        timerExplanation(
            title: "Display Sleep Timer",
            meaning: "This is the configured idle interval before macOS may turn off the display for this power source.",
            significance: "Display sleep reduces energy use and can materially extend battery runtime while allowing the rest of the system to remain awake.",
            interpretation: "The value is a policy setting, not a history of display activity. Active applications and power assertions can affect actual behavior."
        )

    case "Disk Sleep Timer":
        timerExplanation(
            title: "Disk Sleep Timer",
            meaning: "This is the configured idle interval associated with putting eligible storage devices into a lower-power state.",
            significance: "It historically reduced power use for rotating disks and may still describe a policy even when the Mac uses solid-state storage.",
            interpretation: "On SSD-only systems this setting may have little visible effect. It does not show whether any device actually entered a low-power state."
        )

    case "Hibernate Mode":
        FieldExplanation(
            title: "Hibernate Mode",
            meaning: "This numeric policy controls how macOS preserves memory contents and transitions between ordinary sleep and deeper standby behavior.",
            significance: "It affects wake behavior, power consumption, and whether memory state is also written to persistent storage for recovery.",
            interpretation: "The numeric value is implementation-oriented and must be interpreted with the Mac model and related power-management settings. It should not be changed solely because another Mac reports a different value.",
            privacy: nil
        )

    case "HighPowerMode":
        powerModeExplanation(
            title: "High Power Mode",
            meaning: "This reports whether the power profile allows supported Macs to favor sustained performance for demanding workloads.",
            significance: "When supported and enabled, the mode can permit more aggressive thermal and fan behavior to sustain performance.",
            interpretation: "Availability is model-dependent, and the setting does not mean the Mac is currently under load or operating at maximum performance."
        )

    case "LowPowerMode":
        powerModeExplanation(
            title: "Low Power Mode",
            meaning: "This reports whether macOS is configured to reduce energy use for this power source.",
            significance: "Low Power Mode can extend battery runtime by reducing selected background activity and performance behavior.",
            interpretation: "The setting is not a direct measurement of consumption, and its exact effects can vary with macOS version, hardware, and workload."
        )

    case "Wake On LAN":
        powerModeExplanation(
            title: "Wake for Network Access",
            meaning: "This controls whether supported network activity may wake the Mac or make services available while it is sleeping.",
            significance: "It affects remote file sharing, backups, management, and other services that may need the Mac to become reachable during sleep.",
            interpretation: "An enabled setting is authorization for supported wake behavior, not evidence that a remote wake occurred or that remote access succeeded."
        )

    case "PrioritizeNetworkReachabilityOverSleep":
        powerModeExplanation(
            title: "Prioritize Network Reachability",
            meaning: "This policy tells macOS whether maintaining network reachability should take priority over entering or remaining in sleep.",
            significance: "It can affect availability for network services and energy consumption when the Mac would otherwise sleep.",
            interpretation: "The setting does not identify a requesting application or prove ongoing network traffic; current assertions and network state require separate inspection."
        )

    case "Sleep On Power Button":
        powerModeExplanation(
            title: "Power Button Sleep",
            meaning: "This controls whether pressing the physical power button requests sleep rather than another power action.",
            significance: "It describes the expected user-interface behavior of the power button under the active power profile.",
            interpretation: "It does not record that the button was pressed or that a sleep transition completed."
        )

    case "ReduceBrightness":
        powerModeExplanation(
            title: "Reduce Brightness on Battery",
            meaning: "This controls whether macOS may reduce display brightness when the Mac is running from battery power.",
            significance: "The display is a significant power consumer, so reduced brightness can extend portable runtime.",
            interpretation: "The setting does not reveal the current brightness level and may be overridden by the user or other display policies."
        )

    case "sppower_ups_installed":
        booleanPowerExplanation(
            title: "UPS Installed",
            meaning: "This reports whether macOS detected a supported uninterruptible power supply configuration.",
            significance: "A UPS can keep a desktop Mac running briefly during an outage and may support automated shutdown before reserve power is exhausted.",
            interpretation: "A false value does not prove that no external battery system is physically present; unsupported or unmanaged equipment may not appear here.",
            reportedValue: reportedValue
        )

    case "sppower_battery_charger_connected":
        booleanPowerExplanation(
            title: "Power Adapter Connected",
            meaning: "This reports whether the power-management system detected an external charger or power adapter at scan time.",
            significance: "It distinguishes physical power presence from battery-only operation and provides context for charging behavior.",
            interpretation: "A connected adapter does not guarantee that it supplies enough power or that the battery is charging. Cable, port, adapter capability, temperature, and battery-management policy still matter.",
            reportedValue: reportedValue
        )

    case "appPID":
        FieldExplanation(
            title: "Scheduling Process ID",
            meaning: "This is the process identifier recorded for an application or service associated with a scheduled power event.",
            significance: "It can help correlate the event with a process that was active when the schedule was registered.",
            interpretation: "Process IDs are temporary and reused. A PID alone does not reliably identify the current process or prove that the scheduled event executed.",
            privacy: nil
        )

    case "eventtype":
        FieldExplanation(
            title: "Scheduled Event Type",
            meaning: "This describes the requested power-management action, such as wake, sleep, restart, or shutdown.",
            significance: "It shows what kind of future power transition was scheduled when the report was collected.",
            interpretation: "A scheduled request is not proof that the action occurred. The event can be changed, cancelled, missed, or prevented after collection.",
            privacy: nil
        )

    case "scheduledby":
        FieldExplanation(
            title: "Scheduled By",
            meaning: "This identifies the application, service, or subsystem recorded as the source of a scheduled power event.",
            significance: "It provides attribution context when investigating why the Mac is expected to wake or perform another power action.",
            interpretation: "The label reflects scheduling metadata and does not prove malicious intent, current execution, or that the named component ultimately caused a power transition.",
            privacy: "Application or service names can disclose installed software and usage context. Review this field before sharing a report publicly."
        )

    case "UserVisible":
        booleanPowerExplanation(
            title: "User-Visible Event",
            meaning: "This is scheduling metadata that reports whether macOS marked the power event as suitable for presentation in a user-facing interface.",
            significance: "It helps distinguish an event intended to be visible to a person from scheduling used only for internal service coordination.",
            interpretation: "A user-visible value does not prove that the user created, approved, or actually saw the event. It is an event attribute reported by the scheduling system, not an interaction history.",
            reportedValue: reportedValue
        )

    case "time":
        FieldExplanation(
            title: "Scheduled Event Time",
            meaning: "This is the date and time recorded for a scheduled power-management event.",
            significance: "It establishes when macOS expected to attempt the associated wake, sleep, restart, or shutdown action.",
            interpretation: "The timestamp describes a schedule, not an execution record. Time-zone conversion and later schedule changes must be considered when correlating it with logs.",
            privacy: "A scheduled timestamp can reveal aspects of the user's routine or planned computer activity. Review it before public sharing."
        )

    default:
        nil
    }
}

private func booleanPowerExplanation(
    title: String,
    meaning: String,
    significance: String,
    interpretation: String,
    reportedValue: String
) -> FieldExplanation {
    let observedState: String = normalizedPowerBoolean(reportedValue) ?? "an unrecognized state"

    return FieldExplanation(
        title: title,
        meaning: meaning,
        significance: "The collected value indicates \(observedState). \(significance)",
        interpretation: interpretation,
        privacy: nil
    )
}

private func batteryHealthExplanation(reportedValue: String) -> FieldExplanation {
    let significance: String

    if reportedValue.localizedCaseInsensitiveCompare("Good") == .orderedSame {
        significance = "The battery-management system reported a normal condition at scan time and was not requesting service through this summary field."
    } else {
        significance = "The reported condition was not `Good`. Preserve current backups and compare the exact wording with Apple's model-specific battery-service guidance."
    }

    return FieldExplanation(
        title: "Battery Condition",
        meaning: "This is the battery-management system's summarized assessment of the installed battery's condition.",
        significance: significance,
        interpretation: "A normal condition does not guarantee original capacity or future reliability. A service condition should be correlated with maximum capacity, cycle count, symptoms, and Apple Diagnostics.",
        privacy: nil
    )
}

private func batteryMetadataExplanation(
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

private func timerExplanation(
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

private func powerModeExplanation(
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

private func normalizedPowerBoolean(_ reportedValue: String) -> String? {
    return switch reportedValue.lowercased() {
    case "true", "yes", "1": "the condition was active"
    case "false", "no", "0": "the condition was not active"
    default: nil
    }
}
