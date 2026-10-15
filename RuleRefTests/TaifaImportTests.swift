import Foundation
import SwiftData
import Testing
@testable import RuleRef

/// Declared in the test target, so `Bundle(for:)` finds the test bundle even though tests are hosted by the app.
private final class TaifaFixtureToken {}

struct TaifaImportTests {

    // MARK: Scenario 3

    @Test func taifaFixture() async throws {
        // Missing fixture → the test fails, never skips.
        let fixture = try #require(
            Bundle(for: TaifaFixtureToken.self).url(forResource: "taifa-3.0", withExtension: "pdf"),
            "taifa-3.0.pdf is not in the test bundle"
        )
        let bytes = try Data(contentsOf: fixture)
        let container = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let library = Library(context: container.mainContext)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory.appending(path: "Rulebooks", directoryHint: .isDirectory))
        let game = try library.createGame(named: "Taifa")

        let rulebook = try await library.importRulebook(fileAt: fixture, into: game, store: store)

        #expect(rulebook.pageCount == 16)
        #expect(!rulebook.passages.isEmpty)
        let id = RulebookID(bytes: bytes)
        #expect(rulebook.rulebookID == id.hex)
        #expect(try Data(contentsOf: store.fileURL(for: id)) == bytes)
        // Counts and texts for the evidence and the ADR-002 findings, readable from the result bundle.
        let passages = rulebook.orderedPassages
        let perPage = Dictionary(grouping: passages, by: \.pageIndex).mapValues(\.count).sorted { $0.key < $1.key }
        let summary = "pageCount=\(rulebook.pageCount) passages=\(passages.count) perPage="
            + perPage.map { "\($0.key):\($0.value)" }.joined(separator: ",")
        let dump = passages.map { "[\($0.ordinal)] p\($0.pageIndex) \($0.text)" }.joined(separator: "\n")
        Attachment.record(summary + "\n\n" + dump, named: "taifa-passages.txt")
    }
}
