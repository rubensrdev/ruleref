/// A passage as extraction produces it, before it is persisted.
nonisolated struct ExtractedPassage: Equatable, Sendable {
    let text: String
    let ordinal: Int
    let locator: Locator
}
