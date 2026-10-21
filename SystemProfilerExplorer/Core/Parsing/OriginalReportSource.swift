import Foundation

/// Original input is private session state, deliberately not Codable. `id` names
/// one capture, survives report copies, and does not participate in report equality.
struct OriginalReportSource: Sendable {
    let id: UUID
    fileprivate let bytes: Data
    fileprivate let format: OriginalReportSourceFormat

    /// Call only with the owned input returned by `ownedOriginalReportBytes`, after
    /// Foundation has validated that same input. Never retain file-mapped storage.
    init(ownedBytes: Data, format: OriginalReportSourceFormat) {
        id = UUID()
        bytes = ownedBytes
        self.format = format
    }
}

enum OriginalReportSourceFormat: Sendable {
    case systemProfiler
    case reportExport(sectionDataTypes: [SystemProfilerDataType])
}

struct OriginalSourceExcerpt: Sendable, Equatable {
    let bytes: Data
    let text: String
    /// Offsets into the entire captured input, including an export's envelope or
    /// UTF-8 BOM. The range contains the JSON value token and its internal spacing.
    let byteRange: Range<Int>
}

enum OriginalReportSourceError: LocalizedError, Equatable {
    case unsupportedEncoding
    case ambiguousDuplicateKey(byteOffset: Int)
    case sourceMismatch
    case invalidByteRange
    case nestingLimitExceeded(limit: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            "Exact source excerpts require UTF-8 JSON. The retained input uses an unsupported encoding. Collect or import a UTF-8 report to view original bytes."
        case let .ambiguousDuplicateKey(byteOffset):
            "The retained JSON repeats an object key at byte \(byteOffset), so an exact source address is ambiguous. Collect or import a report with unique object keys."
        case .sourceMismatch:
            "The requested value does not match its retained JSON source. Close this viewer and reopen or collect the report before requesting original bytes."
        case .invalidByteRange:
            "The requested source range is outside the retained input. Close this viewer and reopen or collect the report."
        case let .nestingLimitExceeded(limit):
            "The original JSON exceeds the source locator's nesting limit of \(limit). Use a report with shallower nesting to view original bytes."
        }
    }
}

/// An eager copy must precede decoding: Data's value semantics do not protect a
/// file mapping from later in-place file writes. Copying Data with Data(data) can
/// share storage; Data(bytes:count:) allocates independent storage instead.
func ownedOriginalReportBytes(_ data: Data) throws -> Data {
    try Task.checkCancellation()
    let owned: Data = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data in
        guard let baseAddress = buffer.baseAddress else {
            return Data()
        }
        return Data(bytes: baseAddress, count: buffer.count)
    }
    try Task.checkCancellation()
    return owned
}

/// Returns nil only when the report has no retained input. A shorter typed address
/// (for example just `.index(recordIndex)`) returns the surrounding record with its
/// original spacing, escapes, and key order. No file is reopened or reserialized.
/// Foundation validates imports and decodes the selected token; the walker only
/// locates token boundaries in that already validated, immutable UTF-8 document.
func originalSourceExcerpt(
    at address: ProfileValueAddress,
    in report: SystemProfilerReport
) throws -> OriginalSourceExcerpt? {
    guard let source = report.originalSource else {
        return nil
    }
    try Task.checkCancellation()
    let expected: ProfileValue = try profileValue(at: address, in: report)
    let path: [ProfileValuePathComponent] = try originalSourcePath(address, source: source)
    let range: Range<Int> = try source.bytes.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
        var locator: OriginalJSONLocator = OriginalJSONLocator(bytes: buffer, path: path)
        return try locator.locate()
    }
    guard range.lowerBound >= 0, range.upperBound <= source.bytes.count,
          range.lowerBound < range.upperBound else {
        throw OriginalReportSourceError.invalidByteRange
    }
    let bytes: Data = source.bytes.subdata(in: range)
    let value: ProfileValue = try JSONDecoder().decode(ProfileValue.self, from: bytes)
    guard value == expected else {
        throw OriginalReportSourceError.sourceMismatch
    }
    guard let text = String(data: bytes, encoding: .utf8) else {
        throw OriginalReportSourceError.unsupportedEncoding
    }
    try Task.checkCancellation()
    return OriginalSourceExcerpt(bytes: bytes, text: text, byteRange: range)
}

private func originalSourcePath(
    _ address: ProfileValueAddress,
    source: OriginalReportSource
) throws -> [ProfileValuePathComponent] {
    switch source.format {
    case .systemProfiler:
        return [.field(address.dataType.rawValue)] + address.path
    case let .reportExport(sectionDataTypes):
        let indices: [Int] = sectionDataTypes.indices.filter { sectionDataTypes[$0] == address.dataType }
        guard indices.count == 1, let index = indices.first else {
            throw OriginalReportSourceError.sourceMismatch
        }
        return [.field("report"), .field("sections"), .index(index), .field("items")] + address.path
    }
}

/// A single forward pass, bounded by the input length and 512 nesting levels.
/// Cancellation is checked at each value and every 4096 advanced bytes, including
/// long strings. All object keys are decoded by Foundation, including escapes and
/// surrogate pairs; duplicate keys anywhere fail rather than selecting a winner.
private struct OriginalJSONLocator {
    let bytes: UnsafeRawBufferPointer
    let path: [ProfileValuePathComponent]
    private var offset: Int
    private var selectedRange: Range<Int>?
    private let maximumDepth: Int = 512

    init(bytes: UnsafeRawBufferPointer, path: [ProfileValuePathComponent]) {
        self.bytes = bytes
        self.path = path
        offset = 0
        selectedRange = nil
    }

    mutating func locate() throws -> Range<Int> {
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            offset = 3
        }
        try skipWhitespace()
        // Foundation also accepts UTF-16/32. Their ASCII punctuation bytes can
        // look like UTF-8; reject zero-padded root delimiters explicitly.
        guard offset < bytes.count, bytes[offset] == 0x7B,
              offset + 1 < bytes.count, bytes[offset + 1] != 0 else {
            throw OriginalReportSourceError.unsupportedEncoding
        }
        try visitValue(depth: 0, matchedCount: 0)
        try skipWhitespace()
        guard offset == bytes.count, let selectedRange else {
            throw OriginalReportSourceError.sourceMismatch
        }
        return selectedRange
    }

    private mutating func visitValue(depth: Int, matchedCount: Int?) throws {
        try Task.checkCancellation()
        guard depth <= maximumDepth else {
            throw OriginalReportSourceError.nestingLimitExceeded(limit: maximumDepth)
        }
        try skipWhitespace()
        guard offset < bytes.count else {
            throw OriginalReportSourceError.invalidByteRange
        }
        let start: Int = offset
        switch bytes[offset] {
        case 0x7B:
            try visitObject(depth: depth, matchedCount: matchedCount)
        case 0x5B:
            try visitArray(depth: depth, matchedCount: matchedCount)
        case 0x22:
            _ = try stringRange()
        default:
            while offset < bytes.count, !isValueDelimiter(bytes[offset]) {
                try advance()
            }
            guard offset > start else {
                throw OriginalReportSourceError.sourceMismatch
            }
        }
        if matchedCount == path.count {
            guard selectedRange == nil else {
                throw OriginalReportSourceError.sourceMismatch
            }
            selectedRange = start..<offset
        }
    }

    private mutating func visitObject(depth: Int, matchedCount: Int?) throws {
        try consume(0x7B)
        try skipWhitespace()
        if try consumeIfPresent(0x7D) { return }
        var keys: Set<String> = []
        while true {
            let keyRange: Range<Int> = try stringRange()
            let key: String = try JSONDecoder().decode(String.self, from: Data(bytes[keyRange]))
            guard keys.insert(key).inserted else {
                throw OriginalReportSourceError.ambiguousDuplicateKey(byteOffset: keyRange.lowerBound)
            }
            try skipWhitespace()
            try consume(0x3A)
            try visitValue(depth: depth + 1, matchedCount: childMatch(.field(key), matchedCount: matchedCount))
            try skipWhitespace()
            if try consumeIfPresent(0x7D) { return }
            try consume(0x2C)
            try skipWhitespace()
        }
    }

    private mutating func visitArray(depth: Int, matchedCount: Int?) throws {
        try consume(0x5B)
        try skipWhitespace()
        if try consumeIfPresent(0x5D) { return }
        var index: Int = 0
        while true {
            try visitValue(depth: depth + 1, matchedCount: childMatch(.index(index), matchedCount: matchedCount))
            index += 1
            try skipWhitespace()
            if try consumeIfPresent(0x5D) { return }
            try consume(0x2C)
        }
    }

    private func childMatch(_ component: ProfileValuePathComponent, matchedCount: Int?) -> Int? {
        guard let matchedCount, matchedCount < path.count,
              path[matchedCount] == component else { return nil }
        return matchedCount + 1
    }

    private mutating func stringRange() throws -> Range<Int> {
        let start: Int = offset
        try consume(0x22)
        while offset < bytes.count {
            let byte: UInt8 = bytes[offset]
            try advance()
            if byte == 0x22 { return start..<offset }
            if byte == 0x5C { try advance() }
        }
        throw OriginalReportSourceError.invalidByteRange
    }

    private mutating func skipWhitespace() throws {
        while offset < bytes.count, isJSONWhitespace(bytes[offset]) {
            try advance()
        }
    }

    private mutating func consume(_ byte: UInt8) throws {
        guard try consumeIfPresent(byte) else {
            throw OriginalReportSourceError.sourceMismatch
        }
    }

    private mutating func consumeIfPresent(_ byte: UInt8) throws -> Bool {
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        try advance()
        return true
    }

    private mutating func advance() throws {
        guard offset < bytes.count else {
            throw OriginalReportSourceError.invalidByteRange
        }
        offset += 1
        if offset.isMultiple(of: 4096) { try Task.checkCancellation() }
    }
}

private func isJSONWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
}

private func isValueDelimiter(_ byte: UInt8) -> Bool {
    isJSONWhitespace(byte) || byte == 0x2C || byte == 0x5D || byte == 0x7D
}
