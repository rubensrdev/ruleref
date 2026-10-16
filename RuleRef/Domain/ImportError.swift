/// Why an import failed. Every case leaves no persisted rows and no stored file.
nonisolated enum ImportError: Error, Equatable, Sendable {
    /// The file could not be read, or its bytes are not a PDF.
    case unreadable
    /// The PDF opened but is locked: it needs a password; nothing was written.
    case locked
    /// Writing the file copy or saving the rulebook failed; everything was rolled back.
    case storage
    /// The game already has another rulebook; nothing was extracted or written.
    case gameHasRulebook
    /// Another game already holds this file; `gameName` is that game's stored name.
    case alreadyImported(gameName: String)
    /// Extraction found no passages in the whole document; nothing was written.
    case noTextLayer
}
