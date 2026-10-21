import Darwin
import Foundation
import Testing
@testable import SystemProfilerExplorer

struct ReportFileLoadingTests {
    @Test
    func rawSystemProfilerJSONLoadsForViewingAndComparison() throws {
        let data = Data(#"{"SPSoftwareDataType":[{"_name":"os_overview","os_version":"macOS 27.0"}]}"#.utf8)
        let importedAt = Date(timeIntervalSince1970: 5_000)

        let viewable: SystemProfilerReport = try loadViewableReport(from: data, importedAt: importedAt)
        let baseline: SystemProfilerReport = try loadComparisonBaseline(from: data, importedAt: importedAt)

        #expect(viewable.sections.map(\.dataType) == [.software])
        #expect(baseline.sections == viewable.sections)
        #expect(baseline.completedAt == importedAt)
    }

    @Test
    func fullExportsLoadForViewingAndComparison() throws {
        let report: SystemProfilerReport = loadingReport()
        let data: Data = try encodeReportExport(makeFullReportExport(report))

        #expect(try loadViewableReport(from: data, importedAt: Date()) == report)
        #expect(try loadComparisonBaseline(from: data, importedAt: Date()) == report)
    }

    @Test
    func redactedExportsOpenForViewingButCannotBeCompared() throws {
        let data: Data = try encodeReportExport(makeRedactedReportExport(loadingReport()))
        let viewable: SystemProfilerReport = try loadViewableReport(from: data, importedAt: Date())

        #expect(viewable.sections.first?.items.first == .object(["os_version": .string(redactedProfileValue)]))
        #expect(viewable.originalSource != nil)
        #expect(try originalSourceExcerpt(
            at: ProfileValueAddress(dataType: .software, path: [.index(0), .field("os_version")]), in: viewable
        )?.text == "\"\(redactedProfileValue)\"")
        #expect(throws: ReportComparisonError.redactedBaseline) {
            _ = try loadComparisonBaseline(from: data, importedAt: Date())
        }
    }

    @Test
    func redactedPlaceholdersAreNotExplainedAsValues() {
        #expect(valueExplanation(dataType: .software, path: ["system_integrity"], scalar: .string(redactedProfileValue)) == nil)
    }

    @Test
    func exportFilenamesUseTheJSONExtension() {
        let date = Date(timeIntervalSince1970: 0)

        #expect(fullReportExportFilename(completedAt: date).hasSuffix(".json"))
        #expect(redactedReportExportFilename(completedAt: date).hasSuffix(".json"))
    }

    @Test
    func fullExportExcerptsUseTheEnvelopeAndOriginalSectionOrder() throws {
        let prefix: String = originalExportPrefix()
        let record: String = #"{ "os_version" : "macOS\u002027.0", "literal.[0]" : [ 1, 2 ] }"#
        let input: Data = Data((prefix + record + originalExportSuffix()).utf8)
        let viewable: SystemProfilerReport = try loadViewableReport(
            from: input, importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let baseline: SystemProfilerReport = try loadComparisonBaseline(
            from: input, importedAt: Date(timeIntervalSince1970: 5_000)
        )
        #expect(viewable == baseline)
        #expect(viewable.sections.map(\.dataType) == [.power, .software])
        let address: ProfileValueAddress = ProfileValueAddress(dataType: .software, path: [.index(0)])
        for report in [viewable, baseline] {
            let excerpt: OriginalSourceExcerpt = try #require(try originalSourceExcerpt(at: address, in: report))
            #expect(excerpt.bytes == Data(record.utf8))
            #expect(excerpt.text == record)
            #expect(excerpt.byteRange == prefix.utf8.count..<(prefix.utf8.count + record.utf8.count))
            #expect(input.subdata(in: excerpt.byteRange) == excerpt.bytes)
            #expect(try originalSourceExcerpt(
                at: ProfileValueAddress(dataType: .software, path: [.index(0), .field("literal.[0]"), .index(1)]),
                in: report
            )?.text == "2")
        }
    }

    @Test
    func sourceBytesNeverEnterStoredExportsOrSnapshots() throws {
        let captured: SystemProfilerReport = try loadViewableReport(
            from: Data(#"{ "SPSoftwareDataType" : [ { "os_version" : "macOS\u002027.0" } ] }"#.utf8),
            importedAt: Date(timeIntervalSince1970: 5_000)
        )
        let stored: ReportExportEnvelope = makeFullReportExport(captured)
        let reopened: SystemProfilerReport = try comparisonBaselineReport(from: stored)
        let address: ProfileValueAddress = ProfileValueAddress(dataType: .software, path: [.index(0)])

        #expect(captured.originalSource != nil)
        #expect(reopened.originalSource == nil)
        #expect(captured == reopened)
        #expect(try originalSourceExcerpt(at: address, in: reopened) == nil)
        #expect(try encodeReportExport(makeFullReportExport(reopened)) == encodeReportExport(stored))
        #expect(try encodeReportExport(makeRedactedReportExport(reopened)) == encodeReportExport(makeRedactedReportExport(captured)))

        let snapshot: SystemProfilerSnapshot = SystemProfilerSnapshot(
            id: UUID(), name: "Synthetic source retention", createdAt: Date(timeIntervalSince1970: 5_000),
            privacy: .full, report: stored
        )
        let snapshotBytes: Data = try encodeSnapshot(snapshot)
        let restoredSnapshot: SystemProfilerSnapshot = try decodeSnapshot(snapshotBytes)
        let restored: SystemProfilerReport = try comparisonBaselineReport(from: restoredSnapshot.report)
        #expect(restored == captured)
        #expect(try originalSourceExcerpt(at: address, in: restored) == nil)
        let sourceLessSnapshot: SystemProfilerSnapshot = SystemProfilerSnapshot(
            id: snapshot.id, name: snapshot.name, createdAt: snapshot.createdAt,
            privacy: snapshot.privacy, report: makeFullReportExport(reopened)
        )
        #expect(try encodeSnapshot(sourceLessSnapshot) == snapshotBytes)

        let exportedInput: Data = try encodeReportExport(stored)
        let reimported: SystemProfilerReport = try loadViewableReport(from: exportedInput, importedAt: Date())
        #expect(reimported == captured)
        #expect(try #require(reimported.originalSource).id != #require(captured.originalSource).id)
        let reimportedExcerpt: OriginalSourceExcerpt = try #require(try originalSourceExcerpt(at: address, in: reimported))
        #expect(exportedInput.subdata(in: reimportedExcerpt.byteRange) == reimportedExcerpt.bytes)
    }

    @Test
    func retainedSourceSurvivesInPlaceChangesToMappedRawAndExportFiles() throws {
        let raw: String = #"{"SPSoftwareDataType":[{"os_version":"before"}]}"#
        let exported: String = originalExportPrefix() + #"{ "os_version" : "before" }"# + originalExportSuffix()
        let directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            for (index, json) in [raw, exported].enumerated() {
                let url: URL = directory.appendingPathComponent("synthetic-\(index).json")
                let input: Data = Data((json + String(repeating: " ", count: 32_768)).utf8)
                try input.write(to: url)
                // Foundation's mapping options may still produce an independent
                // copy. MAP_SHARED plus bytesNoCopy creates a real mutable alias.
                let descriptor: Int32 = Darwin.open(url.path, O_RDONLY)
                try #require(descriptor >= 0, "Opening the synthetic source mapping failed: errno \(errno).")
                defer { #expect(Darwin.close(descriptor) == 0) }
                let mapping: UnsafeMutableRawPointer? = Darwin.mmap(nil, input.count, PROT_READ, MAP_SHARED, descriptor, 0)
                let storage: UnsafeMutableRawPointer = try #require(mapping)
                try #require(storage != MAP_FAILED, "Mapping the synthetic source failed: errno \(errno).")
                defer { #expect(Darwin.munmap(storage, input.count) == 0) }
                let mapped: Data = Data(bytesNoCopy: storage, count: input.count, deallocator: .none)
                let viewable: SystemProfilerReport = try loadViewableReport(from: mapped, importedAt: Date())
                let baseline: SystemProfilerReport = try loadComparisonBaseline(from: mapped, importedAt: Date())
                let replacement: Data = Data((json.replacingOccurrences(of: "before", with: "after!") + String(repeating: " ", count: 32_768)).utf8)
                let handle: FileHandle = try FileHandle(forWritingTo: url)
                do {
                    try handle.write(contentsOf: replacement)
                    try handle.synchronize()
                } catch {
                    try handle.close()
                    throw error
                }
                try handle.close()
                #expect(try Data(contentsOf: url) == replacement)
                #expect(mapped == replacement)
                for report in [viewable, baseline] {
                    let excerpt: OriginalSourceExcerpt = try #require(try originalSourceExcerpt(
                        at: ProfileValueAddress(dataType: .software, path: [.index(0), .field("os_version")]), in: report
                    ))
                    #expect(excerpt.bytes == Data(#""before""#.utf8))
                    #expect(input.subdata(in: excerpt.byteRange) == excerpt.bytes)
                }
            }
        } catch {
            try FileManager.default.removeItem(at: directory)
            throw error
        }
        try FileManager.default.removeItem(at: directory)
    }
}

private func originalExportPrefix() -> String {
    #"""
    { "formatIdentifier" : "com.netctl.system-profiler-explorer.report", "formatVersion" : 1,
      "privacy" : "full", "summary" : { "recordCount" : 1, "findingCount" : 2,
      "explainedFindingCount" : 0, "privacyFindingCount" : 0 }, "redactedValueCount" : 0,
      "report" : { "sections" : [ { "dataType" : "SPPowerDataType", "items" : [] },
      { "dataType" : "SPSoftwareDataType", "items" : [
    """#
}

private func originalExportSuffix() -> String {
    #"""
      ] } ], "commandArguments" : [], "standardError" : "",
      "startedAt" : "1970-01-01T00:16:40Z", "completedAt" : "1970-01-01T00:16:41Z" } }
    """#
}

private func loadingReport() -> SystemProfilerReport {
    SystemProfilerReport(
        sections: [
            SystemProfilerSection(dataType: .software, items: [.object(["os_version": .string("macOS 27.0")])])
        ],
        commandArguments: ["-json", "SPSoftwareDataType"],
        standardError: "",
        startedAt: Date(timeIntervalSince1970: 1_000),
        completedAt: Date(timeIntervalSince1970: 1_001)
    )
}
