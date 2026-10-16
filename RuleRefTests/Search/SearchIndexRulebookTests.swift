import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct SearchIndexRulebookTests {

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

    // MARK: Scenario 8

    @Test func searchOverAnImportedRulebook() async throws {
        defer { removeDirectory() }
        let pdf = try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["A road ends at a city", "or at a crossing."]])),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Play goes on at the next tile", "or at another road."]])),
        ])
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try pdf.write(to: url)
        let game = try library.createGame(named: "Carcassonne")

        let rulebook = try await library.importRulebook(fileAt: url, into: game, store: store).rulebook

        let id = try #require(RulebookID(hex: rulebook.rulebookID))
        let onPage2 = try #require(rulebook.orderedPassages.first { $0.pageIndex == 1 && $0.text.contains("or at another road") })
        let state = SearchIndex(rulebook: rulebook).search("another")
        guard case .matches(let matches) = state else {
            Issue.record("expected .matches, got \(state)")
            return
        }
        #expect(matches.count == 1)
        #expect(matches.first?.pageNumber == 2)
        #expect(matches.first?.passage == onPage2.extractedPassage(rulebookID: id))
    }
}
