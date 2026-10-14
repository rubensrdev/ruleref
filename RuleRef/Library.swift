import Foundation
import SwiftData

struct Library {
    let context: ModelContext

    /// Creates and saves a game; throws `.blank` or `.duplicate` without inserting anything.
    /// If saving fails, the insert is undone before rethrowing, so nothing is left to count as a duplicate or to autosave.
    @discardableResult
    func createGame(named raw: String) throws -> Game {
        let name = try GameName(raw)
        let key = name.key
        var sameKey = FetchDescriptor<Game>(predicate: #Predicate { $0.nameKey == key })
        sameKey.fetchLimit = 1
        // fetch, not fetchCount: right after a failed save and rollback, fetchCount returns a stale 1.
        guard try context.fetch(sameKey).isEmpty else { throw GameNameError.duplicate }
        let game = Game(name: name)
        context.insert(game)
        do {
            try context.save()
        } catch {
            // delete(game) would leave the model pending; rollback() discards it. The failed save was
            // all-or-nothing, so this returns the context to what the store holds.
            context.rollback()
            throw error
        }
        return game
    }
}
