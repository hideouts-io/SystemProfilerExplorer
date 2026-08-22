import Testing
@testable import SystemProfilerExplorer

struct SoftwareExplanationTests {
    @Test
    func observedSoftwareOverviewFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .software,
            paths: [
                ["boot_mode"],
                ["boot_volume"],
                ["kernel_version"],
                ["local_host_name"],
                ["os_version"],
                ["secure_vm"],
                ["system_integrity"],
                ["uptime"],
                ["user_name"]
            ]
        )
    }

    @Test
    func observedApplicationAndFrameworkFieldsHaveCuratedExplanations() {
        let paths: [[String]] = [
            ["arch_kind"],
            ["info"],
            ["lastModified"],
            ["obtained_from"],
            ["path"],
            ["signed_by", "[]"],
            ["version"]
        ]

        expectSoftwareExplanations(dataType: .applications, paths: paths)
        expectSoftwareExplanations(dataType: .frameworks, paths: paths + [["private_framework"]])
    }

    @Test
    func observedDeveloperToolFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .developerTools,
            paths: [
                ["spdevtools_apps", "spinstruments_app"],
                ["spdevtools_apps", "spxcode_app"],
                ["spdevtools_path"],
                ["spdevtools_sdks", "macOS", "26.2"],
                ["spdevtools_version"]
            ]
        )
    }

    @Test
    func observedExtensionFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .extensions,
            paths: [
                ["spext_architectures", "[]"],
                ["spext_bundleid"],
                ["spext_description"],
                ["spext_has64BitIntelCode"],
                ["spext_hasAllDependencies"],
                ["spext_info"],
                ["spext_lastModified"],
                ["spext_load_address"],
                ["spext_loadable"],
                ["spext_loaded"],
                ["spext_path"],
                ["spext_signed_by"],
                ["spext_version"],
                ["version"]
            ]
        )
    }

    @Test
    func observedFontFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .fonts,
            paths: [
                ["enabled"],
                ["path"],
                ["type"],
                ["valid"],
                ["typefaces", "[]", "copy_protected"],
                ["typefaces", "[]", "copyright"],
                ["typefaces", "[]", "description"],
                ["typefaces", "[]", "designer"],
                ["typefaces", "[]", "duplicate"],
                ["typefaces", "[]", "embeddable"],
                ["typefaces", "[]", "enabled"],
                ["typefaces", "[]", "family"],
                ["typefaces", "[]", "fullname"],
                ["typefaces", "[]", "outline"],
                ["typefaces", "[]", "style"],
                ["typefaces", "[]", "trademark"],
                ["typefaces", "[]", "unique"],
                ["typefaces", "[]", "valid"],
                ["typefaces", "[]", "vendor"],
                ["typefaces", "[]", "version"]
            ]
        )
    }

    @Test
    func observedInstallAndInternationalFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .installHistory,
            paths: [["install_date"], ["install_version"], ["package_source"]]
        )
        expectSoftwareExplanations(
            dataType: .international,
            paths: [
                ["linguistic_data_assets_requested", "[]"],
                ["system_country"],
                ["system_interface_languages", "[]"],
                ["system_languages", "[]"],
                ["system_locale"],
                ["system_text_direction"],
                ["system_uses_metric_system"],
                ["user_assistant_language"],
                ["user_assistant_voice_language"],
                ["user_calendar"],
                ["user_country_code"],
                ["user_current_input_source"],
                ["user_language_code"],
                ["user_locale"],
                ["user_preferred_interface_languages", "[]"],
                ["user_uses_metric_system"]
            ]
        )
    }

    @Test
    func observedLegacyFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .legacySoftware,
            paths: [
                ["has_native_version"],
                ["number_of_times_launched"],
                ["previously_launched_date"],
                ["process_names", "[]"],
                ["reason"],
                ["reason_source"],
                ["process_info", "process_bundle_id"],
                ["process_info", "process_bundle_version"],
                ["process_info", "process_developer_name"],
                ["process_info", "process_name"],
                ["process_info", "process_path"],
                ["process_info", "process_team_id"],
                ["responsible_info", "responsible_bundle_id"],
                ["responsible_info", "responsible_bundle_version"],
                ["responsible_info", "responsible_developer_name"],
                ["responsible_info", "responsible_name"],
                ["responsible_info", "responsible_path"],
                ["responsible_info", "responsible_team_id"]
            ]
        )
    }

    @Test
    func observedPrinterAndSyncFieldsHaveCuratedExplanations() {
        expectSoftwareExplanations(
            dataType: .printerSoftware,
            paths: [
                ["image capture support", "[]", "info path"],
                ["image capture support", "[]", "info version"]
            ]
        )
        expectSoftwareExplanations(
            dataType: .syncServices,
            paths: [
                ["contents"],
                ["description"],
                ["lastModified"],
                ["size"],
                ["summary_of_sync_log"],
                ["summary_os_version"]
            ]
        )
    }

    @Test
    func sensitiveSoftwareFieldsIncludePrivacyGuidance() throws {
        let user = try #require(
            explanation(for: .software, path: ["user_name"], reportedValue: "REDACTED")
        )
        let path = try #require(
            explanation(for: .applications, path: ["path"], reportedValue: "REDACTED")
        )
        let locale = try #require(
            explanation(for: .international, path: ["user_locale"], reportedValue: "REDACTED")
        )
        let launch = try #require(
            explanation(for: .legacySoftware, path: ["previously_launched_date"], reportedValue: "REDACTED")
        )

        #expect(user.privacy != nil)
        #expect(path.privacy != nil)
        #expect(locale.privacy != nil)
        #expect(launch.privacy != nil)
    }
}

private func expectSoftwareExplanations(
    dataType: SystemProfilerDataType,
    paths: [[String]]
) {
    for path in paths {
        #expect(explanation(for: dataType, path: path, reportedValue: "yes") != nil)
    }
}
