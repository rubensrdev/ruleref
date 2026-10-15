import Foundation
import SwiftData

struct Library {
    let context: ModelContext

    /// Every game, sorted by its folded name key. The only place the library's order is defined;
    /// `games()` and the library screen's `@Query` both use it.
    static var alphabeticalGames: FetchDescriptor<Game> {
        FetchDescriptor<Game>(sortBy: [SortDescriptor(\.nameKey, comparator: .localizedStandard, order: .forward)])
    }

    func games() throws -> [Game] {
        try context.fetch(Self.alphabeticalGames)
    }

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

    /// Imports the PDF at `url` into `game`: the file copy, the rulebook and its passages are stored together or not at all.
    /// Reading, fingerprinting and extraction run off the main actor; storing runs here, in one step.
    func importRulebook(fileAt url: URL, into game: Game, store: RulebookStore) async throws -> Rulebook {
        guard game.rulebook == nil else { throw ImportError.gameHasRulebook }

        let prepared = try await RulebookPreparer.prepare(fileAt: url)

        // The main actor may have run other work during the await.
        guard game.rulebook == nil else { throw ImportError.gameHasRulebook }

        let id = prepared.rulebookID
        do {
            try store.write(prepared.bytes, for: id)
        } catch {
            throw ImportError.storage
        }

        // No suspension point from the first insert to save(), so nothing else sees a half-built rulebook.
        let rulebook = Rulebook(rulebookID: id, pageCount: prepared.pageCount, importDate: .now)
        context.insert(rulebook)
        for extracted in prepared.passages {
            let passage = Passage(extracted)
            context.insert(passage)
            passage.rulebook = rulebook
        }
        game.rulebook = rulebook
        do {
            try context.save()
        } catch {
            context.rollback()
            try? store.removeFile(for: id)
            throw ImportError.storage
        }
        return rulebook
    }
}
