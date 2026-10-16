import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct LibraryTests {

    // One in-memory container per test, so tests never share a store.
    private let container: ModelContainer
    private let library: Library

    init() throws {
        container = try ModelContainer(
            for: Game.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        library = Library(context: container.mainContext)
    }

    // Counts saved games and, through the library's own context, unsaved inserts too;
    // both must agree, so an insert left behind by a throwing call is caught.
    private func gameCount() throws -> Int {
        let saved = try ModelContext(container).fetchCount(FetchDescriptor<Game>())
        let savedAndPending = try library.context.fetchCount(FetchDescriptor<Game>())
        #expect(savedAndPending == saved)
        return savedAndPending
    }

    // Scenario 1
    @Test(arguments: ["", "   "])
    func blankNameIsRejected(raw: String) throws {
        #expect(throws: GameNameError.blank) {
            try library.createGame(named: raw)
        }
        #expect(try gameCount() == 0)
    }

    // Scenario 2
    @Test func surroundingSpacesAndCaseDoNotMakeANewName() throws {
        try library.createGame(named: "Taifa")
        #expect(throws: GameNameError.duplicate) {
            try library.createGame(named: " taifa ")
        }
        #expect(try gameCount() == 1)
    }

    // Scenario 3
    @Test func diacriticsDoNotMakeANewName() throws {
        try library.createGame(named: "Catán")
        #expect(throws: GameNameError.duplicate) {
            try library.createGame(named: "catan")
        }
        #expect(try gameCount() == 1)
    }

    // Scenario 4
    @Test func validNameCreatesAPersistedTrimmedGame() throws {
        let game = try library.createGame(named: "  Taifa  ")
        #expect(game.name == "Taifa")

        let fetched = try ModelContext(container).fetch(FetchDescriptor<Game>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Taifa")
        #expect(fetched.first?.nameKey == (try GameName("Taifa").key))
    }

    // Scenario 6: after a failed save, a retry must not report a duplicate and nothing may be left to autosave.
    @Test func failedSaveLeavesNothingBehind() throws {
        // A read-only store makes save() throw. It must be on disk: an in-memory store cannot open read-only.
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.store")
        _ = try ModelContainer(for: Game.self, configurations: ModelConfiguration(url: url))
        let readOnly = try ModelContainer(
            for: Game.self,
            configurations: ModelConfiguration(url: url, allowsSave: false)
        )
        let library = Library(context: readOnly.mainContext)

        // Back to back, as when the user taps Create again: no fetch in between, since a fetch hides the bug.
        let first = #expect(throws: (any Error).self) { try library.createGame(named: "Taifa") }
        let retry = #expect(throws: (any Error).self) { try library.createGame(named: "Taifa") }
        #expect(!(first is GameNameError))
        #expect(!(retry is GameNameError))
        // Both are the same save error.
        let firstError = try #require(first) as NSError
        let retryError = try #require(retry) as NSError
        #expect(retryError.domain == firstError.domain)
        #expect(retryError.code == firstError.code)

        #expect(!library.context.hasChanges)
        #expect(try library.context.fetch(FetchDescriptor<Game>()).isEmpty)
        #expect(try ModelContext(readOnly).fetchCount(FetchDescriptor<Game>()) == 0)
    }

}
