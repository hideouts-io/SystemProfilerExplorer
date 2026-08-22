import Foundation

func contextualFieldExplanation(
    context: DataTypeExplanationContext,
    path: [String]
) -> FieldExplanation {
    let rawField: String = path.last(where: { $0 != "[]" }) ?? "reported_value"
    let field: String = normalizedExplanationField(rawField)

    if isLogContentField(field) {
        return FieldExplanation(
            title: "Log Contents",
            meaning: "This is retained diagnostic or log text that System Information included for \(context.subject).",
            significance: "The text can preserve event descriptions, timestamps, subsystem messages, and error context useful for focused troubleshooting or timeline correlation.",
            interpretation: "Do not interpret isolated wording as proof of failure or compromise. Correlate it with its source, timestamp, surrounding messages, current state, and retention limits.",
            privacy: "Log text can contain usernames, paths, hostnames, device identifiers, network details, document names, and application activity. Redact it before sharing."
        )
    }

    if isPersistentIdentifierField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is an identifier System Information associates with \(context.subject).",
            significance: "Identifiers help correlate the same reported component, controller, route, or record across related diagnostics and repeated inventories.",
            interpretation: "An identifier is not proof of ownership, authenticity, current use, or malicious behavior. Its uniqueness and stability depend on the field and hardware implementation.",
            privacy: "Persistent identifiers can fingerprint a device or correlate reports over time. Redact them from public reports unless exact correlation is required."
        )
    }

    if isHardwareClassificationField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is a vendor, product, subsystem, or class identifier reported for \(context.subject).",
            significance: "Classification identifiers help match hardware to vendor documentation, drivers, bus registries, and other inventory records.",
            interpretation: "These values commonly identify a product family rather than a unique physical device. They do not authenticate the component or prove current activity.",
            privacy: "Hardware classifications can contribute to device fingerprinting when combined with model, serial, location, and configuration details."
        )
    }

    if isVersionField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is version, revision, build, or firmware metadata reported for \(context.subject).",
            significance: "Version metadata supports compatibility checks and correlation with vendor releases, operating-system support, and known device behavior.",
            interpretation: "A version string is reported metadata, not cryptographic proof that the component is genuine, current, correctly installed, or free of vulnerabilities. \(context.limitation)",
            privacy: nil
        )
    }

    if isStatusField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is a state, status, health, or diagnostic result reported for \(context.subject) at collection time.",
            significance: "The value helps distinguish available, active, connected, healthy, restricted, or failed states within the scope represented by the field.",
            interpretation: "Treat the result as a point-in-time summary. A normal value is not a guarantee, and an unexpected value requires corroboration with current state and authoritative diagnostics. \(context.limitation)",
            privacy: nil
        )
    }

    if isCapabilityField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This reports a capability or configured feature associated with \(context.subject).",
            significance: "Capability flags help determine which functions macOS believes the component or queue can support.",
            interpretation: "Supported or enabled capability does not prove the feature was used, that a related event occurred, or that every software layer can use it successfully. \(context.limitation)",
            privacy: nil
        )
    }

    if isCapacityField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This reports a size, capacity, or byte count associated with \(context.subject).",
            significance: "Capacity values help compare hardware configuration, stored artifacts, media layout, and resource limits.",
            interpretation: "Units and allocation semantics depend on the field. Reported capacity does not establish usable free space, data integrity, or current workload. \(context.limitation)",
            privacy: nil
        )
    }

    if isPerformanceField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is a rate, speed, width, frequency, resolution, or other capability measurement reported for \(context.subject).",
            significance: "The value helps explain negotiated connection capability, media quality, display geometry, processing resources, or expected throughput.",
            interpretation: "A reported maximum or negotiated value is not a benchmark and does not measure sustained real-world performance. \(context.limitation)",
            privacy: nil
        )
    }

    if isConnectionField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This describes the bus, route, transport, protocol, source, or connection used for \(context.subject).",
            significance: "Connection metadata helps map the component into the Mac's hardware or service topology and identify which diagnostic layer applies.",
            interpretation: "A represented connection does not prove data transfer, successful application access, or continuous availability. \(context.limitation)",
            privacy: connectionPrivacy(field)
        )
    }

    if isDriverField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This identifies driver or support-software metadata associated with \(context.subject).",
            significance: "Driver information helps correlate hardware or a service queue with the software responsible for exposing its capabilities to macOS.",
            interpretation: "A driver association does not prove the driver is currently executing, trusted, current, or responsible for an observed event. Verify signature, load state, and provenance separately.",
            privacy: "Driver paths and names can reveal installed products, organization-specific packages, and local filesystem structure. Review them before sharing."
        )
    }

    if isDateField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is date or time metadata associated with \(context.subject).",
            significance: "The timestamp can support correlation with configuration changes, device history, diagnostics, and other retained evidence.",
            interpretation: "The field's producer and semantics determine whether it represents creation, modification, manufacture, or collection. It does not by itself identify who caused an event.",
            privacy: "Timestamps can reveal device-use and administrative activity patterns. Review them before public sharing."
        )
    }

    if isManufacturerOrModelField(field) {
        return FieldExplanation(
            title: semanticFieldTitle(rawField),
            meaning: "This is manufacturer, model, product, or device-name metadata reported for \(context.subject).",
            significance: "Identity metadata supports compatibility checks and correlation with physical labels, vendor documentation, drivers, and other inventories. \(context.significance)",
            interpretation: "Names and model strings can be vendor-controlled or generalized. They do not prove authenticity, ownership, current use, or a security issue. \(context.limitation)",
            privacy: "Custom device, queue, or server names can reveal people, organizations, locations, or infrastructure. Review them before sharing."
        )
    }

    return FieldExplanation(
        title: semanticFieldTitle(rawField),
        meaning: "This is the \(semanticFieldTitle(rawField).lowercased()) value System Information reported for \(context.subject).",
        significance: context.significance,
        interpretation: "Interpret the value with its containing record and neighboring fields. Schema names and encodings can vary by macOS release and hardware model. \(context.limitation)",
        privacy: nil
    )
}

private func normalizedExplanationField(_ field: String) -> String {
    field
        .lowercased()
        .replacingOccurrences(of: "-", with: "_")
        .replacingOccurrences(of: " ", with: "_")
}

private func semanticFieldTitle(_ field: String) -> String {
    displayName(
        for: field
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    )
}

private func fieldContains(_ field: String, terms: [String]) -> Bool {
    terms.contains(where: field.contains)
}

private func isLogContentField(_ field: String) -> Bool {
    field == "contents" || field.hasSuffix("_contents")
}

private func isPersistentIdentifierField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "serial", "uuid", "guid", "unique_id", "uniqueid", "switch_uid", "location_id",
        "locationid", "route_string", "domain_uuid", "receptacle_id"
    ])
}

private func isHardwareClassificationField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "vendor_id", "vendorid", "product_id", "productid", "device_id", "deviceid",
        "subsystem_id", "hardware_id", "displayid"
    ])
}

private func isVersionField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "version", "revision", "firmware", "build", "boot_rom", "stfw", "mtfw"
    ])
}

private func isStatusField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "status", "state", "health", "diagnostic", "condition", "result", "online",
        "link_status", "secure_boot", "smart"
    ])
}

private func isCapabilityField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "supported", "support", "capable", "enabled", "available", "removable", "detachable",
        "default", "shared", "sharing", "mirror", "main", "input", "output", "scanner",
        "trim", "ambient_brightness"
    ])
}

private func isCapacityField(_ field: String) -> Bool {
    fieldContains(field, terms: ["size", "capacity", "bytesize", "byte_size", "_in_bytes"])
}

private func isPerformanceField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "speed", "rate", "srate", "frequency", "width", "resolution", "pixels", "cores",
        "channel", "bandwidth"
    ])
}

private func isConnectionField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "transport", "connection", "protocol", "interface", "bus", "source", "route",
        "receptacle", "printserver", "uri"
    ])
}

private func isDriverField(_ field: String) -> Bool {
    fieldContains(field, terms: ["driver", "kext", "ppd", "iocontent"])
}

private func isDateField(_ field: String) -> Bool {
    fieldContains(field, terms: ["date", "modified", "timestamp", "display_week", "display_year"])
}

private func isManufacturerOrModelField(_ field: String) -> Bool {
    fieldContains(field, terms: [
        "manufacturer", "vendor", "model", "product", "device_name", "device_type", "media_name"
    ])
}

private func connectionPrivacy(_ field: String) -> String? {
    guard fieldContains(field, terms: ["source", "server", "uri", "route"]) else {
        return nil
    }

    return "Connection sources and routes can expose server names, addresses, queue names, usernames, or physical topology. Redact them when sharing is not necessary."
}
