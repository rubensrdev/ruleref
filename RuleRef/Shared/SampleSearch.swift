#if DEBUG
import CoreGraphics
import Foundation

/// Sample data for search previews: invented passages, never rulebook text.
/// Preview data is the second exception to "only extraction builds locators" (docs/domain-model.md).
enum SampleSearch {
    static let query = "road"

    private static let rulebookID = RulebookID(bytes: Data("sample rulebook".utf8))

    static let passages: [ExtractedPassage] = [
        passage(
            "A road ends at a city, at a crossing or at another road. A road that loops back on itself is complete as soon as the loop closes.",
            ordinal: 4, pageIndex: 1
        ),
        passage(
            "Each player draws one tile and places it so that every edge continues the edges it touches: a road meets a road, a field meets a field.",
            ordinal: 9, pageIndex: 2
        ),
        passage(
            "When a road is complete, the player with the most travellers on it scores one point for each tile it crosses.",
            ordinal: 15, pageIndex: 4
        ),
    ]

    /// The matches for `query` over `passages`, ranked.
    static let matches: [Match] = [
        Match(passage: passages[0], occurrences: 3),
        Match(passage: passages[1], occurrences: 2),
        Match(passage: passages[2], occurrences: 1),
    ]

    private static func passage(_ text: String, ordinal: Int, pageIndex: Int) -> ExtractedPassage {
        ExtractedPassage(
            text: text,
            ordinal: ordinal,
            locator: .pdf(rulebookID: rulebookID, pageIndex: pageIndex, bounds: CGRect(x: 72, y: 400, width: 468, height: 60))
        )
    }
}
#endif
