import Foundation

func installHistoryExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "install_date":
        return FieldExplanation(
            title: "Installation Date",
            meaning: "This is the date macOS installation history associates with the software package or update record.",
            significance: "It supports timeline analysis of operating-system updates, Apple packages, applications, and other installer activity.",
            interpretation: "An installation-history entry is not proof that every payload remains present, that installation succeeded completely, or that the package was first installed on this date.",
            privacy: nil
        )
    case "install_version":
        return FieldExplanation(
            title: "Installed Version",
            meaning: "This is the version recorded for the package or software item in installation history.",
            significance: "It helps correlate the event with vendor releases and distinguish upgrades from repeated installations.",
            interpretation: "The historical version does not necessarily match the currently installed file set. Later updates, removals, restoration, and manual changes require separate verification.",
            privacy: nil
        )
    case "package_source":
        return FieldExplanation(
            title: "Package Source",
            meaning: "This identifies the package or source label associated with the installation-history event.",
            significance: "It can distinguish Apple updates, App Store content, vendor packages, and other installer sources during timeline review.",
            interpretation: "The recorded source is not complete provenance and does not prove the package was trusted, notarized, or obtained directly from the named publisher.",
            privacy: "Package-source text can reveal internal products, management systems, mounted paths, or organization-specific deployment names. Review before sharing."
        )
    default:
        return nil
    }
}

func internationalExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)

    return switch field {
    case "linguistic_data_assets_requested":
        FieldExplanation(
            title: "Requested Linguistic Asset",
            meaning: "This identifies a language-related data asset macOS has requested for features such as input, speech, dictionaries, or linguistic processing.",
            significance: "Requested assets provide context for which language capabilities the system may prepare or download.",
            interpretation: "A request does not prove the asset downloaded successfully, was used, or identifies the user's native language.",
            privacy: "Language asset choices can reveal language preferences and regional context. Review them before publishing."
        )
    case "system_country", "user_country_code":
        FieldExplanation(
            title: field == "system_country" ? "System Country" : "User Country Code",
            meaning: "This is the country or region configured for system-wide or current-user localization behavior.",
            significance: "Region affects formatting, calendars, measurement conventions, storefronts, and some content availability.",
            interpretation: "The setting is user-configurable and is not reliable evidence of citizenship, residence, precise location, or physical presence.",
            privacy: "Country and region preferences can reveal approximate personal or organizational context. Review before sharing."
        )
    case "system_interface_languages", "user_preferred_interface_languages":
        FieldExplanation(
            title: field == "system_interface_languages" ? "System Interface Language" : "Preferred Interface Language",
            meaning: "This is a language in the ordered preferences macOS uses when selecting localized user-interface resources.",
            significance: "The order influences which language applications and system components display when matching translations are available.",
            interpretation: "A preference does not prove fluency, identity, or that every application displayed that language.",
            privacy: "Language preferences can reveal cultural or regional context. Review them before publishing."
        )
    case "system_languages":
        FieldExplanation(
            title: "System Language",
            meaning: "This is a language included in the system-level language configuration reported by macOS.",
            significance: "It provides localization context for system services and software that consult system language settings.",
            interpretation: "The entry does not prove active use, fluency, identity, or the language used for a specific document or session.",
            privacy: "Language configuration can reveal cultural or regional context. Review before sharing."
        )
    case "system_locale", "user_locale":
        FieldExplanation(
            title: field == "system_locale" ? "System Locale" : "User Locale",
            meaning: "This locale identifier combines language and regional conventions used for formatting and localization.",
            significance: "Locale influences dates, numbers, sorting, currency presentation, and application resource selection.",
            interpretation: "Locale is configuration, not proof of physical location, nationality, timezone, or language proficiency.",
            privacy: "Locale can reveal language and regional preferences. Review it before publishing."
        )
    case "system_text_direction":
        FieldExplanation(
            title: "System Text Direction",
            meaning: "This reports the primary writing direction selected for system text layout.",
            significance: "Text direction affects interface arrangement and rendering for left-to-right and right-to-left writing systems.",
            interpretation: "The direction is a localization setting and does not establish the language or content of a particular document.",
            privacy: nil
        )
    case "system_uses_metric_system", "user_uses_metric_system":
        softwareBooleanExplanation(
            title: field == "system_uses_metric_system" ? "System Uses Metric Units" : "User Uses Metric Units",
            meaning: "This reports whether metric measurement conventions are selected for the system or current user.",
            significance: "The setting affects how compatible applications present distance, temperature, and other measurements.",
            interpretation: "Measurement preference is configurable and is not reliable proof of a person's country or physical location.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "user_assistant_language", "user_assistant_voice_language":
        FieldExplanation(
            title: field == "user_assistant_language" ? "Assistant Language" : "Assistant Voice Language",
            meaning: "This is the language configured for the digital assistant's recognition or spoken voice.",
            significance: "It determines which language models and voice resources the assistant is expected to use.",
            interpretation: "The setting does not prove the assistant was enabled, invoked, recorded audio, or transmitted a request.",
            privacy: "Assistant language preferences can reveal linguistic and regional context. Review them before sharing."
        )
    case "user_calendar":
        FieldExplanation(
            title: "Calendar System",
            meaning: "This identifies the calendar convention selected for the current user.",
            significance: "The calendar affects how compatible applications calculate and display dates, eras, and recurring events.",
            interpretation: "The preference does not expose calendar events and does not prove religious, cultural, or regional identity.",
            privacy: "A non-default calendar choice can reveal cultural or religious context. Review it before publishing."
        )
    case "user_current_input_source":
        FieldExplanation(
            title: "Current Input Source",
            meaning: "This identifies the keyboard layout or input method selected for the current user when the report was collected.",
            significance: "Input sources determine how keystrokes are converted into characters and can include language-specific or specialized input methods.",
            interpretation: "The current source is point-in-time configuration and does not reveal typed content, prove language proficiency, or identify the physical keyboard.",
            privacy: "Input-source choice can reveal linguistic context. Review it before sharing."
        )
    case "user_language_code":
        FieldExplanation(
            title: "User Language Code",
            meaning: "This is the primary language code associated with the current user's localization settings.",
            significance: "Applications can use it when selecting localized resources and language-aware behavior.",
            interpretation: "The code is a preference, not proof of identity, nationality, fluency, or the language used for particular content.",
            privacy: "Language settings can reveal personal or regional context. Review them before publishing."
        )
    default:
        nil
    }
}

func printerSoftwareExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "info path":
        return FieldExplanation(
            title: "Printer Support Path",
            meaning: "This is the filesystem location of a printer or image-capture software support component.",
            significance: "The path helps identify installed vendor support files and provides a target for version, signature, and provenance checks.",
            interpretation: "File presence does not prove that a printer is connected, that the component ran, or that it is currently selected by a print queue.",
            privacy: "Paths can expose account names, mounted volumes, vendors, or internal deployment structure. Review before sharing."
        )
    case "info version":
        return FieldExplanation(
            title: "Printer Support Version",
            meaning: "This is the reported version of the printer or image-capture support component.",
            significance: "It helps correlate the installed support software with vendor releases and compatibility information.",
            interpretation: "The version does not prove current use, device presence, signature validity, or that every related file has the same build.",
            privacy: nil
        )
    default:
        return nil
    }
}
