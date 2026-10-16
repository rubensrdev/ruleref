import Foundation

/// In-memory search over one rulebook's passages. Reads passages only, never the stored file.
nonisolated struct SearchIndex: Sendable {
    private struct Entry: Sendable {
        let passage: ExtractedPassage
        let folded: String
    }

    private let entries: [Entry]

    init(passages: [ExtractedPassage]) {
        entries = passages
            .sorted { $0.ordinal < $1.ordinal }
            .map { Entry(passage: $0, folded: SearchFolding.folded($0.text)) }
    }

    /// Every term must occur (AND); a term may occur inside a word.
    func search(_ query: String) -> SearchState {
        var terms: [String] = []
        for term in SearchFolding.folded(query).split(whereSeparator: \.isWhitespace).map(String.init)
        where !terms.contains(term) {
            terms.append(term)
        }
        guard !terms.isEmpty else { return .idle }

        var matches: [Match] = []
        for entry in entries {
            var total = 0
            var everyTermOccurs = true
            for term in terms {
                let count = Self.occurrences(of: term, in: entry.folded)
                if count == 0 {
                    everyTermOccurs = false
                    break
                }
                total += count
            }
            if everyTermOccurs {
                matches.append(Match(passage: entry.passage, occurrences: total))
            }
        }
        // Entries are already in ordinal order; the ordinal tie-break keeps the order explicit.
        matches.sort { lhs, rhs in
            lhs.occurrences != rhs.occurrences
                ? lhs.occurrences > rhs.occurrences
                : lhs.passage.ordinal < rhs.passage.ordinal
        }
        return .matches(matches)
    }

    /// Non-overlapping occurrences, counted left to right.
    private static func occurrences(of term: String, in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: term, options: .literal, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<text.endIndex
        }
        return count
    }
}

// On the main actor: it reads @Model objects.
@MainActor
extension SearchIndex {
    init(rulebook: Rulebook) {
        // An imported rulebook always stores a valid hex; nil would mean a corrupt store, so the index is empty.
        guard let id = RulebookID(hex: rulebook.rulebookID) else {
            self.init(passages: [])
            return
        }
        self.init(passages: rulebook.orderedPassages.map { $0.extractedPassage(rulebookID: id) })
    }
}
