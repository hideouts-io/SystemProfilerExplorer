import Testing
@testable import SystemProfilerExplorer

struct SecurityExplanationTests {
    @Test
    func observedFirewallFieldsHaveCuratedExplanations() {
        expectSecurityExplanations(
            dataType: .firewall,
            paths: [
                ["spfirewall_globalstate"],
                ["spfirewall_loggingenabled"],
                ["spfirewall_stealthenabled"],
                ["spfirewall_applications", "com.example.application"]
            ]
        )
    }

    @Test
    func observedConfigurationProfileFieldsHaveCuratedExplanations() {
        expectSecurityExplanations(
            dataType: .configurationProfiles,
            paths: [
                ["spconfigprofile_RemovalDisallowed"],
                ["spconfigprofile_description"],
                ["spconfigprofile_install_date"],
                ["spconfigprofile_install_source"],
                ["spconfigprofile_profile_identifier"],
                ["spconfigprofile_profile_uuid"],
                ["spconfigprofile_verification_state"],
                ["spconfigprofile_version"],
                ["_items", "[]", "spconfigprofile_payload_data"],
                ["_items", "[]", "spconfigprofile_payload_display_name"],
                ["_items", "[]", "spconfigprofile_payload_identifier"],
                ["_items", "[]", "spconfigprofile_payload_uuid"],
                ["_items", "[]", "spconfigprofile_payload_version"]
            ]
        )
    }

    @Test
    func observedManagedClientFieldsHaveCuratedExplanations() {
        expectSecurityExplanations(
            dataType: .managedClient,
            paths: [["data_keyValue"], ["data_source"], ["data_state"]]
        )
    }

    @Test
    func observedSecureElementFieldsHaveCuratedExplanations() {
        expectSecurityExplanations(
            dataType: .secureElement,
            paths: [
                ["ctl_fw"],
                ["ctl_hw"],
                ["ctl_info"],
                ["ctl_mw"],
                ["se_device"],
                ["se_fw"],
                ["se_hw"],
                ["se_id"],
                ["se_in_restricted_mode"],
                ["se_info"],
                ["se_os_id"],
                ["se_os_version"],
                ["se_plt"],
                ["se_prod_signed"]
            ]
        )
    }

    @Test
    func observedSmartCardAndAccessibilityFieldsHaveCuratedExplanations() {
        expectSecurityExplanations(
            dataType: .smartCards,
            paths: [["#01"], ["#02"]]
        )
        expectSecurityExplanations(
            dataType: .universalAccess,
            paths: [
                ["contrast"],
                ["cursor_mag"],
                ["display"],
                ["flash_screen"],
                ["keyboardZoom"],
                ["mouse_keys"],
                ["scrollZoom"],
                ["slow_keys"],
                ["sticky_keys"],
                ["voiceover"],
                ["zoomMode"]
            ]
        )
    }

    @Test
    func sensitiveSecurityFieldsIncludePrivacyGuidance() throws {
        let firewallRule = try #require(
            explanation(
                for: .firewall,
                path: ["spfirewall_applications", "com.example.application"],
                reportedValue: "Allow"
            )
        )
        let payload = try #require(
            explanation(
                for: .configurationProfiles,
                path: ["spconfigprofile_payload_data"],
                reportedValue: "REDACTED"
            )
        )
        let secureElementID = try #require(
            explanation(for: .secureElement, path: ["se_id"], reportedValue: "REDACTED")
        )
        let accessibility = try #require(
            explanation(for: .universalAccess, path: ["voiceover"], reportedValue: "yes")
        )

        #expect(firewallRule.privacy != nil)
        #expect(payload.privacy != nil)
        #expect(secureElementID.privacy != nil)
        #expect(accessibility.privacy != nil)
    }
}

private func expectSecurityExplanations(
    dataType: SystemProfilerDataType,
    paths: [[String]]
) {
    for path in paths {
        #expect(explanation(for: dataType, path: path, reportedValue: "yes") != nil)
    }
}
