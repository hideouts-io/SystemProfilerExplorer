import Foundation

enum ProfileValuePathComponent: Sendable, Hashable {
    case field(String)
    case index(Int)
}

/// An exact position in a parsed report. Display paths are never parsed for lookup:
/// a literal key containing dots, brackets, or an empty string remains one field.
struct ProfileValueAddress: Sendable, Hashable {
    let dataType: SystemProfilerDataType
    let path: [ProfileValuePathComponent]

    var sourcePath: String {
        path.reduce(dataType.rawValue) { result, component in
            switch component {
            case let .field(key): "\(result).\(key)"
            case let .index(index): "\(result)[\(index)]"
            }
        }
    }

    /// Length-delimited field keys keep distinct structures distinct in SwiftUI IDs,
    /// even when their human-readable source paths happen to look identical.
    var identity: String {
        path.reduce(dataType.rawValue + ":") { result, component in
            switch component {
            case let .field(key): "\(result)f\(key.utf8.count):\(key)"
            case let .index(index): "\(result)i\(index);"
            }
        }
    }
}

enum ProfileValueAddressError: LocalizedError, Equatable {
    case missingSection(SystemProfilerDataType)
    case repeatedSection(SystemProfilerDataType)
    case expectedRecordIndex
    case invalidIndex(Int)
    case missingField
    case expectedObject
    case expectedArray

    var errorDescription: String? {
        switch self {
        case let .missingSection(dataType):
            "The retained report does not contain the \(dataType.title) section. Close this viewer and compare complete reports again."
        case let .repeatedSection(dataType):
            "The retained report contains repeated \(dataType.title) sections, so this address is not unique. Compare reports with one section per data type."
        case .expectedRecordIndex:
            "The evidence address does not start with a record index. Close this viewer and create a new comparison."
        case let .invalidIndex(index):
            "The evidence address requests array index \(index), which is outside the retained array. Close this viewer and create a new comparison."
        case .missingField:
            "The addressed field is missing from the retained report. Close this viewer and create a new comparison."
        case .expectedObject:
            "The evidence address requests a field inside a value that is not an object. Close this viewer and create a new comparison."
        case .expectedArray:
            "The evidence address requests an index inside a value that is not an array. Close this viewer and create a new comparison."
        }
    }
}

/// Resolves only the supplied typed address against the supplied immutable report.
/// Missing values fail explicitly; a reported JSON null is a successful value.
func profileValue(at address: ProfileValueAddress, in report: SystemProfilerReport) throws -> ProfileValue {
    let sections: [SystemProfilerSection] = report.sections.filter { $0.dataType == address.dataType }
    guard let section = sections.first else {
        throw ProfileValueAddressError.missingSection(address.dataType)
    }
    guard sections.count == 1 else {
        throw ProfileValueAddressError.repeatedSection(address.dataType)
    }
    guard case .index? = address.path.first else {
        throw ProfileValueAddressError.expectedRecordIndex
    }

    return try address.path.reduce(ProfileValue.array(section.items)) { value, component in
        switch component {
        case let .field(key):
            guard case let .object(object) = value else {
                throw ProfileValueAddressError.expectedObject
            }
            guard let child = object[key] else {
                throw ProfileValueAddressError.missingField
            }
            return child
        case let .index(index):
            guard case let .array(items) = value else {
                throw ProfileValueAddressError.expectedArray
            }
            guard items.indices.contains(index) else {
                throw ProfileValueAddressError.invalidIndex(index)
            }
            return items[index]
        }
    }
}

/// Identifies one reported value, including which record and array item it's in, such
/// as `SPStorageDataType[1].free_space_in_bytes`. A source path such as
/// `SPStorageDataType.free_space_in_bytes` names the field and is the same for every
/// record, so bookmarks and highlights use locations instead.
func findingLocation(
    dataType: SystemProfilerDataType,
    recordIndex: Int,
    path: [String],
    arrayIndices: [Int]
) -> String {
    var segments: [String] = ["\(dataType.rawValue)[\(recordIndex)]"]
    var nextArrayIndex: Int = 0

    for segment in path {
        if segment == "[]", nextArrayIndex < arrayIndices.count {
            segments.append("[\(arrayIndices[nextArrayIndex])]")
            nextArrayIndex += 1
        } else {
            segments.append(segment)
        }
    }

    return segments.joined(separator: ".")
}

/// The field's source path for a location; a source path is returned unchanged.
func sourcePath(fromLocation location: String) -> String {
    location
        .replacingOccurrences(of: #"^(SP\w+DataType)\[\d+\]"#, with: "$1", options: .regularExpression)
        .replacingOccurrences(of: #"\.\[\d+\]"#, with: ".[]", options: .regularExpression)
}

/// Whether a saved bookmark refers to this value. Bookmarks saved before locations
/// existed hold a source path and still match every record with that field.
func bookmarkMatches(_ bookmarks: Set<String>, location: String, sourcePath: String) -> Bool {
    bookmarks.contains(location) || bookmarks.contains(sourcePath)
}

/// Whether a value's location is inside the group at `groupLocation`, such as
/// `SPStorageDataType[1].physical_drive.medium_type` inside `SPStorageDataType[1]`.
/// `SPStorageDataType[10]` is not inside `SPStorageDataType[1]`.
func locationIsInsideGroup(_ location: String, groupLocation: String) -> Bool {
    location.hasPrefix(groupLocation + ".")
}
