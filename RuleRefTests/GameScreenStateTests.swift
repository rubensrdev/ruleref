import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct GameScreenStateTests {

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

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    private static func twoPagePDF() throws -> Data {
        try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Each player takes five tiles", "and places them face down."]])),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Play goes clockwise around", "the table until the end."]])),
        ])
    }

    // MARK: Scenario 1

    @Test func screenStateFromEmptyToReady() async throws {
        defer { removeDirectory() }
        let taifa = try library.createGame(named: "Taifa")
        #expect(GameScreenState(game: taifa) == .empty)

        let url = try writeTemporaryFile(Self.twoPagePDF())
        let first = await library.importPickedFile(at: url, into: taifa, store: store)
        guard case .success(.imported) = first else {
            Issue.record("expected .success(.imported(_)), got \(first)")
            return
        }
        #expect(GameScreenState(game: taifa) == .ready(pageCount: 2))

        let second = await library.importPickedFile(at: url, into: taifa, store: store)
        guard case .success(.alreadyPresent) = second else {
            Issue.record("expected .success(.alreadyPresent(_)), got \(second)")
            return
        }
        #expect(GameScreenState(game: taifa) == .ready(pageCount: 2))

        let other = try library.createGame(named: "Catán")
        let notAPDF = try writeTemporaryFile(Data("not a pdf".utf8))
        let third = await library.importPickedFile(at: notAPDF, into: other, store: store)
        guard case .failure(let error) = third else {
            Issue.record("expected .failure(.unreadable), got \(third)")
            return
        }
        #expect(error == .unreadable)
        #expect(GameScreenState(game: other) == .empty)
    }
}
