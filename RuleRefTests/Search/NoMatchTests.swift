import CoreGraphics
import Foundation
import Testing
@testable import RuleRef

struct NoMatchTests {

    // MARK: Synthetic rulebook: the passages of SearchIndexTests' scenario 1

    private static let rulebookID = RulebookID(bytes: Data("synthetic rulebook".utf8))

    private static let passages = ["A road ends at a city.", "A road crosses a field.", "The city scores two points."]
        .enumerated()
        .map { ordinal, text in
            ExtractedPassage(
                text: text,
                ordinal: ordinal,
                locator: .pdf(rulebookID: rulebookID, pageIndex: 0, bounds: CGRect(x: 72, y: 700 - 40 * ordinal, width: 400, height: 24))
            )
        }

    private static let index = SearchIndex(passages: passages)

    // MARK: Scenario 1

    @Test func anAbsentTerm() {
        let state = Self.index.search("dragon")
        #expect(state == .noMatch)
        #expect(state.matches.isEmpty)
    }

    // MARK: Scenario 2

    @Test func oneTermPresentOneAbsent() {
        let state = Self.index.search("road dragon")
        #expect(state == .noMatch)
        #expect(state.matches.isEmpty)
    }

    // MARK: Scenario 3

    @Test(arguments: ["roads", "citty"])
    func noApproximateMatching(query: String) {
        let state = Self.index.search(query)
        #expect(state == .noMatch)
        #expect(state.matches.isEmpty)
    }

    // MARK: Scenario 4

    @Test func idleAndMatchesAreUnchanged() {
        let idle = Self.index.search("   ")
        #expect(idle == .idle)
        #expect(idle != .noMatch)
        #expect(idle.matches.isEmpty)

        let road = Self.index.search("road")
        #expect(road == .matches([
            Match(passage: Self.passages[0], occurrences: 1),
            Match(passage: Self.passages[1], occurrences: 1),
        ]))
        #expect(road.matches.map(\.passage.ordinal) == [0, 1])
    }
}
