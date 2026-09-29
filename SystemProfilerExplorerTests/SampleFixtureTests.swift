import Foundation
import Testing
@testable import SystemProfilerExplorer

/// Anonymized samples from other Macs, exported in Developer mode with Share ›
/// Anonymized Sample. They're read from the source tree next to this file; see
/// Samples/README.md for how to add one.
private let sampleDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Samples", isDirectory: true)

private func sampleURLs() throws -> [URL] {
    try FileManager.default
        .contentsOfDirectory(at: sampleDirectory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasSuffix(".sample.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private func openSample(_ url: URL) throws -> (payload: [String: [ProfileValue]], report: SystemProfilerReport) {
    let data: Data = try Data(contentsOf: url)
    let payload: [String: [ProfileValue]] = try JSONDecoder().decode([String: [ProfileValue]].self, from: data)
    let report: SystemProfilerReport = try SystemProfilerParser().parseImportedReport(data, importedAt: Date())
    return (payload, report)
}

struct SampleFixtureTests {
    @Test
    func everySampleOpensAndIndexes() throws {
        for url in try sampleURLs() {
            let report: SystemProfilerReport = try openSample(url).report
            let index: ReportPresentationIndex = try makeReportPresentationIndex(report)

            #expect(index.summary.findingCount > 0, "\(url.lastPathComponent) has no findings")
        }
    }

    /// A sample must be exactly what the export produces, so personal values can't be
    /// edited back in and every data type in it is one the app supports.
    @Test
    func samplesAreUnchangedByAnonymizing() throws {
        for url in try sampleURLs() {
            let sample = try openSample(url)

            #expect(
                makeAnonymizedSample(sample.report) == sample.payload,
                "\(url.lastPathComponent) differs from an anonymized export. Export it again with Share › Anonymized Sample."
            )
        }
    }

    /// Values of fields the app explains must all be recognized. A failure lists each
    /// new value, which needs a rule in Core/Explanations/Values.
    @Test
    func explainedFieldsRecognizeEverySampleValue() throws {
        for url in try sampleURLs() {
            let report: SystemProfilerReport = try openSample(url).report
            let context: ValueReportContext = valueReportContext(for: report)
            var unrecognized: Set<String> = []

            for section in report.sections {
                for item in section.items {
                    collectUnrecognizedValues(
                        item,
                        dataType: section.dataType,
                        path: [],
                        siblings: [:],
                        report: context,
                        into: &unrecognized
                    )
                }
            }

            #expect(unrecognized.isEmpty, "\(url.lastPathComponent): \(unrecognized.sorted().joined(separator: "; "))")
        }
    }
}

private func collectUnrecognizedValues(
    _ value: ProfileValue,
    dataType: SystemProfilerDataType,
    path: [String],
    siblings: [String: ProfileValue],
    report: ValueReportContext,
    into unrecognized: inout Set<String>
) {
    let scalar: ProfileScalar

    switch value {
    case let .object(object):
        for (key, fieldValue) in object {
            collectUnrecognizedValues(fieldValue, dataType: dataType, path: path + [key], siblings: object, report: report, into: &unrecognized)
        }
        return
    case let .array(values):
        for item in values {
            collectUnrecognizedValues(item, dataType: dataType, path: path + ["[]"], siblings: [:], report: report, into: &unrecognized)
        }
        return
    case let .string(text):
        scalar = .string(text)
    case let .integer(number):
        scalar = .integer(number)
    case let .decimal(number):
        scalar = .decimal(number)
    case let .boolean(flag):
        scalar = .boolean(flag)
    case .null:
        scalar = .null
    }

    guard scalar.rawDescription != anonymizedSampleRemovedValue,
          hasValueRule(dataType: dataType, path: path),
          valueExplanation(dataType: dataType, path: path, scalar: scalar, siblings: siblings, report: report)?.status == .unknown else {
        return
    }

    unrecognized.insert("\(dataType.rawValue).\(path.joined(separator: ".")) = \(scalar.rawDescription)")
}
