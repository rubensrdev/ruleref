import PDFKit
import SwiftUI

/// The page viewer: opens the stored rulebook when it appears; `PageViewerContent` shows it.
struct PageViewer: View {
    let highlight: PageHighlight
    let pageNumber: Int
    let store: RulebookStore

    @State private var document: PageDocument = .loading

    // Stores values only: a NavigationLink may build its destination with every row,
    // so opening the file here would read it once per row on every render.
    init(highlight: PageHighlight, pageNumber: Int, store: RulebookStore = .app) {
        self.highlight = highlight
        self.pageNumber = pageNumber
        self.store = store
    }

    var body: some View {
        PageViewerContent(pageNumber: pageNumber, document: document, highlight: highlight)
            .task {
                // Once: the document keeps its in-memory highlight while the viewer exists.
                guard case .loading = document else { return }
                document = Self.openDocument(for: highlight.rulebookID, store: store).map(PageDocument.ready) ?? .unavailable
            }
    }

    /// The viewer's own copy of the stored file, read only; `nil` when it cannot be opened.
    static func openDocument(for id: RulebookID, store: RulebookStore) -> PDFDocument? {
        PDFDocument(url: store.fileURL(for: id))
    }
}

#if DEBUG
#Preview("Missing File") {
    NavigationStack {
        PageViewer(
            highlight: SamplePDF.previewHighlight,
            pageNumber: 1,
            // A unique temporary directory that holds no file.
            store: RulebookStore(baseDirectory: URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        )
    }
}
#endif
