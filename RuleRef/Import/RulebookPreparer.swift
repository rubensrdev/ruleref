import Foundation
import PDFKit

/// The heavy parts of an import, off the main actor: fingerprinting, then opening and extraction.
nonisolated enum RulebookPreparer {
    /// Reads the bytes once and hashes them once; the library checks the ID before anything is extracted.
    @concurrent
    static func fingerprint(fileAt url: URL) async throws -> FingerprintedFile {
        let bytes: Data
        do {
            bytes = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable
        }
        return FingerprintedFile(rulebookID: RulebookID(bytes: bytes), bytes: bytes)
    }

    /// Only a `FingerprintedFile` goes in and only a `PreparedRulebook` comes out; the `PDFDocument` never leaves this function.
    @concurrent
    static func prepare(_ file: FingerprintedFile) async throws -> PreparedRulebook {
        guard let document = PDFDocument(data: file.bytes) else { throw ImportError.unreadable }
        // Only a locked document is rejected; an encrypted one that opens unlocked takes the normal path.
        if document.isLocked { throw ImportError.locked }

        let passages = PassageExtractor.extract(from: document, rulebookID: file.rulebookID)
        // No passages in the whole document means no usable text layer; pages without text alone do not reject.
        if passages.isEmpty { throw ImportError.noTextLayer }

        return PreparedRulebook(rulebookID: file.rulebookID, pageCount: document.pageCount, bytes: file.bytes, passages: passages)
    }
}
