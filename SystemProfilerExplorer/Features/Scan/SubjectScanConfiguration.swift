import Foundation

struct SubjectScanConfiguration: Sendable, Equatable {
    let request: SystemProfilerRequest
}

func scanConfiguration(for subject: ProfilerSubject) -> SubjectScanConfiguration? {
    let dataTypes: [SystemProfilerDataType]
    let timeoutSeconds: Int

    switch subject {
    case .overview:
        dataTypes = [.hardware, .software, .storage, .network, .power, .firewall]
        timeoutSeconds = 90
    case .hardware:
        dataTypes = [
            .hardware,
            .memory,
            .displays,
            .audio,
            .camera,
            .bluetooth,
            .cardReader,
            .iBridge,
            .pci,
            .parallelATA,
            .spi,
            .thunderbolt,
            .usb,
            .printers
        ]
        timeoutSeconds = 120
    case .storage:
        dataTypes = [
            .storage,
            .nvme,
            .serialATA,
            .parallelATA,
            .parallelSCSI,
            .sas,
            .fibreChannel,
            .discBurning,
            .cardReader,
            .networkVolumes
        ]
        timeoutSeconds = 120
    case .network:
        dataTypes = [
            .network,
            .wifi,
            .ethernet,
            .bluetooth,
            .networkLocation,
            .networkVolumes
        ]
        timeoutSeconds = 90
    case .software:
        dataTypes = [
            .software,
            .applications,
            .developerTools,
            .extensions,
            .frameworks,
            .fonts,
            .installHistory,
            .international,
            .preferencePanes,
            .printerSoftware,
            .rawCamera,
            .legacySoftware,
            .startupItems,
            .syncServices
        ]
        timeoutSeconds = 180
    case .security:
        dataTypes = [
            .firewall,
            .secureElement,
            .smartCards,
            .configurationProfiles,
            .managedClient,
            .diagnostics,
            .disabledSoftware,
            .universalAccess
        ]
        timeoutSeconds = 120
    case .power:
        dataTypes = [.power]
        timeoutSeconds = 60
    case .reports:
        dataTypes = SystemProfilerDataType.allCases
        timeoutSeconds = 300
    }

    return SubjectScanConfiguration(
        request: SystemProfilerRequest(
            dataTypes: dataTypes,
            detailLevel: .full,
            timeoutSeconds: timeoutSeconds
        )
    )
}
