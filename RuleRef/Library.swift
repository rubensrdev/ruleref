import Foundation
import SwiftData

struct Library {
    let context: ModelContext

    /// Creates and saves a game; throws `.blank` or `.duplicate` without inserting anything.
    @discardableResult
    func createGame(named raw: String) throws -> Game {
        let name = try GameName(raw)
        let key = name.key
        let sameKey = FetchDescriptor<Game>(predicate: #Predicate { $0.nameKey == key })
        guard try context.fetchCount(sameKey) == 0 else { throw GameNameError.duplicate }
        let game = Game(name: name)
        context.insert(game)
        try context.save()
        return game
    }
}
