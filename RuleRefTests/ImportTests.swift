import Foundation
import PDFKit
import SwiftData
import Testing
@testable import RuleRef

struct ImportTests {

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

    private static let paragraphsA = [
        ["Each player takes five tiles", "and places them face down."],
        ["The first player is the youngest."],
    ]

    private static func twoPagePDF(_ first: [[String]], _ second: [[String]]) throws -> Data {
        try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs(first)),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs(second)),
        ])
    }

    private static func pdfA() throws -> Data {
        try twoPagePDF(paragraphsA, [["Play goes clockwise around", "the table until the end."]])
    }

    private static func pdfB() throws -> Data {
        try twoPagePDF([["A road ends at a city", "or at a crossing."]], [["Farmers score at the end."]])
    }

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    private struct RowCounts: Equatable {
        let rulebooks: Int
        let passages: Int
        static let empty = RowCounts(rulebooks: 0, passages: 0)
    }

    // fetch, not fetchCount: right after a failed save and rollback, fetchCount returns a stale count (f02).
    private func rowCounts(in context: ModelContext) throws -> RowCounts {
        RowCounts(
            rulebooks: try context.fetch(FetchDescriptor<Rulebook>()).count,
            passages: try context.fetch(FetchDescriptor<Passage>()).count
        )
    }

    /// Names of every file with the `pdf` extension anywhere under `root`.
    private func pdfFileNames(under root: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var names: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "pdf" {
            names.append(url.lastPathComponent)
        }
        return names
    }

    private func storedFiles() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: store.baseDirectory.path())) ?? []
    }

    // MARK: Scenario 1

    @Test func successfulImportOfASyntheticPDF() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try Self.pdfA()
        let url = try writeTemporaryFile(data)

        let rulebook = try await library.importRulebook(fileAt: url, into: game, store: store)

        let id = RulebookID(bytes: data)
        let imported = try #require(game.rulebook)
        #expect(imported === rulebook)
        #expect(imported.rulebookID == id.hex)
        #expect(imported.pageCount == 2)
        let expected = PassageExtractor.extract(from: try #require(PDFDocument(data: data)), rulebookID: id)
        try #require(!expected.isEmpty)
        #expect(imported.orderedPassages.map { $0.extractedPassage(rulebookID: id) } == expected)
        #expect(try Data(contentsOf: store.baseDirectory.appending(path: "\(id.hex).pdf")) == data)
    }

    // MARK: Scenario 2

    @Test func persistence() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try Self.pdfA()
        let rulebook = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: game, store: store)
        let id = RulebookID(bytes: data)
        let original = rulebook.orderedPassages.map { $0.extractedPassage(rulebookID: id) }

        let context = ModelContext(container)
        let fetched = try context.fetch(FetchDescriptor<Game>(predicate: #Predicate { $0.name == "Taifa" }))

        let reloadedGame = try #require(fetched.first)
        let reloaded = try #require(reloadedGame.rulebook)
        #expect(fetched.count == 1)
        #expect(reloaded.rulebookID == id.hex)
        #expect(reloaded.pageCount == 2)
        let reloadedID = try #require(RulebookID(hex: reloaded.rulebookID))
        let passages = reloaded.orderedPassages.map { $0.extractedPassage(rulebookID: reloadedID) }
        #expect(passages.map(\.text) == original.map(\.text))
        #expect(passages.map(\.ordinal) == original.map(\.ordinal))
        #expect(passages.map(\.locator) == original.map(\.locator))
        #expect(passages.map(\.ordinal) == Array(0..<passages.count))
    }

    // MARK: Scenario 4

    @Test func storageFailure() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let notADirectory = directory.appending(path: "Rulebooks-file")
        try Data("a regular file".utf8).write(to: notADirectory)
        let store = RulebookStore(baseDirectory: notADirectory)
        let url = try writeTemporaryFile(try Self.pdfA())

        await #expect(throws: ImportError.storage) {
            _ = try await library.importRulebook(fileAt: url, into: game, store: store)
        }

        #expect(try rowCounts(in: library.context) == .empty)
        #expect(try rowCounts(in: ModelContext(container)) == .empty)
        // Only the source file itself is a PDF under the temporary directory.
        #expect(pdfFileNames(under: directory) == [url.lastPathComponent])
        #expect(game.rulebook == nil)
    }

    // MARK: Scenario 5

    @Test func bytesThatAreNotAPDF() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let url = directory.appending(path: "not-a-pdf.txt")
        try Data("not a pdf".utf8).write(to: url)

        await #expect(throws: ImportError.unreadable) {
            _ = try await library.importRulebook(fileAt: url, into: game, store: store)
        }

        #expect(try rowCounts(in: library.context) == .empty)
        #expect(try rowCounts(in: ModelContext(container)) == .empty)
        #expect(storedFiles().isEmpty)
        #expect(game.rulebook == nil)
    }

    @Test func missingFileIsUnreadable() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")

        await #expect(throws: ImportError.unreadable) {
            _ = try await library.importRulebook(fileAt: directory.appending(path: "missing.pdf"), into: game, store: store)
        }

        #expect(try rowCounts(in: ModelContext(container)) == .empty)
        #expect(storedFiles().isEmpty)
        #expect(game.rulebook == nil)
    }

    // MARK: Scenario 6

    @Test func gameThatAlreadyHasARulebook() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let dataA = try Self.pdfA()
        let dataB = try Self.pdfB()
        try #require(RulebookID(bytes: dataA) != RulebookID(bytes: dataB))
        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(dataA), into: game, store: store)
        let countsBefore = try rowCounts(in: ModelContext(container))
        let filesBefore = Set(storedFiles())
        let urlB = try writeTemporaryFile(dataB)

        await #expect(throws: ImportError.gameHasRulebook) {
            _ = try await library.importRulebook(fileAt: urlB, into: game, store: store)
        }

        #expect(try rowCounts(in: ModelContext(container)) == countsBefore)
        #expect(try rowCounts(in: library.context) == countsBefore)
        #expect(Set(storedFiles()) == filesBefore)
        #expect(filesBefore == ["\(RulebookID(bytes: dataA).hex).pdf"])
        #expect(game.rulebook?.rulebookID == RulebookID(bytes: dataA).hex)
    }

    // MARK: Save failure (not a spec scenario; covers rollback and file removal)

    @Test func saveFailureRollsBackAndRemovesTheFile() async throws {
        defer { removeDirectory() }
        // A read-only store makes save() throw. It must be on disk: an in-memory store cannot open read-only.
        let storeURL = directory.appending(path: "library.store")
        let writable = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        try Library(context: writable.mainContext).createGame(named: "Taifa")
        let readOnly = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(url: storeURL, allowsSave: false)
        )
        let library = Library(context: readOnly.mainContext)
        let game = try #require(try library.context.fetch(FetchDescriptor<Game>()).first)
        let url = try writeTemporaryFile(try Self.pdfA())

        await #expect(throws: ImportError.storage) {
            _ = try await library.importRulebook(fileAt: url, into: game, store: store)
        }

        #expect(!library.context.hasChanges)
        #expect(try rowCounts(in: library.context) == .empty)
        #expect(try rowCounts(in: ModelContext(readOnly)) == .empty)
        #expect(storedFiles().isEmpty)
        #expect(game.rulebook == nil)
    }
}
