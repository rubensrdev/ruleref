import Foundation

/// Folds text for matching exactly as `GameName` folds its key.
nonisolated enum SearchFolding {
    static func folded(_ text: String) -> String {
        // Same options and fixed locale as GameName.key; SearchFoldingTests pins the equality.
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
