/// The result of one query.
nonisolated enum SearchState: Equatable, Sendable {
    /// The query has no terms.
    case idle
    /// Ranked by occurrences, then by reading order. Never empty.
    case matches([Match])
    /// The query has terms and no passage contains all of them. Nothing approximate replaces it.
    case noMatch

    /// The ranked matches; empty for `.idle` and `.noMatch`.
    var matches: [Match] {
        if case .matches(let matches) = self { matches } else { [] }
    }
}
