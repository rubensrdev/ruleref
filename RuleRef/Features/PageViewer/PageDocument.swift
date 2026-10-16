import PDFKit

/// The page viewer's document. On the main actor: `PDFDocument` is not `Sendable`.
enum PageDocument {
    case loading
    case ready(PDFDocument)
    case unavailable
}
