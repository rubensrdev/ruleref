import Foundation
import Testing
@testable import RuleRef

struct SearchFoldingTests {

    @Test(arguments: ["  Catán ", "ＣＡＴＡＮ", "catan"])
    func foldingMatchesGameNameKey(raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(SearchFolding.folded(trimmed) == (try GameName(raw).key))
    }
}
