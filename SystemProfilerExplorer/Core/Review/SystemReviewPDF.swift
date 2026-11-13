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
    let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 3
    let text: NSTextStorage = NSTextStorage(
        string: markdown,
        attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
    )
    let layout: NSLayoutManager = NSLayoutManager()
    text.addLayoutManager(layout)
    let data: NSMutableData = NSMutableData()
    var pageBounds: CGRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard text.length > 0,
          let consumer: CGDataConsumer = CGDataConsumer(data: data),
          let context: CGContext = CGContext(consumer: consumer, mediaBox: &pageBounds, nil) else {
        throw SystemReviewPDFError.renderingFailed
    }
    let textBounds: CGRect = pageBounds.insetBy(dx: 60, dy: 60)
    let glyphCount: Int = layout.numberOfGlyphs
    var offset: Int = 0
    while offset < glyphCount {
        let container: NSTextContainer = NSTextContainer(size: textBounds.size)
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        let range: NSRange = layout.glyphRange(for: container)
        guard range.location == offset, range.length > 0 else {
            context.closePDF()
            throw SystemReviewPDFError.renderingFailed
        }
        // Cocoa layout preserves complex glyph shaping without opting into
        // unbounded Core Text layout. Draw only this page's fitted glyphs:
        // clipping an entire text view repeats hidden boundary text in the PDF.
        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: textBounds.minX, y: textBounds.maxY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        layout.enumerateLineFragments(forGlyphRange: range) { rect, _, _, lineRange, _ in
            let drawRange: NSRange = NSIntersectionRange(lineRange, range)
            let firstGlyph: CGPoint = layout.location(forGlyphAt: drawRange.location)
            let baseline: CGPoint = CGPoint(x: rect.minX + firstGlyph.x, y: rect.minY + firstGlyph.y)
            // Keep the local baseline at zero in an unflipped context. AppKit's
            // color-emoji PDF text layer otherwise applies its position twice,
            // disrupting selectable-text order even when the image looks right.
            context.saveGState()
            context.translateBy(x: baseline.x, y: -baseline.y)
            layout.drawGlyphs(forGlyphRange: drawRange, at: CGPoint(x: -baseline.x, y: -baseline.y))
            context.restoreGState()
        }
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
        context.endPDFPage()
        offset = NSMaxRange(range)
    }

    context.closePDF()
    return data as Data
}
