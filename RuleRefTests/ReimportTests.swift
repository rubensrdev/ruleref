import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct ReimportTests {

    // One in-memory container and one temporary directory per test; each test removes its directory.
    private let container: ModelContainer
    private let library: Library
    private let directory: URL
    private let store: RulebookStore

    init() throws {
        container = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        library = Library(context: container.mainContext)
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = RulebookStore(baseDirectory: directory.appending(path: "Rulebooks", directoryHint: .isDirectory))
    }

    private func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Helpers

    private static func pdfA() throws -> Data {
        try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([
                ["Each player takes five tiles", "and places them face down."],
                ["The first player is the youngest."],
            ])),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Play goes clockwise around", "the table until the end."]])),
        ])
    }

    private static func pdfB() throws -> Data {
        try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["A road ends at a city", "or at a crossing."]])),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Farmers score at the end."]])),
        ])
    }

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    /// Every file in the store's base directory with its bytes; a missing directory counts as empty.
    private func storedFiles() throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: store.baseDirectory.path()) else { return [:] }
        var files: [String: Data] = [:]
        for url in try FileManager.default.contentsOfDirectory(at: store.baseDirectory, includingPropertiesForKeys: nil) {
            files[url.lastPathComponent] = try Data(contentsOf: url)
        }
        return files
    }

    /// What "nothing changed" compares: row counts, stored files and their bytes, and each game's rulebook.
    private struct Snapshot: Equatable {
        let rulebooks: Int
        let passages: Int
        let files: [String: Data]
        let rulebookOfGame: [String: PersistentIdentifier?]
    }

    private func snapshot(_ games: [Game]) throws -> Snapshot {
        var rulebookOfGame: [String: PersistentIdentifier?] = [:]
        for game in games {
            rulebookOfGame[game.name] = .some(game.rulebook?.persistentModelID)
        }
        return Snapshot(
            rulebooks: try library.context.fetchCount(FetchDescriptor<Rulebook>()),
            passages: try library.context.fetchCount(FetchDescriptor<Passage>()),
            files: try storedFiles(),
            rulebookOfGame: rulebookOfGame
        )
    }

    private func modificationDate(of url: URL) throws -> Date {
        try #require(try FileManager.default.attributesOfItem(atPath: url.path())[.modificationDate] as? Date)
    }

    /// `ImportOutcome` holds a `Rulebook` and is not `Sendable`, so a concurrent import reports this instead.
    private enum Summary: Sendable, Equatable {
        case imported(PersistentIdentifier)
        case alreadyPresent(PersistentIdentifier)
        case failed(ImportError)
    }

    /// Starts an import on the main actor in its own task; the closure captures only `Sendable` values.
    private static func startImport(
        container: ModelContainer, url: URL, store: RulebookStore, gameName: String
    ) -> Task<Summary, any Error> {
        Task { @MainActor in
            let library = Library(context: container.mainContext)
            let game = try #require(try library.context.fetch(FetchDescriptor<Game>(predicate: #Predicate { $0.name == gameName })).first)
            do {
                switch try await library.importRulebook(fileAt: url, into: game, store: store) {
                case let .imported(rulebook): return .imported(rulebook.persistentModelID)
                case let .alreadyPresent(rulebook): return .alreadyPresent(rulebook.persistentModelID)
                }
            } catch let error as ImportError {
                return .failed(error)
            }
        }
    }

    // MARK: Scenario 1

    @Test func idempotentReimportIntoTheSameGame() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        let data = try Self.pdfA()
        let id = RulebookID(bytes: data)
        let first = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: taifa, store: store).rulebook
        let locators = first.orderedPassages.map { $0.extractedPassage(rulebookID: id).locator }
        try #require(!locators.isEmpty)
        let rulebookCount = try library.context.fetchCount(FetchDescriptor<Rulebook>())
        let passageCount = try library.context.fetchCount(FetchDescriptor<Passage>())
        let importDate = first.importDate
        let storedURL = store.fileURL(for: id)
        let storedBytes = try Data(contentsOf: storedURL)
        let storedDate = try modificationDate(of: storedURL)

        let outcome = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: taifa, store: store)

        guard case let .alreadyPresent(rulebook) = outcome else {
            Issue.record("expected .alreadyPresent, got \(outcome)")
            return
        }
        #expect(rulebook.persistentModelID == first.persistentModelID)
        #expect(rulebook.orderedPassages.map { $0.extractedPassage(rulebookID: id).locator } == locators)
        #expect(try library.context.fetchCount(FetchDescriptor<Rulebook>()) == rulebookCount)
        #expect(try library.context.fetchCount(FetchDescriptor<Passage>()) == passageCount)
        #expect(rulebook.importDate == importDate)
        #expect(try storedFiles() == [storedURL.lastPathComponent: storedBytes])
        #expect(try modificationDate(of: storedURL) == storedDate)
    }

    // MARK: Scenario 2

    @Test func sameFileAnotherGame() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        let catan = try library.createGame(named: "Catan")
        let data = try Self.pdfA()
        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: taifa, store: store)
        let before = try snapshot([taifa, catan])
        let url = try writeTemporaryFile(data)

        await #expect(throws: ImportError.alreadyImported(gameName: "Taifa")) {
            _ = try await library.importRulebook(fileAt: url, into: catan, store: store)
        }

        #expect(catan.rulebook == nil)
        #expect(try snapshot([taifa, catan]) == before)
    }

    // MARK: Scenario 3

    @Test func theStoredNameIsReturned() async throws {
        defer { removeDirectory() }
        let catan = try library.createGame(named: "Catán")
        let taifa = try library.createGame(named: "Taifa")
        let data = try Self.pdfA()
        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: catan, store: store)
        let url = try writeTemporaryFile(data)

        await #expect(throws: ImportError.alreadyImported(gameName: "Catán")) {
            _ = try await library.importRulebook(fileAt: url, into: taifa, store: store)
        }
    }

    // MARK: Scenario 4

    @Test func anotherFileSameGame() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        let dataA = try Self.pdfA()
        let dataB = try Self.pdfB()
        try #require(RulebookID(bytes: dataA) != RulebookID(bytes: dataB))
        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(dataA), into: taifa, store: store)
        let before = try snapshot([taifa])
        let urlB = try writeTemporaryFile(dataB)

        await #expect(throws: ImportError.gameHasRulebook) {
            _ = try await library.importRulebook(fileAt: urlB, into: taifa, store: store)
        }

        #expect(try snapshot([taifa]) == before)
    }

    // MARK: Scenario 5

    @Test func theIDCheckComesBeforeTheGameCheck() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        let catan = try library.createGame(named: "Catan")
        let dataA = try Self.pdfA()
        let dataB = try Self.pdfB()
        try #require(RulebookID(bytes: dataA) != RulebookID(bytes: dataB))
        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(dataA), into: taifa, store: store)
        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(dataB), into: catan, store: store)
        let before = try snapshot([taifa, catan])
        let urlA = try writeTemporaryFile(dataA)

        await #expect(throws: ImportError.alreadyImported(gameName: "Taifa")) {
            _ = try await library.importRulebook(fileAt: urlA, into: catan, store: store)
        }

        #expect(try snapshot([taifa, catan]) == before)
    }

    // MARK: Scenario 6

    @Test func simultaneousImportsIntoTwoGames() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        let catan = try library.createGame(named: "Catan")
        let data = try Self.pdfA()
        let url = try writeTemporaryFile(data)

        let intoTaifa = Self.startImport(container: container, url: url, store: store, gameName: "Taifa")
        let intoCatan = Self.startImport(container: container, url: url, store: store, gameName: "Catan")
        let results = ["Taifa": try await intoTaifa.value, "Catan": try await intoCatan.value]

        let rulebooks = try library.context.fetch(FetchDescriptor<Rulebook>())
        #expect(rulebooks.count == 1)
        #expect(try storedFiles() == ["\(RulebookID(bytes: data).hex).pdf": data])
        let winners = [taifa, catan].filter { $0.rulebook != nil }
        try #require(winners.count == 1)
        let winner = winners[0]
        let loser = winner === taifa ? catan : taifa
        let rulebook = try #require(rulebooks.first)
        #expect(results[winner.name] == .imported(rulebook.persistentModelID))
        #expect(results[loser.name] == .failed(.alreadyImported(gameName: winner.name)))
        #expect(loser.rulebook == nil)
    }

    // MARK: Scenario 7

    @Test func simultaneousImportsIntoTheSameGame() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        let data = try Self.pdfA()
        let url = try writeTemporaryFile(data)

        let first = Self.startImport(container: container, url: url, store: store, gameName: "Taifa")
        let second = Self.startImport(container: container, url: url, store: store, gameName: "Taifa")
        let results = [try await first.value, try await second.value]

        let rulebooks = try library.context.fetch(FetchDescriptor<Rulebook>())
        #expect(rulebooks.count == 1)
        #expect(try storedFiles() == ["\(RulebookID(bytes: data).hex).pdf": data])
        let rulebook = try #require(rulebooks.first)
        #expect(taifa.rulebook?.persistentModelID == rulebook.persistentModelID)
        let id = rulebook.persistentModelID
        #expect(results.filter { $0 == .imported(id) }.count == 1)
        #expect(results.filter { $0 == .alreadyPresent(id) }.count == 1)
    }
}
