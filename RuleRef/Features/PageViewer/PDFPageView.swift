import PDFKit
import SwiftUI

/// The one UIKit-backed view (ADR-004): PDFKit's `PDFView` on the highlight's page.
/// Imports SwiftUI and PDFKit only, and uses only members PDFKit declares.
struct PDFPageView: UIViewRepresentable {
    let document: PDFDocument
    let highlight: PageHighlight

    /// Adds one in-memory `.highlight` annotation with exactly the highlight's bounds to its page,
    /// and returns that page; `nil` when the document has no such page. Never writes the document.
    static func addHighlight(_ highlight: PageHighlight, to document: PDFDocument) -> PDFPage? {
        guard highlight.pageIndex >= 0, highlight.pageIndex < document.pageCount,
              let page = document.page(at: highlight.pageIndex)
        else { return nil }
        page.addAnnotation(PDFAnnotation(bounds: highlight.bounds, forType: .highlight, withProperties: nil))
        return page
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        if let page = Self.addHighlight(highlight, to: document) {
            view.go(to: highlight.bounds, on: page)
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        // A viewer shows one fixed highlight; another match pushes another viewer.
    }
}

#if DEBUG
#Preview("Page") {
    if let document = PDFDocument(data: SamplePDF.data()) {
        PDFPageView(document: document, highlight: SamplePDF.previewHighlight)
    }
}
#endif
