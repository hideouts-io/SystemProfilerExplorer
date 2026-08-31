import Foundation

indirect enum ProfileValue: Sendable, Equatable, Codable {
    case object([String: ProfileValue])
    case array([ProfileValue])
    case string(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        if let objectContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: ProfileValue] = [:]
            object.reserveCapacity(objectContainer.allKeys.count)

            for key in objectContainer.allKeys {
                object[key.stringValue] = try objectContainer.decode(ProfileValue.self, forKey: key)
            }

            self = .object(object)
            return
        }

        if var arrayContainer = try? decoder.unkeyedContainer() {
            var values: [ProfileValue] = []

            if let valueCount = arrayContainer.count {
                values.reserveCapacity(valueCount)
            }

            while !arrayContainer.isAtEnd {
                values.append(try arrayContainer.decode(ProfileValue.self))
            }

            self = .array(values)
            return
        }

        let singleValueContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        if singleValueContainer.decodeNil() {
            self = .null
        } else if let value = try? singleValueContainer.decode(String.self) {
            self = .string(value)
        } else if let value = try? singleValueContainer.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? singleValueContainer.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? singleValueContainer.decode(Double.self) {
            self = .decimal(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: singleValueContainer,
                debugDescription: "The profiler value was not a supported JSON type."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .object(object):
            var container: KeyedEncodingContainer<DynamicCodingKey> = encoder.container(
                keyedBy: DynamicCodingKey.self
            )

            for (key, value) in object {
                guard let codingKey = DynamicCodingKey(stringValue: key) else {
                    throw EncodingError.invalidValue(
                        key,
                        EncodingError.Context(
                            codingPath: encoder.codingPath,
                            debugDescription: "The profiler object contained a key that could not be encoded."
                        )
                    )
                }

                try container.encode(value, forKey: codingKey)
            }

        case let .array(values):
            var container: UnkeyedEncodingContainer = encoder.unkeyedContainer()

            for value in values {
                try container.encode(value)
            }

        case let .string(value):
            var container: SingleValueEncodingContainer = encoder.singleValueContainer()
            try container.encode(value)

        case let .integer(value):
            var container: SingleValueEncodingContainer = encoder.singleValueContainer()
            try container.encode(value)

        case let .decimal(value):
            var container: SingleValueEncodingContainer = encoder.singleValueContainer()
            try container.encode(value)

        case let .boolean(value):
            var container: SingleValueEncodingContainer = encoder.singleValueContainer()
            try container.encode(value)

        case .null:
            var container: SingleValueEncodingContainer = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }

    var preferredName: String? {
        guard case let .object(object) = self,
              case let .string(name)? = object["_name"] else {
            return nil
        }

        return name
    }
}

private struct DynamicCodingKey: CodingKey {
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
