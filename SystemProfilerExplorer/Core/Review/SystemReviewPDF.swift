import AppKit
import Foundation

enum SystemReviewPDFError: LocalizedError, Equatable {
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            "The system review summary could not be rendered as a PDF."
        }
    }
}

@MainActor
func makeSystemReviewPDF(markdown: String) throws -> Data {
    let paperSize: NSSize = NSSize(width: 612, height: 792)
    let printableWidth: CGFloat = paperSize.width - 96
    let textView: NSTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: printableWidth, height: paperSize.height - 96))
    let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 3
    textView.textStorage?.setAttributedString(
        NSAttributedString(
            string: markdown,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    )
    textView.textContainerInset = NSSize(width: 12, height: 12)
    textView.isVerticallyResizable = true
    textView.textContainer?.containerSize = NSSize(width: printableWidth, height: .greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    // Grow the view to its full text height; otherwise only the first page is printed.
    textView.maxSize = NSSize(width: printableWidth, height: .greatestFiniteMagnitude)
    textView.sizeToFit()

    let printInfo: NSPrintInfo = NSPrintInfo()
    printInfo.paperSize = paperSize
    printInfo.leftMargin = 48
    printInfo.rightMargin = 48
    printInfo.topMargin = 48
    printInfo.bottomMargin = 48
    printInfo.horizontalPagination = .fit
    printInfo.verticalPagination = .automatic

    // A saving print job paginates onto paper-sized pages; pdfOperation(with:inside:)
    // would render the whole view as a single page.
    let outputURL: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: false)
        .appendingPathExtension("pdf")
    defer {
        try? FileManager.default.removeItem(at: outputURL)
    }

    printInfo.jobDisposition = .save
    printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = outputURL

    let operation: NSPrintOperation = NSPrintOperation(view: textView, printInfo: printInfo)
    operation.showsPrintPanel = false
    operation.showsProgressPanel = false

    guard operation.run() else {
        throw SystemReviewPDFError.renderingFailed
    }

    return try Data(contentsOf: outputURL)
}
