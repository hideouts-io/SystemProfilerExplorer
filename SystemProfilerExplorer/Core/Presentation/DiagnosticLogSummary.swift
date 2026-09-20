import Foundation

struct DiagnosticLogSummary: Sendable, Equatable {
    let inspectedLineCount: Int
    let isPartial: Bool
    let aveLineCount: Int
    let singleInputSummaryCount: Int
    let processLabels: [String]
}

func friendlyReportGroupName(_ name: String) -> String {
    switch name {
    case "log_tree_name", "summary_tree_name": displayName(for: name)
    default: name
    }
}

func summarizeDiagnosticLog(_ rawText: String) throws -> DiagnosticLogSummary {
    // Bound analysis, not evidence retention. A partial final line is not counted.
    let prefix: Substring = rawText.prefix(2_000_000)
    let isPartial: Bool = prefix.endIndex != rawText.endIndex
    let inspectedText: Substring = isPartial
        ? prefix[..<(prefix.lastIndex(of: "\n") ?? prefix.startIndex)] : prefix
    let lines: [Substring] = inspectedText.split(separator: "\n")
    let processPattern: NSRegularExpression = try NSRegularExpression(
        pattern: #"(?:^|\s)([^\s\[\]]+\[\d+\]):"#
    )
    var aveLineCount: Int = 0
    var singleInputSummaryCount: Int = 0
    var processLabels: Set<String> = []

    for (index, line) in lines.enumerated() {
        if index.isMultiple(of: 256) { try Task.checkCancellation() }
        guard (line.contains("AVE INFO:") && (line.contains("AVE_Session_HEVC_") || line.contains("AVE_Plugin_HEVC_")))
                || line.contains(" AVE :") else {
            continue
        }
        aveLineCount += 1
        if line.contains("Input: 1 Proc: 1 Drop: 0") {
            singleInputSummaryCount += 1
        }
        let text: String = String(line)
        if let match = processPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            processLabels.insert(String(text[range]))
        }
    }
    return DiagnosticLogSummary(
        inspectedLineCount: lines.count,
        isPartial: isPartial,
        aveLineCount: aveLineCount,
        singleInputSummaryCount: singleInputSummaryCount,
        processLabels: processLabels.sorted()
    )
}

func diagnosticLogPages(_ text: String) throws -> [String] {
    var pages: [String] = []
    var start: String.Index = text.startIndex
    while start < text.endIndex {
        try Task.checkCancellation()
        let end: String.Index = text.index(start, offsetBy: 12_000, limitedBy: text.endIndex) ?? text.endIndex
        pages.append(String(text[start..<end]))
        start = end
    }
    return pages
}
