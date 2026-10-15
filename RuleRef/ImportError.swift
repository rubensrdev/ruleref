/// Why an import failed. Every case leaves no persisted rows and no stored file.
nonisolated enum ImportError: Error, Equatable, Sendable {
    /// The file could not be read, or its bytes are not a PDF.
    case unreadable
    /// Writing the file copy or saving the rulebook failed; everything was rolled back.
    case storage
    /// The game already has a rulebook; nothing was read.
    case gameHasRulebook
}
