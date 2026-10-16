import PDFKit
import SwiftUI

/// The page viewer's content. `PageViewer` owns the document and opens it.
struct PageViewerContent: View {
    let pageNumber: Int
    let document: PageDocument
    let highlight: PageHighlight

    var body: some View {
        content
            .navigationTitle(Text("Page \(pageNumber)"))
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch document {
        case .loading:
            ProgressView()
        case .ready(let pdf) where (0..<pdf.pageCount).contains(highlight.pageIndex):
            PDFPageView(document: pdf, highlight: highlight)
        case .ready, .unavailable:
            ContentUnavailableView(
                "Page Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The rulebook file could not be opened.")
            )
        }
    }
}

#if DEBUG
#Preview("Loading") {
    NavigationStack {
        PageViewerContent(pageNumber: 1, document: .loading, highlight: PageHighlight(locator: SamplePDF.previewLocator))
    }
}

#Preview("Highlighted") {
    NavigationStack {
        PageViewerContent(
            pageNumber: 1,
            document: PDFDocument(data: SamplePDF.data()).map(PageDocument.ready) ?? .unavailable,
            highlight: PageHighlight(locator: SamplePDF.previewLocator)
        )
    }
}

#Preview("Unavailable") {
    NavigationStack {
        PageViewerContent(pageNumber: 1, document: .unavailable, highlight: PageHighlight(locator: SamplePDF.previewLocator))
    }
}
#endif
