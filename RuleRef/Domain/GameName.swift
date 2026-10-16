import Foundation

/// A validated game name: trimmed and non-blank, with a folded key for uniqueness.
nonisolated struct GameName: Sendable, Equatable {
    let value: String
    let key: String

    init(_ raw: String) throws(GameNameError) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .blank }
        value = trimmed
        // Fixed locale keeps the key deterministic; case folding varies by locale.
        key = trimmed.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
