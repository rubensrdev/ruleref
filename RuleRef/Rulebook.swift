import Foundation
import SwiftData

@Model
final class Rulebook {
    /// The rulebook ID's hex; `RulebookID(hex:)` turns it back into an ID.
    var rulebookID: String
    var pageCount: Int
    var importDate: Date
    var game: Game?
    // SwiftData documents no order for to-many relationships; read through `orderedPassages`.
    @Relationship(deleteRule: .cascade, inverse: \Passage.rulebook)
    var passages: [Passage] = []

    init(rulebookID: RulebookID, pageCount: Int, importDate: Date) {
        self.rulebookID = rulebookID.hex
        self.pageCount = pageCount
        self.importDate = importDate
    }

    /// The passages in reading order; the only order to read them in.
    var orderedPassages: [Passage] {
        passages.sorted { $0.ordinal < $1.ordinal }
    }
}
