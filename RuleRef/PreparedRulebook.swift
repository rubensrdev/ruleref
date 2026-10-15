import Foundation

/// Everything an import stores, computed off the main actor and handed back as one `Sendable` value.
nonisolated struct PreparedRulebook: Sendable {
    let rulebookID: RulebookID
    let pageCount: Int
    let bytes: Data
    let passages: [ExtractedPassage]
}
