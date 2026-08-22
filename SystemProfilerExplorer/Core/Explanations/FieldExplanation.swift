import Foundation

struct FieldExplanation: Sendable, Equatable {
    let title: String
    let meaning: String
    let significance: String
    let interpretation: String
    let privacy: String?
}

func explanation(
    for dataType: SystemProfilerDataType,
    path: [String],
    reportedValue: String
) -> FieldExplanation? {
    switch dataType {
    case .hardware:
        hardwareExplanation(path: path, reportedValue: reportedValue)
    case .storage:
        storageExplanation(path: path, reportedValue: reportedValue)
    case .power:
        powerExplanation(path: path, reportedValue: reportedValue)
    case .network, .ethernet:
        networkExplanation(path: path, reportedValue: reportedValue)
    case .wifi:
        wifiExplanation(path: path, reportedValue: reportedValue)
    case .bluetooth:
        bluetoothExplanation(path: path, reportedValue: reportedValue)
    case .networkLocation:
        networkLocationExplanation(path: path, reportedValue: reportedValue)
    case .networkVolumes:
        networkVolumeExplanation(path: path, reportedValue: reportedValue)
    case .software:
        softwareOverviewExplanation(path: path, reportedValue: reportedValue)
    case .applications:
        applicationExplanation(path: path, reportedValue: reportedValue)
    case .developerTools:
        developerToolsExplanation(path: path, reportedValue: reportedValue)
    case .extensions:
        extensionExplanation(path: path, reportedValue: reportedValue)
    case .frameworks:
        frameworkExplanation(path: path, reportedValue: reportedValue)
    case .fonts:
        fontExplanation(path: path, reportedValue: reportedValue)
    case .installHistory:
        installHistoryExplanation(path: path, reportedValue: reportedValue)
    case .international:
        internationalExplanation(path: path, reportedValue: reportedValue)
    case .preferencePanes:
        preferencePaneExplanation(path: path, reportedValue: reportedValue)
    case .printerSoftware:
        printerSoftwareExplanation(path: path, reportedValue: reportedValue)
    case .legacySoftware:
        legacySoftwareExplanation(path: path, reportedValue: reportedValue)
    case .startupItems:
        startupItemExplanation(path: path, reportedValue: reportedValue)
    case .syncServices:
        syncServicesExplanation(path: path, reportedValue: reportedValue)
    case .firewall:
        firewallExplanation(path: path, reportedValue: reportedValue)
    case .secureElement:
        secureElementExplanation(path: path, reportedValue: reportedValue)
    case .smartCards:
        smartCardExplanation(path: path, reportedValue: reportedValue)
    case .configurationProfiles:
        configurationProfileExplanation(path: path, reportedValue: reportedValue)
    case .managedClient:
        managedClientExplanation(path: path, reportedValue: reportedValue)
    case .universalAccess:
        accessibilityExplanation(path: path, reportedValue: reportedValue)
    default:
        additionalDataTypeExplanation(dataType: dataType, path: path)
    }
}
