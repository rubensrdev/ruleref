import CoreGraphics
import Foundation
import PDFKit
import SwiftData
import Testing
@testable import RuleRef

struct NoTextLayerImportTests {

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

    private static let imageRect = CGRect(x: 72, y: 200, width: 468, height: 400)

    private static func imageOnlyData() throws -> Data {
        try SyntheticPDF.data(pages: [SyntheticPDF.Page(rects: [imageRect])])
    }

    private static func textPDF() throws -> Data {
        try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Each player takes five tiles", "and places them face down."]])),
        ])
    }

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    /// Character counts PDFKit reports for each page of `data`.
    private static func characterCounts(of data: Data) throws -> [Int] {
        let document = try #require(PDFDocument(data: data))
        return try (0..<document.pageCount).map { try #require(document.page(at: $0)).numberOfCharacters }
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

    /// Imports `data` into `game` and checks that it fails with exactly `.noTextLayer` and persists nothing.
    private func expectRejectedWithNothingPersisted(_ data: Data, into game: Game) async throws {
        let url = try writeTemporaryFile(data)

        await #expect(throws: ImportError.noTextLayer) {
            _ = try await library.importRulebook(fileAt: url, into: game, store: store)
        }

        let empty = RowCounts(rulebooks: 0, passages: 0)
        #expect(try rowCounts(in: library.context) == empty)
        #expect(try rowCounts(in: ModelContext(container)) == empty)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: RulebookID(bytes: data)).path()))
        #expect(try storedFiles().isEmpty)
        #expect(game.rulebook == nil)
    }

    // MARK: Scenario 1

    @Test func imageOnlyPDF() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try Self.imageOnlyData()
        try #require(try Self.characterCounts(of: data) == [0])

        try await expectRejectedWithNothingPersisted(data, into: game)
    }

    // MARK: Scenario 2

    @Test func blankPages() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try SyntheticPDF.data(pages: [SyntheticPDF.Page(), SyntheticPDF.Page()])
        try #require(try Self.characterCounts(of: data) == [0, 0])

        try await expectRejectedWithNothingPersisted(data, into: game)
    }

    // MARK: Scenario 3

    @Test func mixedPDFImports() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let data = try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Each player takes five tiles", "and places them face down."]])),
            SyntheticPDF.Page(rects: [Self.imageRect]),
        ])
        let counts = try Self.characterCounts(of: data)
        try #require(counts.count == 2)
        try #require(counts[0] > 0)
        try #require(counts[1] == 0)
        let url = try writeTemporaryFile(data)

        _ = try await library.importRulebook(fileAt: url, into: game, store: store)

        let rulebook = try #require(game.rulebook)
        #expect(rulebook.pageCount == 2)
        #expect(!rulebook.passages.isEmpty)
        #expect(rulebook.passages.allSatisfy { $0.pageIndex == 0 })
        #expect(FileManager.default.fileExists(atPath: store.fileURL(for: RulebookID(bytes: data)).path()))
    }

    // MARK: Scenario 4

    @Test func gameCanImportAfterARejection() async throws {
        defer { removeDirectory() }
        let game = try library.createGame(named: "Taifa")
        let imageOnly = try Self.imageOnlyData()
        try #require(try Self.characterCounts(of: imageOnly) == [0])
        let imageOnlyURL = try writeTemporaryFile(imageOnly)
        await #expect(throws: ImportError.noTextLayer) {
            _ = try await library.importRulebook(fileAt: imageOnlyURL, into: game, store: store)
        }
        let data = try Self.textPDF()
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
