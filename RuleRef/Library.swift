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
    /// The same file is held by at most one game: in `game` it is a no-op (`.alreadyPresent`), in another game
    /// `.alreadyImported`. Reading, fingerprinting and extraction run off the main actor; storing runs here, in one step.
    func importRulebook(fileAt url: URL, into game: Game, store: RulebookStore) async throws -> ImportOutcome {
        let file = try await RulebookPreparer.fingerprint(fileAt: url)
        if let existing = try check(file.rulebookID, for: game) { return .alreadyPresent(existing) }

        let prepared = try await RulebookPreparer.prepare(file)

        // The main actor may have finished another import during the awaits. No await from here to save(),
        // so no path writes or removes the file of a rulebook another game holds.
        if let existing = try check(file.rulebookID, for: game) { return .alreadyPresent(existing) }

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
        return .imported(rulebook)
    }

    /// Imports a file handed over by the system picker, inside security-scoped access that is released
    /// on success and on error. A failed start does not stop the import (a plain file needs no access).
    func importPickedFile(at url: URL, into game: Game, store: RulebookStore) async -> Result<ImportOutcome, ImportError> {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            return .success(try await importRulebook(fileAt: url, into: game, store: store))
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            // importRulebook throws only ImportError (f08-f11); anything else is treated as a storage failure.
            return .failure(.storage)
        }
    }

    /// The stored rulebook with `id`, if any. No #Unique on `rulebookID` (SwiftData would upsert); the checks keep it unique.
    private func rulebook(withID id: RulebookID) throws -> Rulebook? {
        let hex = id.hex
        var sameID = FetchDescriptor<Rulebook>(predicate: #Predicate { $0.rulebookID == hex })
        sameID.fetchLimit = 1
        do {
            return try context.fetch(sameID).first
        } catch {
            throw ImportError.storage
        }
    }

    /// Returns the rulebook `game` already holds for `id` (the no-op), throws if the import must be refused,
    /// or returns `nil` when the import may go on. The ID check comes before the game check.
    private func check(_ id: RulebookID, for game: Game) throws -> Rulebook? {
        if let existing = try rulebook(withID: id) {
            guard let holder = existing.game else { throw ImportError.storage }
            guard holder.persistentModelID == game.persistentModelID else {
                throw ImportError.alreadyImported(gameName: holder.name)
            }
            return existing
        }
        guard game.rulebook == nil else { throw ImportError.gameHasRulebook }
        return nil
    }
}
