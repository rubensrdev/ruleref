import CoreGraphics
import Foundation
import Testing
@testable import RuleRef

struct SearchIndexTests {

    // MARK: Synthetic rulebook (tests may build locators by hand)

    private static let rulebookID = RulebookID(bytes: Data("synthetic rulebook".utf8))

    private static func passage(_ text: String, ordinal: Int, pageIndex: Int = 0) -> ExtractedPassage {
        ExtractedPassage(
            text: text,
            ordinal: ordinal,
            locator: .pdf(rulebookID: rulebookID, pageIndex: pageIndex, bounds: CGRect(x: 72, y: 700 - 40 * ordinal, width: 400, height: 24))
        )
    }

    private static let scenario1Texts = ["A road ends at a city.", "A road crosses a field.", "The city scores two points."]
    private static let scenario1 = scenario1Texts.enumerated().map { passage($1, ordinal: $0) }

    private static let construction = [passage("Fase de construcción", ordinal: 0)]

    private static let scenario4 = ["carta y mano", "carta, otra carta", "una carta", "mano"]
        .enumerated().map { passage($1, ordinal: $0) }

    /// The matches as (ordinal, occurrences), in result order; `nil` when the state is not `.matches`.
    private static func ranked(_ state: SearchState) -> [Ranked]? {
        guard case .matches(let matches) = state else { return nil }
        return matches.map { Ranked(ordinal: $0.passage.ordinal, occurrences: $0.occurrences) }
    }

    private struct Ranked: Equatable {
        let ordinal: Int
        let occurrences: Int
    }

    // MARK: Scenario 1

    @Test func andSemantics() {
        let state = SearchIndex(passages: Self.scenario1).search("road city")
        #expect(state == .matches([Match(passage: Self.scenario1[0], occurrences: 2)]))
    }

    // MARK: Scenario 2

    @Test(arguments: ["construccion", "CONSTRUCCIÓN", "ｃｏｎｓｔｒｕｃｃｉｏｎ"])
    func caseDiacriticsAndWidthAreFolded(query: String) {
        let state = SearchIndex(passages: Self.construction).search(query)
        #expect(state == .matches([Match(passage: Self.construction[0], occurrences: 1)]))
    }

    // MARK: Scenario 3

    @Test func termMatchesInsideAWord() {
        let state = SearchIndex(passages: Self.construction).search("constru")
        #expect(state == .matches([Match(passage: Self.construction[0], occurrences: 1)]))
    }

    // MARK: Scenario 4

    @Test func rankingByOccurrencesThenOrdinal() {
        let index = SearchIndex(passages: Self.scenario4)
        let expected = [Ranked(ordinal: 1, occurrences: 2), Ranked(ordinal: 0, occurrences: 1), Ranked(ordinal: 2, occurrences: 1)]

        let first = index.search("carta")
        #expect(Self.ranked(first) == expected)
        #expect(index.search("carta") == first)
        #expect(SearchIndex(passages: Self.scenario4.reversed()).search("carta") == first)

        #expect(Self.ranked(index.search("carta mano")) == [Ranked(ordinal: 0, occurrences: 2)])
    }

    // MARK: Scenario 5

    @Test func repeatedTermsCountOnce() {
        let index = SearchIndex(passages: Self.scenario4)
        #expect(index.search("carta carta") == index.search("carta"))
    }

    // MARK: Scenario 6

    @Test(arguments: ["", "   ", "\n\t"])
    func emptyQueryIsIdle(query: String) {
        #expect(SearchIndex(passages: Self.scenario4).search(query) == .idle)
    }

    // MARK: Scenario 7

    @Test func matchCarriesItsPassageUnchanged() {
        let passages = zip(Self.scenario1Texts.indices, [0, 0, 3]).map { ordinal, pageIndex in
            Self.passage(Self.scenario1Texts[ordinal], ordinal: ordinal, pageIndex: pageIndex)
        }

        let state = SearchIndex(passages: passages).search("city")

        guard case .matches(let matches) = state else {
            Issue.record("expected .matches, got \(state)")
            return
        }
        #expect(matches.map(\.passage) == [passages[0], passages[2]])
        #expect(matches.map(\.pageNumber) == [1, 4])
    }
}
