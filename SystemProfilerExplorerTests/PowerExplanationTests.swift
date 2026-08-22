import Testing
@testable import SystemProfilerExplorer

struct PowerExplanationTests {
    @Test
    func observedPowerFieldsHaveCuratedExplanations() {
        let fields: [([String], String)] = [
            (["sppower_battery_charge_info", "sppower_battery_at_warn_level"], "FALSE"),
            (["sppower_battery_charge_info", "sppower_battery_fully_charged"], "FALSE"),
            (["sppower_battery_charge_info", "sppower_battery_is_charging"], "FALSE"),
            (["sppower_battery_charge_info", "sppower_battery_state_of_charge"], "67"),
            (["sppower_battery_health_info", "sppower_battery_cycle_count"], "154"),
            (["sppower_battery_health_info", "sppower_battery_health"], "Good"),
            (["sppower_battery_health_info", "sppower_battery_health_maximum_capacity"], "97%"),
            (["sppower_battery_model_info", "sppower_battery_cell_revision"], "REDACTED"),
            (["sppower_battery_model_info", "sppower_battery_device_name"], "REDACTED"),
            (["sppower_battery_model_info", "sppower_battery_firmware_version"], "REDACTED"),
            (["sppower_battery_model_info", "sppower_battery_hardware_revision"], "REDACTED"),
            (["sppower_battery_model_info", "sppower_battery_pack_lot_code"], "REDACTED"),
            (["sppower_battery_model_info", "sppower_battery_pcb_lot_code"], "REDACTED"),
            (["sppower_battery_model_info", "sppower_battery_serial_number"], "REDACTED"),
            (["Battery Power", "Current Power Source"], "TRUE"),
            (["Battery Power", "Disk Sleep Timer"], "10"),
            (["Battery Power", "Display Sleep Timer"], "2"),
            (["Battery Power", "Hibernate Mode"], "3"),
            (["Battery Power", "HighPowerMode"], "No"),
            (["Battery Power", "LowPowerMode"], "No"),
            (["Battery Power", "PrioritizeNetworkReachabilityOverSleep"], "No"),
            (["Battery Power", "ReduceBrightness"], "Yes"),
            (["Battery Power", "Sleep On Power Button"], "Yes"),
            (["Battery Power", "System Sleep Timer"], "1"),
            (["Battery Power", "Wake On LAN"], "No"),
            (["sppower_ups_installed"], "No"),
            (["sppower_battery_charger_connected"], "Yes"),
            (["_items", "[]", "appPID"], "123"),
            (["_items", "[]", "eventtype"], "wake"),
            (["_items", "[]", "scheduledby"], "com.example.service"),
            (["_items", "[]", "UserVisible"], "true"),
            (["_items", "[]", "time"], "2026-08-22 08:00:00")
        ]

        for (path, value) in fields {
            #expect(explanation(for: .power, path: path, reportedValue: value) != nil)
        }
    }

    @Test
    func powerIdentifiersAndScheduleContextIncludePrivacyGuidance() throws {
        let batterySerial = try #require(
            explanation(
                for: .power,
                path: ["sppower_battery_model_info", "sppower_battery_serial_number"],
                reportedValue: "REDACTED"
            )
        )
        let scheduledBy = try #require(
            explanation(for: .power, path: ["_items", "[]", "scheduledby"], reportedValue: "service")
        )
        let scheduledTime = try #require(
            explanation(for: .power, path: ["_items", "[]", "time"], reportedValue: "REDACTED")
        )

        #expect(batterySerial.privacy != nil)
        #expect(scheduledBy.privacy != nil)
        #expect(scheduledTime.privacy != nil)
    }

    @Test
    func reportedBooleanStateIsIncludedInTheExplanation() throws {
        let enabled = try #require(
            explanation(for: .power, path: ["sppower_battery_is_charging"], reportedValue: "TRUE")
        )
        let disabled = try #require(
            explanation(for: .power, path: ["sppower_battery_is_charging"], reportedValue: "FALSE")
        )

        #expect(enabled.significance.contains("condition was active"))
        #expect(disabled.significance.contains("condition was not active"))
    }

    @Test
    func uppercaseProfilerBooleansArePresentedReadably() {
        let enabled = fieldPresentation(
            dataType: .power,
            path: ["sppower_battery_is_charging"],
            scalar: .string("TRUE")
        )
        let disabled = fieldPresentation(
            dataType: .power,
            path: ["sppower_battery_is_charging"],
            scalar: .string("FALSE")
        )

        #expect(enabled.displayedValue == "Yes")
        #expect(disabled.displayedValue == "No")
        #expect(enabled.rawValue == "TRUE")
        #expect(disabled.rawValue == "FALSE")
    }
}
