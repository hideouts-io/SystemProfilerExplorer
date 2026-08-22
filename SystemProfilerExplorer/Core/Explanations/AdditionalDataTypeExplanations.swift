import Foundation

struct DataTypeExplanationContext: Sendable, Equatable {
    let subject: String
    let significance: String
    let limitation: String
}

func additionalDataTypeExplanation(
    dataType: SystemProfilerDataType,
    path: [String]
) -> FieldExplanation? {
    let context: DataTypeExplanationContext

    switch dataType {
    case .audio:
        context = DataTypeExplanationContext(
            subject: "the Mac's audio devices and routing",
            significance: "Audio metadata helps explain available inputs, outputs, sample rates, default routing, and the transport used by each device.",
            limitation: "The inventory does not prove that audio was recorded or played, identify the application using a device, or measure current signal quality."
        )
    case .camera:
        context = DataTypeExplanationContext(
            subject: "a camera recognized by macOS",
            significance: "Camera identity and connection metadata help distinguish built-in and attached imaging hardware during compatibility and privacy reviews.",
            limitation: "Device presence does not prove that the camera was active, that an application accessed it, or that any image was captured."
        )
    case .cardReader:
        context = DataTypeExplanationContext(
            subject: "the card-reader controller",
            significance: "Controller identity and link details help determine the reader hardware, its bus relationship, and its negotiated connection capability.",
            limitation: "A controller entry does not prove that removable media was inserted, mounted, read, or written."
        )
    case .diagnostics:
        context = DataTypeExplanationContext(
            subject: "diagnostic results retained by macOS",
            significance: "Diagnostic metadata can identify a recorded test, its result, and the system area evaluated when macOS exposes those details.",
            limitation: "A passing result is limited to the test and time represented; a failure requires corroboration and is not by itself evidence of compromise."
        )
    case .disabledSoftware:
        context = DataTypeExplanationContext(
            subject: "software macOS classified as disabled",
            significance: "This inventory can explain why a component is unavailable and help correlate compatibility or security enforcement with an installed item.",
            limitation: "A disabled entry does not prove malware, execution, persistence, or a current security incident. Verify the reason, signature, path, and operating-system policy separately."
        )
    case .discBurning:
        context = DataTypeExplanationContext(
            subject: "an optical-disc recording device",
            significance: "Drive and media capabilities determine which optical formats macOS can read or record through the reported device.",
            limitation: "Reported capability does not prove that a disc is inserted or that a burn or read operation occurred."
        )
    case .displays:
        context = DataTypeExplanationContext(
            subject: "the graphics processor or connected display",
            significance: "Graphics, connection, resolution, and display identity details help explain the active visual configuration and supported rendering capabilities.",
            limitation: "The inventory is a configuration snapshot; it does not measure application workload, frame rate, color accuracy, or prove that a display remained connected."
        )
    case .fibreChannel:
        context = storageInterfaceContext("a Fibre Channel storage interface")
    case .logs:
        context = DataTypeExplanationContext(
            subject: "a log artifact exposed by System Information",
            significance: "Log metadata and retained text can support troubleshooting and timeline correlation when interpreted with the originating subsystem.",
            limitation: "A log entry is evidence of a recorded message, not automatically an error, attack, or complete activity history. Retention and collection scope limit conclusions."
        )
    case .memory:
        context = DataTypeExplanationContext(
            subject: "installed system memory",
            significance: "Memory type, capacity, manufacturer, and slot information help verify the physical memory configuration and diagnose hardware compatibility.",
            limitation: "Inventory metadata does not measure current memory pressure, prove module authenticity, or replace hardware diagnostics. Unified-memory Macs may expose fewer module details."
        )
    case .nvme:
        context = storageInterfaceContext("an NVMe storage device")
    case .pci:
        context = DataTypeExplanationContext(
            subject: "a PCI or PCIe device",
            significance: "Bus identity, class, vendor, link, and driver details help map hardware devices to the software responsible for operating them.",
            limitation: "Enumeration proves that macOS described a bus object; it does not prove active use, trusted firmware, or a security problem."
        )
    case .parallelATA:
        context = storageInterfaceContext("a Parallel ATA storage interface")
    case .parallelSCSI:
        context = storageInterfaceContext("a Parallel SCSI storage interface")
    case .printers:
        context = DataTypeExplanationContext(
            subject: "a configured printer or scanner queue",
            significance: "Queue, driver, server, protocol, sharing, and capability metadata explain how macOS is configured to communicate with the print device.",
            limitation: "A configured queue does not prove the device is reachable, that a document was printed or scanned, or that the reported status is still current."
        )
    case .rawCamera:
        context = DataTypeExplanationContext(
            subject: "macOS RAW camera-format support",
            significance: "The compatibility entry identifies camera models or RAW formats the installed operating system knows how to decode.",
            limitation: "Support metadata does not prove that the camera is connected or that a matching image exists on the Mac."
        )
    case .sas:
        context = storageInterfaceContext("a Serial Attached SCSI storage interface")
    case .serialATA:
        context = storageInterfaceContext("a Serial ATA storage interface")
    case .spi:
        context = DataTypeExplanationContext(
            subject: "a device on the Mac's Serial Peripheral Interface",
            significance: "Hardware, firmware, manufacturer, and location identifiers help distinguish embedded controllers attached through the SPI bus.",
            limitation: "Enumeration does not establish firmware authenticity, current activity, or compromise. Embedded-device interpretation depends on the Mac model."
        )
    case .thunderbolt:
        context = DataTypeExplanationContext(
            subject: "the Thunderbolt or USB4 topology",
            significance: "Route, link, receptacle, vendor, and device details explain how high-speed controllers and peripherals are connected.",
            limitation: "A topology entry does not prove file access, network traffic, direct-memory access, or malicious behavior. Link state and negotiated speed are point-in-time observations."
        )
    case .usb:
        context = DataTypeExplanationContext(
            subject: "the USB host-controller topology",
            significance: "Controller, location, driver, identity, speed, and power details help map attached USB devices to their host path.",
            limitation: "USB enumeration shows what macOS described, not that an application successfully opened the device, exchanged payload data, or trusted its firmware."
        )
    case .iBridge:
        context = DataTypeExplanationContext(
            subject: "Apple bridge or security-controller state",
            significance: "Build, boot-policy, integrity, and hardware details provide context about the embedded controller and security policy reported for supported Mac models.",
            limitation: "These values are model- and build-specific summaries. They do not independently authenticate firmware or provide a complete Secure Boot, SIP, or management-policy audit."
        )
    case .applications, .bluetooth, .configurationProfiles, .developerTools, .ethernet,
         .extensions, .firewall, .fonts, .frameworks, .hardware, .installHistory,
         .international, .legacySoftware, .managedClient, .network, .networkLocation,
         .networkVolumes, .power, .preferencePanes, .printerSoftware, .secureElement,
         .smartCards, .software, .startupItems, .storage, .syncServices,
         .universalAccess, .wifi:
        return nil
    }

    return contextualFieldExplanation(context: context, path: path)
}

private func storageInterfaceContext(_ subject: String) -> DataTypeExplanationContext {
    DataTypeExplanationContext(
        subject: subject,
        significance: "Controller, device, transport, capacity, firmware, and health metadata help map storage hardware and assess compatibility or troubleshooting scope.",
        limitation: "Enumeration and a passing summary do not prove data integrity, complete device health, firmware authenticity, or that the storage was mounted or accessed."
    )
}
