import Foundation
import Testing
@testable import SystemProfilerExplorer

struct RawReportImportTests {
    @Test
    func importsRecognizedSectionsAndIgnoresUnrelatedRootData() throws {
        let data: Data = Data(
            #"{"SPHardwareDataType":[{"_name":"Hardware","machine_model":"Mac00,0","nested":{"count":2}}],"unrelated":{"format":"metadata"}}"#.utf8
        )
        let importedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)

        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            data,
            importedAt: importedAt
        )

        #expect(report.sections.count == 1)
        #expect(report.sections[0].dataType == .hardware)
        #expect(report.sections[0].items.count == 1)
        #expect(report.commandArguments.isEmpty)
        #expect(report.standardError.isEmpty)
        #expect(report.startedAt == importedAt)
        #expect(report.completedAt == importedAt)
    }

    @Test
    func importedSectionsUseTheApplicationDataTypeOrder() throws {
        let data: Data = Data(
            #"{"SPPowerDataType":[],"SPHardwareDataType":[],"SPUSBHostDataType":[]}"#.utf8
        )

        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            data,
            importedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(report.sections.map(\.dataType) == [.hardware, .power, .usb])
    }

    @Test
    func rejectsJSONWithoutRecognizedSystemProfilerSections() {
        let data: Data = Data(#"{"metadata":{"format":"other"}}"#.utf8)

        #expect(throws: SystemProfilerParsingError.noSupportedDataTypes) {
            _ = try SystemProfilerParser().parseImportedReport(
                data,
                importedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }

    @Test
    func rejectsRecognizedSectionWithTheWrongJSONShape() {
        let data: Data = Data(#"{"SPHardwareDataType":{"machine_model":"Mac00,0"}}"#.utf8)

        #expect(
            throws: SystemProfilerParsingError.invalidDataTypeSection(
                identifier: SystemProfilerDataType.hardware.rawValue
            )
        ) {
            _ = try SystemProfilerParser().parseImportedReport(
                data,
                importedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }

    @Test
    func originalExcerptsPreserveUTF8BytesEscapesWhitespaceAndTypedKeys() throws {
        let prefix: String = "\u{FEFF}\r\n{ \"SPHardwareDataType\" : [\n  "
        let recordPrefix: String = #"{ "a.b[0]" : { "" : [ 0, { "\u00e9\u0022\\" : "#
        let token: String = #""line\n\uD83D\uDE00\/ café""#
        let record: String = recordPrefix + token + #" } ] }, "0" : null, "[]" : true }"#
        let input: Data = Data((prefix + record + "\n ] }\r\n").utf8)
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            input, importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let address: ProfileValueAddress = ProfileValueAddress(
            dataType: .hardware,
            path: [.index(0), .field("a.b[0]"), .field(""), .index(1), .field("é\"\\")]
        )
        let excerpt: OriginalSourceExcerpt = try #require(try originalSourceExcerpt(at: address, in: report))
        let lowerBound: Int = (prefix + recordPrefix).utf8.count

        #expect(excerpt.text == token)
        #expect(excerpt.bytes == Data(token.utf8))
        #expect(excerpt.byteRange == lowerBound..<(lowerBound + token.utf8.count))
        #expect(input.subdata(in: excerpt.byteRange) == excerpt.bytes)
        #expect(try profileValue(at: address, in: report) == .string("line\n😀/ café"))

        let recordAddress: ProfileValueAddress = ProfileValueAddress(dataType: .hardware, path: [.index(0)])
        let surrounding: OriginalSourceExcerpt = try #require(try originalSourceExcerpt(at: recordAddress, in: report))
        #expect(surrounding.bytes == Data(record.utf8))
        #expect(surrounding.byteRange == prefix.utf8.count..<(prefix.utf8.count + record.utf8.count))
        #expect(input.subdata(in: surrounding.byteRange) == surrounding.bytes)
        #expect(try originalSourceExcerpt(
            at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("0")]), in: report
        )?.text == "null")
        #expect(try originalSourceExcerpt(
            at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("[]")]), in: report
        )?.text == "true")
    }

    @Test(arguments: ["null", "true", "false", "-12", "1.2300e+02", "[ 0, { \"x\" : 1 } ]", "{ }"])
    func originalExcerptPreservesEachJSONValueToken(_ token: String) throws {
        let prefix: String = #"{"SPHardwareDataType":[{"value": "#
        let input: Data = Data((prefix + token + " } ] }").utf8)
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            input, importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let excerpt: OriginalSourceExcerpt = try #require(try originalSourceExcerpt(
            at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")]), in: report
        ))

        #expect(excerpt.bytes == Data(token.utf8))
        #expect(excerpt.text == token)
        #expect(excerpt.byteRange == prefix.utf8.count..<(prefix.utf8.count + token.utf8.count))
    }

    @Test
    func importsHaveDistinctSourceIdentitiesButKeepSemanticEquality() throws {
        let parser: SystemProfilerParser = SystemProfilerParser()
        let first: SystemProfilerReport = try parser.parseImportedReport(
            Data(#"{"SPHardwareDataType":[{"value":1}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let second: SystemProfilerReport = try parser.parseImportedReport(
            Data(#"{ "SPHardwareDataType" : [ { "value" : 1 } ] }"#.utf8),
            importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let repeated: SystemProfilerReport = try parser.parseImportedReport(
            Data(#"{"SPHardwareDataType":[{"value":1}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let copied: SystemProfilerReport = first

        #expect(first == second)
        #expect(first == repeated)
        #expect(try #require(first.originalSource).id != #require(second.originalSource).id)
        #expect(try #require(first.originalSource).id != #require(repeated.originalSource).id)
        #expect(copied.originalSource?.id == first.originalSource?.id)
    }

    @Test(arguments: [
        #"{"SPHardwareDataType":[{"value":1,"\u0076alue":2}]}"#,
        #"{"SPHardwareDataType":[{"value":{"x":1,"x":1}}]}"#,
        #"{"SPHardwareDataType":[{"value":1}],"SPHardwareDataType":[{"value":1}]}"#
    ])
    func ambiguousDuplicateKeysFailExplicitly(_ json: String) throws {
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            Data(json.utf8), importedAt: Date(timeIntervalSince1970: 5_000)
        )
        #expect {
            _ = try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")]), in: report
            )
        } throws: { error in
            guard let sourceError = error as? OriginalReportSourceError,
                  case .ambiguousDuplicateKey = sourceError else { return false }
            return true
        }
    }

    @Test
    func sourceLookupFailsForInvalidAddressesAndMismatchedValues() throws {
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            Data(#"{"SPHardwareDataType":[{"value":1}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 5_000)
        )
        #expect(throws: ProfileValueAddressError.invalidIndex(-1)) {
            _ = try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(-1)]), in: report
            )
        }
        #expect(throws: ProfileValueAddressError.invalidIndex(1)) {
            _ = try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(1)]), in: report
            )
        }
        #expect(throws: ProfileValueAddressError.missingField) {
            _ = try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("missing")]), in: report
            )
        }
        let mismatched: SystemProfilerReport = SystemProfilerReport(
            sections: [SystemProfilerSection(dataType: .hardware, items: [.object(["value": .integer(2)])])],
            commandArguments: report.commandArguments,
            standardError: report.standardError,
            startedAt: report.startedAt,
            completedAt: report.completedAt,
            originalSource: report.originalSource
        )
        #expect(throws: OriginalReportSourceError.sourceMismatch) {
            _ = try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")]), in: mismatched
            )
        }
    }

    @Test
    func nonUTF8ImportRetainsSourceButRefusesAnExactTextExcerpt() throws {
        let input: Data = try #require(#"{"SPHardwareDataType":[{"value":1}]}"#.data(using: .utf16))
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            input, importedAt: Date(timeIntervalSince1970: 5_000)
        )
        #expect(report.originalSource != nil)
        #expect(throws: OriginalReportSourceError.unsupportedEncoding) {
            _ = try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(0)]), in: report
            )
        }
    }

    @Test
    func collectedOutputAlsoRetainsExactSource() throws {
        let input: Data = Data(#"{ "SPHardwareDataType" : [ { "value" : "\u0061" } ] }"#.utf8)
        let execution: SystemProfilerExecution = SystemProfilerExecution(
            request: SystemProfilerRequest(dataTypes: [.hardware], detailLevel: .full, timeoutSeconds: 90),
            standardOutput: input,
            standardError: "",
            startedAt: Date(timeIntervalSince1970: 5_000),
            completedAt: Date(timeIntervalSince1970: 5_001)
        )
        let report: SystemProfilerReport = try SystemProfilerParser().parse(execution)
        #expect(try originalSourceExcerpt(
            at: ProfileValueAddress(dataType: .hardware, path: [.index(0), .field("value")]), in: report
        )?.bytes == Data(#""\u0061""#.utf8))
    }

    @Test
    func sourceLookupHonorsCancellation() async throws {
        let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(
            Data(#"{"SPHardwareDataType":[{"value":1}]}"#.utf8),
            importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let lookup: Task<OriginalSourceExcerpt?, Error> = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .hardware, path: [.index(0)]), in: report
            )
        }
        do {
            _ = try await lookup.value
            Issue.record("A canceled original-source lookup returned an excerpt.")
        } catch is CancellationError {
            // Cancellation is the observable result of this test's canceled task.
        }
    }
}
