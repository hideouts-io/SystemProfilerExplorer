import Foundation

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
