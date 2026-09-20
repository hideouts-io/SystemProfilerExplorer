import Foundation

func legacySoftwareExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    let field: String = softwareField(path)
    let responsible: Bool = path.contains("responsible_info")

    switch field {
    case "has_native_version":
        return softwareBooleanExplanation(
            title: "Native Version Available",
            meaning: "This reports whether macOS knows of a native alternative for the legacy or translated software item.",
            significance: "A native version can reduce reliance on compatibility layers and may improve support, performance, and future macOS compatibility.",
            interpretation: "Availability does not prove that the native version is installed, equivalent, trusted, or suitable for the user's workflow.",
            reportedValue: reportedValue,
            privacy: nil
        )
    case "number_of_times_launched":
        return FieldExplanation(
            title: "Recorded Launch Count",
            meaning: "This is the number of launches recorded by the subsystem that produced the legacy-software entry.",
            significance: "It can distinguish a one-time compatibility event from repeatedly observed use within the retained data.",
            interpretation: "The count is not a complete execution history. Retention, resets, aliases, process grouping, restoration, and collection scope can make it lower or different from actual launches.",
            privacy: "Launch counts reveal software-use patterns. Share them only when needed for the analysis."
        )
    case "previously_launched_date":
        return FieldExplanation(
            title: "Previously Launched",
            meaning: "This is a recorded date associated with a prior launch of the legacy or translated software item.",
            significance: "It provides timeline evidence that is stronger than file presence alone.",
            interpretation: "The timestamp may not be the first or most recent execution and does not prove user interaction, duration, or successful completion. Confirm retention and correlate logs.",
            privacy: "Software-use timestamps can reveal personal activity patterns. Review them before sharing."
        )
    case "process_names":
        return FieldExplanation(
            title: "Related Process Name",
            meaning: "This is a process name associated with the recorded legacy-software event.",
            significance: "It helps correlate a grouped record with executable names that may appear in logs, crash reports, or process histories.",
            interpretation: "A name is not a unique executable identity and can be reused or changed. Verify paths, code signatures, and timestamps before attribution.",
            privacy: "Process names can expose private applications, projects, or organizational tools. Review them before publishing."
        )
    case "reason":
        return FieldExplanation(
            title: "Legacy Classification Reason",
            meaning: "This explains why macOS classified the software or launch as legacy, translated, or otherwise noteworthy.",
            significance: "The reason identifies the compatibility characteristic that triggered collection, such as an architecture or unsupported technology.",
            interpretation: "Classification is not a malware, failure, or policy verdict and can change with macOS and hardware support.",
            privacy: nil
        )
    case "reason_source":
        return FieldExplanation(
            title: "Classification Source",
            meaning: "This identifies the subsystem or evidence source that supplied the legacy-software classification reason.",
            significance: "Source context helps determine how much weight to give the classification and where to seek corroborating records.",
            interpretation: "The source label does not by itself establish a complete execution history or explain every compatibility condition.",
            privacy: nil
        )
    case "process_bundle_id", "responsible_bundle_id":
        return legacyIdentityExplanation(
            title: responsible ? "Responsible Bundle Identifier" : "Process Bundle Identifier",
            kind: "bundle identifier",
            responsible: responsible
        )
    case "process_bundle_version", "responsible_bundle_version":
        return legacyIdentityExplanation(
            title: responsible ? "Responsible Bundle Version" : "Process Bundle Version",
            kind: "bundle version",
            responsible: responsible
        )
    case "process_developer_name", "responsible_developer_name":
        return legacyIdentityExplanation(
            title: responsible ? "Responsible Developer" : "Process Developer",
            kind: "developer name",
            responsible: responsible
        )
    case "process_name", "responsible_name":
        return legacyIdentityExplanation(
            title: responsible ? "Responsible Software" : "Process Name",
            kind: "software name",
            responsible: responsible
        )
    case "process_path", "responsible_path":
        return FieldExplanation(
            title: responsible ? "Responsible Software Path" : "Process Path",
            meaning: responsible
                ? "This is the filesystem path of software macOS associated as responsible for initiating or hosting the recorded process."
                : "This is the filesystem path of the executable associated with the recorded legacy-software event.",
            significance: "The path provides a concrete target for read-only signature, provenance, file metadata, and package-receipt checks.",
            interpretation: "A recorded path does not prove the file still exists, remains unchanged, or was directly launched by a person. Responsible-process attribution can reflect launch or hosting relationships.",
            privacy: "Paths can expose account names, projects, mounted volumes, internal applications, and organization structure. Redact them from public reports."
        )
    case "process_team_id", "responsible_team_id":
        return FieldExplanation(
            title: responsible ? "Responsible Team Identifier" : "Process Team Identifier",
            meaning: "This is the Apple code-signing team identifier associated with the \(responsible ? "responsible software" : "recorded process").",
            significance: "It can correlate separately named binaries to the same Developer ID team and supports provenance analysis.",
            interpretation: "A team identifier is not proof that the binary is benign, currently signed correctly, notarized, or unchanged. Verify the actual signature and requirement.",
            privacy: "Team identifiers are commonly public for distributed software, but internal development teams can reveal an organization. Review before sharing."
        )
    default:
        return nil
    }
}

func syncServicesExplanation(path: [String], reportedValue: String) -> FieldExplanation? {
    switch softwareField(path) {
    case "contents":
        return FieldExplanation(
            title: "Diagnostic Log Contents",
            meaning: "This is diagnostic text included in the report's Sync Services section. A system.log entry can contain messages from many applications, not just synchronization activity.",
            significance: "Use the timestamp and process name on each line to understand which application reported an event. Repeated lines can describe steps in a single operation rather than separate problems.",
            interpretation: "The report section is not proof that synchronization or transmission occurred. A log is a retained excerpt, not a complete record of activity or a safety assessment.",
            privacy: "Logs can reveal account names, paths, attachment names, and application activity. Review the original text before sharing."
        )
    case "description":
        return FieldExplanation(
            title: "Sync Record Description",
            meaning: "This is descriptive text associated with the Sync Services record.",
            significance: "It provides human-readable context for legacy synchronization diagnostics.",
            interpretation: "The text is not a complete event log and does not prove success, network transmission, or current account state.",
            privacy: "Descriptions can contain account, device, application, or data-source identifiers. Review before sharing."
        )
    case "lastModified":
        return FieldExplanation(
            title: "Sync Record Last Modified",
            meaning: "This is the modification timestamp associated with the retained synchronization record.",
            significance: "It can anchor the record in a broader timeline of application, account, and system activity.",
            interpretation: "Modification time is not necessarily sync start, completion, upload, or download time and can be affected by migration or restoration.",
            privacy: "Synchronization timestamps can reveal user activity patterns. Review before publishing."
        )
    case "size":
        return FieldExplanation(
            title: "Sync Record Size",
            meaning: "This is the reported storage size associated with the synchronization record or log item.",
            significance: "Size can help distinguish an empty marker from a larger retained diagnostic artifact.",
            interpretation: "The value is not a network byte count and does not show how much data was uploaded, downloaded, or successfully synchronized.",
            privacy: nil
        )
    case "summary_of_sync_log":
        return FieldExplanation(
            title: "Sync Log Summary",
            meaning: "This is a summarized view of retained legacy Sync Services diagnostic activity.",
            significance: "It can expose errors, participating clients, or synchronization state useful for historical troubleshooting.",
            interpretation: "A summary is not the complete log and retained entries are not proof of current activity, compromise, or successful remote transfer.",
            privacy: "Sync logs can contain account, device, application, and activity details. Treat them as private diagnostic data."
        )
    case "summary_os_version":
        return FieldExplanation(
            title: "Sync Summary OS Version",
            meaning: "This identifies the operating-system version associated with the retained synchronization summary.",
            significance: "It provides build context for interpreting legacy behavior and migration across macOS releases.",
            interpretation: "The historical version does not necessarily match the current OS and does not prove when each summarized event occurred.",
            privacy: nil
        )
    default:
        return nil
    }
}

private func legacyIdentityExplanation(
    title: String,
    kind: String,
    responsible: Bool
) -> FieldExplanation {
    FieldExplanation(
        title: title,
        meaning: "This is the reported \(kind) for the \(responsible ? "software macOS associated as responsible for the event" : "process recorded in the legacy-software event").",
        significance: "It helps correlate the record with application bundles, signatures, package metadata, logs, and vendor information.",
        interpretation: "Reported identity metadata can be missing, stale, publisher-controlled, or shared by multiple files. It does not prove authorship, trust, or direct user launch.",
        privacy: "Software identity metadata can reveal private applications, developers, or internal products. Review it before publishing."
    )
}
