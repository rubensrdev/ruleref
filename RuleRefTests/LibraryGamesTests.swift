import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct LibraryGamesTests {

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

    // Scenario 1
    @Test func alphabeticalOrder() throws {
        try library.createGame(named: "Zombicide")
        try library.createGame(named: "azul")
        try library.createGame(named: "Ábaco")

        #expect(try library.games().map(\.name) == ["Ábaco", "azul", "Zombicide"])
    }

    // Scenario 2
    @Test func emptyLibrary() throws {
        #expect(try library.games().isEmpty)
    }

    // Scenario 3
    @Test func orderAfterCreating() throws {
        try library.createGame(named: "Zombicide")
        try library.createGame(named: "azul")
        #expect(try library.games().map(\.name) == ["azul", "Zombicide"])

        try library.createGame(named: "Catán")

        #expect(try library.games().map(\.name) == ["azul", "Catán", "Zombicide"])
    }

}
