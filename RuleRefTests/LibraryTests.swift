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

    private func gameCount() throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<Game>())
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

}
