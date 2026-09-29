import Foundation

struct DiagnosticLogSummary: Sendable, Equatable {
    let inspectedLineCount: Int
    let isPartial: Bool
    /// The first and last timestamps in the analyzed text, as written in the log.
    let firstTimestamp: String?
    let lastTimestamp: String?
    /// The processes that wrote the most lines, most first.
    let busiestProcesses: [LogProcessLineCount]
    /// Lines that contain "error" or "fail" in any letter case.
    let errorMentionCount: Int
    let aveLineCount: Int
    let singleInputSummaryCount: Int
    let processLabels: [String]
}

struct LogProcessLineCount: Sendable, Equatable {
    let name: String
    let lineCount: Int
}

private let busiestProcessLimit: Int = 5

func summarizeDiagnosticLog(_ rawText: String) throws -> DiagnosticLogSummary {
    // Bound analysis, not evidence retention. A partial final line is not counted.
    let prefix: Substring = rawText.prefix(2_000_000)
    let isPartial: Bool = prefix.endIndex != rawText.endIndex
    let inspectedText: Substring = isPartial
        ? prefix[..<(prefix.lastIndex(of: "\n") ?? prefix.startIndex)] : prefix
    let lines: [Substring] = inspectedText.split(separator: "\n")
    let processPattern: NSRegularExpression = try NSRegularExpression(
        pattern: #"(?:^|\s)(([^\s\[\]]+)\[\d+\]):"#
    )
    // Classic syslog ("Sep 19 15:26:50") and ISO-style ("2026-09-19 15:26:50") line starts.
    let timestampPattern: NSRegularExpression = try NSRegularExpression(
        pattern: #"^([A-Z][a-z]{2} +\d{1,2} \d{2}:\d{2}:\d{2}|\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})"#
    )
    var firstTimestamp: String?
    var lastTimestamp: String?
    var linesByProcess: [String: Int] = [:]
    var errorMentionCount: Int = 0
    var aveLineCount: Int = 0
    var singleInputSummaryCount: Int = 0
    var processLabels: Set<String> = []

    for (index, line) in lines.enumerated() {
        if index.isMultiple(of: 256) { try Task.checkCancellation() }
        let text: String = String(line)
        let range: NSRange = NSRange(text.startIndex..., in: text)
        let processMatch: NSTextCheckingResult? = processPattern.firstMatch(in: text, range: range)

        if let match = timestampPattern.firstMatch(in: text, range: range),
           let timestampRange = Range(match.range(at: 1), in: text) {
            let timestamp: String = String(text[timestampRange])
            firstTimestamp = firstTimestamp ?? timestamp
            lastTimestamp = timestamp
        }

        if let processMatch, let nameRange = Range(processMatch.range(at: 2), in: text) {
            linesByProcess[String(text[nameRange]), default: 0] += 1
        }

        if line.range(of: "error", options: .caseInsensitive) != nil
            || line.range(of: "fail", options: .caseInsensitive) != nil {
            errorMentionCount += 1
        }

        guard (line.contains("AVE INFO:") && (line.contains("AVE_Session_HEVC_") || line.contains("AVE_Plugin_HEVC_")))
                || line.contains(" AVE :") else {
            continue
        }
        aveLineCount += 1
        if line.contains("Input: 1 Proc: 1 Drop: 0") {
            singleInputSummaryCount += 1
        }
        if let processMatch, let labelRange = Range(processMatch.range(at: 1), in: text) {
            processLabels.insert(String(text[labelRange]))
        }
    }

    let busiestProcesses: [LogProcessLineCount] = linesByProcess
        .map { LogProcessLineCount(name: $0.key, lineCount: $0.value) }
        .sorted { $0.lineCount != $1.lineCount ? $0.lineCount > $1.lineCount : $0.name < $1.name }
        .prefix(busiestProcessLimit)
        .map { $0 }

    return DiagnosticLogSummary(
        inspectedLineCount: lines.count,
        isPartial: isPartial,
        firstTimestamp: firstTimestamp,
        lastTimestamp: lastTimestamp,
        busiestProcesses: busiestProcesses,
        errorMentionCount: errorMentionCount,
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
