/// A passage returned by a query, with how many times the query's terms occur in it.
nonisolated struct Match: Equatable, Sendable, Identifiable {
    let passage: ExtractedPassage
    let occurrences: Int

    var id: Int { passage.ordinal }

    /// The 1-based page number shown to the user.
    var pageNumber: Int {
        switch passage.locator {
        case let .pdf(_, pageIndex, _):
            pageIndex + 1
        }
    }
}
