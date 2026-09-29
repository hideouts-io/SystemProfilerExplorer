import Foundation
import Testing
@testable import SystemProfilerExplorer

struct FindingLocationTests {
    @Test
    func locationsIncludeRecordAndArrayPositions() {
        let location: String = findingLocation(
            dataType: .wifi,
            recordIndex: 0,
            path: ["spairport_airport_interfaces", "[]", "spairport_airport_other_local_wireless_networks", "[]", "spairport_signal_noise"],
            arrayIndices: [0, 3]
        )

        #expect(location == "SPAirPortDataType[0].spairport_airport_interfaces.[0].spairport_airport_other_local_wireless_networks.[3].spairport_signal_noise")
        #expect(sourcePath(fromLocation: location) == "SPAirPortDataType.spairport_airport_interfaces.[].spairport_airport_other_local_wireless_networks.[].spairport_signal_noise")
        #expect(sourcePath(fromLocation: "SPStorageDataType.free_space_in_bytes") == "SPStorageDataType.free_space_in_bytes")
    }

    @Test
    func groupsContainOnlyTheirOwnValues() {
        let value: String = findingLocation(
            dataType: .wifi,
            recordIndex: 1,
            path: ["spairport_airport_interfaces", "[]", "spairport_status_information"],
            arrayIndices: [2]
        )
        let record: String = findingLocation(dataType: .wifi, recordIndex: 1, path: [], arrayIndices: [])
        let interfaces: String = findingLocation(dataType: .wifi, recordIndex: 1, path: ["spairport_airport_interfaces"], arrayIndices: [])
        let thirdInterface: String = findingLocation(dataType: .wifi, recordIndex: 1, path: ["spairport_airport_interfaces", "[]"], arrayIndices: [2])
        let firstInterface: String = findingLocation(dataType: .wifi, recordIndex: 1, path: ["spairport_airport_interfaces", "[]"], arrayIndices: [0])

        #expect(locationIsInsideGroup(value, groupLocation: record))
        #expect(locationIsInsideGroup(value, groupLocation: interfaces))
        #expect(locationIsInsideGroup(value, groupLocation: thirdInterface))
        #expect(!locationIsInsideGroup(value, groupLocation: firstInterface))
        #expect(!locationIsInsideGroup("SPAirPortDataType[10].field", groupLocation: "SPAirPortDataType[1]"))
        #expect(!locationIsInsideGroup(value, groupLocation: value))
    }

    @Test
    func sourcePathsFromLocationsMatchFieldPresentation() {
        let path: [String] = ["physical_drive", "smart_status"]
        let presentation: FieldPresentation = fieldPresentation(dataType: .storage, path: path, scalar: .string("Verified"))
        let location: String = findingLocation(dataType: .storage, recordIndex: 2, path: path, arrayIndices: [])

        #expect(sourcePath(fromLocation: location) == presentation.sourcePath)
    }

    @Test
    func bookmarksMatchOneRecordButLegacyBookmarksMatchAll() {
        let first: String = "SPStorageDataType[0].free_space_in_bytes"
        let second: String = "SPStorageDataType[1].free_space_in_bytes"
        let field: String = "SPStorageDataType.free_space_in_bytes"

        #expect(bookmarkMatches([first], location: first, sourcePath: field))
        #expect(!bookmarkMatches([first], location: second, sourcePath: field))
        #expect(bookmarkMatches([field], location: second, sourcePath: field))
    }

    @Test
    func reviewSelectionAndWorthItemsUseExactLocations() throws {
        let volume: (Int64) -> ProfileValue = { free in
            .object([
                "mount_point": .string("/Volumes/Disk\(free)"),
                "free_space_in_bytes": .integer(free),
                "size_in_bytes": .integer(1_000),
                "physical_drive": .object(["protocol": .string("USB")])
            ])
        }
        let report = SystemProfilerReport(
            sections: [SystemProfilerSection(dataType: .storage, items: [volume(900), volume(50)])],
            commandArguments: [],
            standardError: "",
            startedAt: .now,
            completedAt: .now
        )
        let selected = selectedSystemReviewFindings(
            report: report,
            selectedSourcePaths: ["SPStorageDataType[1].free_space_in_bytes"]
        )
        let index: ReportPresentationIndex = try makeReportPresentationIndex(report)

        #expect(selected.map(\.location) == ["SPStorageDataType[1].free_space_in_bytes"])
        #expect(index.worthReviewingItems.map(\.location) == ["SPStorageDataType[1].free_space_in_bytes"])
    }
}
