import Foundation
import PDFKit

/// The heavy part of an import: read, fingerprint and extract, off the main actor.
nonisolated enum RulebookPreparer {
    /// Only a `URL` goes in and only a `PreparedRulebook` comes out; the `PDFDocument` never leaves this function.
    @concurrent
    static func prepare(fileAt url: URL) async throws -> PreparedRulebook {
        let bytes: Data
        do {
            bytes = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable
        }

        // Fingerprinting: the bytes are read and hashed once.
        let rulebookID = RulebookID(bytes: bytes)
        // f11 plugs in here: same ID in this game → duplicateNoOp, in another game → .alreadyImported.

        guard let document = PDFDocument(data: bytes) else { throw ImportError.unreadable }
        // Only a locked document is rejected; an encrypted one that opens unlocked takes the normal path.
        if document.isLocked { throw ImportError.locked }

        let passages = PassageExtractor.extract(from: document, rulebookID: rulebookID)
        // No passages in the whole document means no usable text layer; pages without text alone do not reject.
        if passages.isEmpty { throw ImportError.noTextLayer }

        return PreparedRulebook(rulebookID: rulebookID, pageCount: document.pageCount, bytes: bytes, passages: passages)
    }
}
