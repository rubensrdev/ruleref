import Foundation
import SwiftData

@Model
final class Game {
    var name: String
    // Folded name; folding is unavailable in #Predicate, so it is stored. No #Unique: SwiftData would upsert.
    var nameKey: String
    @Relationship(deleteRule: .cascade, inverse: \Rulebook.game)
    var rulebook: Rulebook?

    init(name: GameName) {
        self.name = name.value
        self.nameKey = name.key
    }
}
