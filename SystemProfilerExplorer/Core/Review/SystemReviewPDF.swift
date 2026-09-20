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

    let printInfo: NSPrintInfo = NSPrintInfo()
    printInfo.paperSize = paperSize
    printInfo.leftMargin = 48
    printInfo.rightMargin = 48
    printInfo.topMargin = 48
    printInfo.bottomMargin = 48
    printInfo.horizontalPagination = .fit
    printInfo.verticalPagination = .automatic

    let data: NSMutableData = NSMutableData()
    let operation: NSPrintOperation = NSPrintOperation.pdfOperation(
        with: textView,
        inside: textView.bounds,
        to: data,
        printInfo: printInfo
    )
    operation.showsPrintPanel = false
    operation.showsProgressPanel = false

    guard operation.run() else {
        throw SystemReviewPDFError.renderingFailed
    }

    return data as Data
}
