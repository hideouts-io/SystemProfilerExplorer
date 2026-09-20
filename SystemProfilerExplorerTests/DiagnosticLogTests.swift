import Foundation
import Testing
@testable import SystemProfilerExplorer

struct DiagnosticLogTests {
    @Test
    func summarizesEvidenceWithoutAssumingMessagesOrCountingOtherProcesses() throws {
        let text: String = """
        Sep 19 15:26:50 Example[42]: AVE INFO: AVE_Session_HEVC_Create Enter
        Sep 19 15:26:51 Example[42]: 12345 2 AVE : ID: 10 | Input: 1 Proc: 1 Drop: 0
        Sep 19 15:26:52 Other[73]: unrelated message
        Sep 19 15:26:53 Another[50]: AVE INFO: AVE_Plugin_HEVC_Finalize Exit
        """
        let summary: DiagnosticLogSummary = try summarizeDiagnosticLog(text)
        #expect(summary.aveLineCount == 3)
        #expect(summary.singleInputSummaryCount == 1)
        #expect(summary.processLabels == ["Another[50]", "Example[42]"])
        #expect(!summary.isPartial)
        #expect(try diagnosticLogPages(text).joined() == text)
    }

    @Test
    func retainsLargeUnicodeEvidenceWhileExplicitlyLimitingAnalysis() throws {
        let text: String = String(repeating: "🙂 unrecognized log\n", count: 120_000)
        let summary: DiagnosticLogSummary = try summarizeDiagnosticLog(text)
        let pages: [String] = try diagnosticLogPages(text)
        #expect(summary.isPartial)
        #expect(summary.aveLineCount == 0)
        #expect(pages.joined() == text)
        #expect(pages.allSatisfy { $0.count <= 12_000 })
        #expect(try diagnosticLogPages("").isEmpty)
    }

    @Test
    func routesLogFieldsWithoutChangingRawEvidenceOrOtherContents() {
        let text: String = "AVE_Session_HEVC_Create\n  original_spacing"
        let log: FieldPresentation = fieldPresentation(dataType: .syncServices, path: ["_items", "[]", "contents"], scalar: .string(text))
        let other: FieldPresentation = fieldPresentation(dataType: .hardware, path: ["contents"], scalar: .string(text))
        #expect(log.isLogContent)
        #expect(log.rawValue == text)
        #expect(log.displayedValue == text)
        #expect(!other.isLogContent)
        #expect(friendlyReportGroupName("system.log") == "system.log")
    }
}
