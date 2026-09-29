import Foundation
import Testing
@testable import SystemProfilerExplorer

/// Value rules for enumeration and on/off fields that docs/value-inventory.md lists
/// without a value explanation.
struct ThirdWaveValueTests {
    // MARK: - Startup security

    @Test
    func secureBootLevelsChangeTheStatus() {
        func status(_ value: String) -> ValueStatus? {
            valueExplanation(dataType: .iBridge, path: ["ibridge_secure_boot"], scalar: .string(value))?.status
        }

        #expect(status("Full Security") == .normal)
        #expect(status("Reduced Security") == .informational)
        #expect(status("Permissive Security") == .worthReviewing)
        #expect(status("Medium Security") == .informational)
        #expect(status("No Security") == .worthReviewing)
        #expect(status("Future Security") == .unknown)
    }

    @Test
    func loweredStartupProtectionsAreWorthALook() {
        func explanation(_ field: String, _ value: String) -> ValueExplanation? {
            valueExplanation(dataType: .iBridge, path: [field], scalar: .string(value))
        }

        #expect(explanation("ibridge_sb_sip", "Enabled")?.status == .normal)
        #expect(explanation("ibridge_sb_sip", "Disabled")?.status == .worthReviewing)
        #expect(explanation("ibridge_sb_sip", "Custom Configuration")?.summary.contains("partly") == true)
        #expect(explanation("ibridge_sb_ssv", "Disabled")?.status == .worthReviewing)
        #expect(explanation("ibridge_sb_ctrr", "Disabled")?.status == .worthReviewing)
        #expect(explanation("ibridge_sb_boot_args", "Disabled")?.status == .informational)
        #expect(explanation("ibridge_sb_other_kext", "Yes")?.status == .informational)
        #expect(explanation("ibridge_sb_other_kext", "No")?.status == .normal)
    }

    @Test
    func privilegedManagementIsMarkedAsAnInference() throws {
        let person = try #require(valueExplanation(dataType: .iBridge, path: ["ibridge_sb_manual_mdm"], scalar: .string("Yes")))
        let enrollment = try #require(valueExplanation(dataType: .iBridge, path: ["ibridge_sb_device_mdm"], scalar: .string("Yes")))

        #expect(person.confidence?.reasons.isEmpty == false)
        #expect(person.suggestedAction != nil)
        #expect(enrollment.summary.contains("Automated Device Enrollment"))
        #expect(valueExplanation(dataType: .iBridge, path: ["ibridge_sb_device_mdm"], scalar: .string("No"))?.status == .normal)
    }

    // MARK: - Coverage

    /// Values observed in the full scan behind docs/value-inventory.md for fields this
    /// wave covers. A value listed here must never fall back to "not yet explained".
    @Test
    func observedThirdWaveValuesAreAllExplained() {
        let observed: [(SystemProfilerDataType, [String], String)] = [
            (.iBridge, ["ibridge_secure_boot"], "Full Security"),
            (.iBridge, ["ibridge_sb_sip"], "Enabled"),
            (.iBridge, ["ibridge_sb_ssv"], "Enabled"),
            (.iBridge, ["ibridge_sb_ctrr"], "Enabled"),
            (.iBridge, ["ibridge_sb_boot_args"], "Enabled"),
            (.iBridge, ["ibridge_sb_other_kext"], "No"),
            (.iBridge, ["ibridge_sb_manual_mdm"], "No"),
            (.iBridge, ["ibridge_sb_device_mdm"], "No")
        ]

        for (dataType, path, value) in observed {
            let explanation: ValueExplanation? = valueExplanation(dataType: dataType, path: path, scalar: .string(value))
            #expect(explanation != nil, "\(dataType.rawValue).\(path.joined(separator: ".")) = \(value) has no explanation")
            #expect(explanation?.status != .unknown, "\(dataType.rawValue).\(path.joined(separator: ".")) = \(value) is not yet explained")
        }
    }
}
