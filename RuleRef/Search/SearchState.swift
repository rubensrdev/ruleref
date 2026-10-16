/// The result of one query. The no-match state arrives with f14; until then zero matches is `.matches([])`.
nonisolated enum SearchState: Equatable, Sendable {
    /// The query has no terms.
    case idle
    /// Ranked by occurrences, then by reading order.
    case matches([Match])
}
