import Foundation
import PDFKit
import SwiftData
import Testing
@testable import RuleRef

struct UnreadableFileImportTests {

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

    private static let page = SyntheticPDF.Page(
        lines: SyntheticPDF.paragraphs([["Each player takes five tiles", "and places them face down."]])
    )

    /// Owner and user passwords differ, so PDFKit cannot open it with the empty password.
    private static func lockedData() throws -> Data {
        try SyntheticPDF.data(
            pages: [page],
            encryption: SyntheticPDF.Encryption(ownerPassword: "ruleref-owner", userPassword: "ruleref-user")
        )
    }

    /// No user password: the user password is empty, so PDFKit opens it unlocked.
    private static func ownerOnlyData() throws -> Data {
        try SyntheticPDF.data(
            pages: [page],
            encryption: SyntheticPDF.Encryption(ownerPassword: "ruleref-owner", userPassword: nil)
        )
    }

    /// A PDF header followed by 0x00...0xFF repeated four times.
    private static func corruptData() -> Data {
        var data = Data("%PDF-1.7\n".utf8)
        for _ in 0..<4 {
            data.append(contentsOf: (0...255).map { UInt8($0) })
        }
        return data
    }

    private static func requireLocked(_ data: Data) throws {
        let document = try #require(PDFDocument(data: data))
        try #require(document.isEncrypted)
        try #require(document.isLocked)
    }

    private static func requireCorrupt(_ data: Data) throws {
        try #require(data.count == 9 + 1_024)
        try #require(PDFDocument(data: data) == nil)
    }

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    private struct RowCounts: Equatable {
        let rulebooks: Int
        let passages: Int
    }

    // fetch, not fetchCount: fetchCount can return a stale count (f02, f08).
    private func rowCounts(in context: ModelContext) throws -> RowCounts {
        RowCounts(
            rulebooks: try context.fetch(FetchDescriptor<Rulebook>()).count,
            passages: try context.fetch(FetchDescriptor<Passage>()).count
        )
    }

    /// Files directly in the store's base directory; a missing directory counts as empty,
    /// since only `RulebookStore.write` creates it.
    private func storedFiles() throws -> [String] {
        guard FileManager.default.fileExists(atPath: store.baseDirectory.path()) else { return [] }
        return try FileManager.default
            .contentsOfDirectory(at: store.baseDirectory, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
    }

    /// Imports `data` into `game` and returns the `ImportError` it throws; records an issue if it throws none.
    private func importError(_ data: Data, into game: Game) async throws -> ImportError? {
        let url = try writeTemporaryFile(data)
        return await #expect(throws: ImportError.self) {
            _ = try await library.importRulebook(fileAt: url, into: game, store: store)
        }
    }

    /// No rows in either context, no stored file for any of `data`, an empty store and no rulebook on `game`.
    private func expectNothingPersisted(for data: [Data], game: Game) throws {
        let empty = RowCounts(rulebooks: 0, passages: 0)
        #expect(try rowCounts(in: library.context) == empty)
        #expect(try rowCounts(in: ModelContext(container)) == empty)
        for bytes in data {
            #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: RulebookID(bytes: bytes)).path()))
        }
        #expect(try storedFiles().isEmpty)
        #expect(game.rulebook == nil)
    }

    // MARK: Scenario 1

    @Test func userPasswordLocked() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try Self.lockedData()
        try Self.requireLocked(data)

        let error = try await importError(data, into: game)

        #expect(error == .locked)
        try expectNothingPersisted(for: [data], game: game)
    }

    // MARK: Scenario 2

    @Test func ownerPasswordOnlyImports() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try Self.ownerOnlyData()
        let document = try #require(PDFDocument(data: data))
        try #require(document.isEncrypted)
        try #require(!document.isLocked)
        let id = RulebookID(bytes: data)

        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: game, store: store)

        let rulebook = try #require(game.rulebook)
        #expect(rulebook.rulebookID == id.hex)
        #expect(rulebook.pageCount == 1)
        #expect(!rulebook.passages.isEmpty)
        let storedURL = store.baseDirectory.appending(path: "\(id.hex).pdf")
        #expect(try Data(contentsOf: storedURL) == data)
    }

    // MARK: Scenario 3

    @Test func corruptFileUnreadable() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = Self.corruptData()
        try Self.requireCorrupt(data)

        let error = try await importError(data, into: game)

        #expect(error == .unreadable)
        try expectNothingPersisted(for: [data], game: game)
    }

    // MARK: Scenario 4

    @Test func distinctErrors() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let locked = try Self.lockedData()
        try Self.requireLocked(locked)
        let corrupt = Self.corruptData()
        try Self.requireCorrupt(corrupt)

        let lockedError = try await importError(locked, into: game)
        let corruptError = try await importError(corrupt, into: game)

        #expect(lockedError == .locked)
        #expect(corruptError == .unreadable)
        #expect(lockedError != corruptError)
        try expectNothingPersisted(for: [locked, corrupt], game: game)
    }

    // MARK: Scenario 5

    @Test func gameCanImportAfterARejection() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let locked = try Self.lockedData()
        try Self.requireLocked(locked)
        let lockedError = try await importError(locked, into: game)
        try #require(lockedError == .locked)
        let data = try SyntheticPDF.data(pages: [Self.page])
        let id = RulebookID(bytes: data)

        _ = try await library.importRulebook(fileAt: try writeTemporaryFile(data), into: game, store: store)

        let rulebook = try #require(game.rulebook)
        #expect(rulebook.rulebookID == id.hex)
        let rulebooks = try library.context.fetch(FetchDescriptor<Rulebook>())
        #expect(rulebooks.count == 1)
        let expected = PassageExtractor.extract(from: try #require(PDFDocument(data: data)), rulebookID: id)
        try #require(!expected.isEmpty)
        #expect(rulebook.orderedPassages.map { $0.extractedPassage(rulebookID: id) } == expected)
        #expect(try storedFiles() == ["\(id.hex).pdf"])
    }
}
