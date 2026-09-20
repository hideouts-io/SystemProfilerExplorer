import Foundation

enum SystemProfilerParsingError: LocalizedError, Equatable {
    case invalidJSON(reason: String)
    case noSupportedDataTypes
    case invalidDataTypeSection(identifier: String)

    var errorDescription: String? {
        switch self {
        case let .invalidJSON(reason):
            "system_profiler returned JSON that could not be decoded. \(reason)"
        case .noSupportedDataTypes:
            "The JSON document does not contain a supported system_profiler data-type section. Select JSON created by system_profiler with the -json option."
        case let .invalidDataTypeSection(identifier):
            "The \(identifier) section must be a JSON array, matching the structure produced by system_profiler -json."
        }
    }
}

struct SystemProfilerParser: Sendable {
    func parse(_ execution: SystemProfilerExecution) throws -> SystemProfilerReport {
        let payload: SystemProfilerPayload = try decodePayload(execution.standardOutput)

        let sections: [SystemProfilerSection] = execution.request.dataTypes.compactMap { dataType in
            guard let items = payload.sections[dataType.rawValue] else {
                return nil
            }

            return SystemProfilerSection(dataType: dataType, items: items)
        }

        return SystemProfilerReport(
            sections: sections,
            commandArguments: execution.request.arguments,
            standardError: execution.standardError,
            startedAt: execution.startedAt,
            completedAt: execution.completedAt
        )
    }

    func parseImportedReport(_ data: Data, importedAt: Date) throws -> SystemProfilerReport {
        let payload: SystemProfilerPayload = try decodePayload(data)
        let sections: [SystemProfilerSection] = SystemProfilerDataType.allCases.compactMap { dataType in
            guard let items = payload.sections[dataType.rawValue] else {
                return nil
            }

            return SystemProfilerSection(dataType: dataType, items: items)
        }

        guard !sections.isEmpty else {
            throw SystemProfilerParsingError.noSupportedDataTypes
        }

        return SystemProfilerReport(
            sections: sections,
            commandArguments: [],
            standardError: "",
            startedAt: importedAt,
            completedAt: importedAt
        )
    }
}

private func decodePayload(_ data: Data) throws -> SystemProfilerPayload {
    do {
        let payload: SystemProfilerPayload = try JSONDecoder().decode(SystemProfilerPayload.self, from: data)

        if let invalidIdentifier = payload.invalidSectionIdentifiers.sorted().first {
            throw SystemProfilerParsingError.invalidDataTypeSection(identifier: invalidIdentifier)
        }

        return payload
    } catch let error as DecodingError {
        throw SystemProfilerParsingError.invalidJSON(reason: decodingErrorDescription(error))
    }
}

private struct SystemProfilerPayload: Decodable {
    let sections: [String: [ProfileValue]]
    let invalidSectionIdentifiers: Set<String>

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PayloadCodingKey.self)
        var decodedSections: [String: [ProfileValue]] = [:]
        var invalidIdentifiers: Set<String> = []
        let supportedIdentifiers: Set<String> = Set(SystemProfilerDataType.allCases.map(\.rawValue))
        decodedSections.reserveCapacity(container.allKeys.count)

        for key in container.allKeys {
            let value: ProfileValue = try container.decode(ProfileValue.self, forKey: key)

            guard case let .array(items) = value else {
                if supportedIdentifiers.contains(key.stringValue) {
                    invalidIdentifiers.insert(key.stringValue)
                }

                continue
            }

            decodedSections[key.stringValue] = items
        }

        sections = decodedSections
        invalidSectionIdentifiers = invalidIdentifiers
    }
}

private struct PayloadCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private func decodingErrorDescription(_ error: DecodingError) -> String {
    switch error {
    case let .dataCorrupted(context):
        "Data was corrupted at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
    case let .keyNotFound(key, context):
        "Key \(key.stringValue) was missing at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
    case let .typeMismatch(type, context):
        "Expected \(String(describing: type)) at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
    case let .valueNotFound(type, context):
        "Expected a \(String(describing: type)) value at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
    @unknown default:
        "An unknown decoding error occurred: \(String(reflecting: error))"
    }
}

private func codingPathDescription(_ codingPath: [CodingKey]) -> String {
    guard !codingPath.isEmpty else {
        return "the document root"
    }

    return codingPath.map(\.stringValue).joined(separator: ".")
}
