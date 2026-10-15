import Foundation
import PDFKit

/// Turns an opened PDF into ordered passages. Pure and synchronous; runs on the caller's isolation.
/// `PDFDocument` is not `Sendable`, so a caller must not share one document across isolation domains.
nonisolated enum PassageExtractor {
    static func lines(on page: PDFPage) -> [PageLine] {
        let count = page.numberOfCharacters
        // selection(for:) raises an exception for a zero-length range.
        guard count > 0, let selection = page.selection(for: NSRange(location: 0, length: count)) else {
            return []
        }
        return selection.selectionsByLine().map { line in
            var text = line.string ?? ""
            while let last = text.unicodeScalars.last, CharacterSet.newlines.contains(last) {
                text.unicodeScalars.removeLast()
            }
            return PageLine(text: text, bounds: line.bounds(for: page))
        }
    }

    static func extract(from document: PDFDocument, rulebookID: RulebookID) -> [ExtractedPassage] {
        var passages: [ExtractedPassage] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let segments = PassageSegmenter.segments(of: lines(on: page), pageBounds: page.bounds(for: .cropBox))
            for segment in segments {
                let locator = Locator.pdf(rulebookID: rulebookID, pageIndex: pageIndex, bounds: segment.bounds)
                passages.append(ExtractedPassage(text: segment.text, ordinal: passages.count, locator: locator))
            }
        }
        return passages
    }
}
