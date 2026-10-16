import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct PageHighlightTests {

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

    // MARK: Scenario 1

    @Test func theViewerReceivesExactlyTheLocatorsPageAndBounds() async throws {
        defer { removeDirectory() }
        let fixture = try await PageViewerFixture.importTwoPages(library: library, directory: directory, store: store)

        let highlight = PageHighlight(locator: fixture.match.passage.locator)

        guard case let .pdf(rulebookID, pageIndex, bounds) = fixture.match.passage.locator else {
            Issue.record("expected a .pdf locator")
            return
        }
        #expect(highlight.rulebookID == rulebookID)
        #expect(highlight.pageIndex == pageIndex)
        #expect(highlight.bounds == bounds)
        #expect(highlight.rulebookID == fixture.rulebookID)
        #expect(highlight.pageIndex == 1)
        #expect(highlight.bounds == fixture.storedBounds)
    }
}

/// A two-page synthetic rulebook imported into a game, and the match for a term on page 2.
struct PageViewerFixture {
    let rulebookID: RulebookID
    let match: Match
    /// The bounds the stored `Passage` holds for that match.
    let storedBounds: CGRect

    static func importTwoPages(library: Library, directory: URL, store: RulebookStore) async throws -> PageViewerFixture {
        let pdf = try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["A road ends at a city", "or at a crossing."]])),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Play goes on at the next tile", "or at another road."]])),
        ])
        let url = directory.appending(path: "\(UUID().uuidString).pdf")
        try pdf.write(to: url)
        let game = try library.createGame(named: "Carcassonne")

        let rulebook = try await library.importRulebook(fileAt: url, into: game, store: store).rulebook

        let id = try #require(RulebookID(hex: rulebook.rulebookID))
        let stored = try #require(rulebook.orderedPassages.first { $0.pageIndex == 1 && $0.text.contains("another road") })
        let state = SearchIndex(rulebook: rulebook).search("another")
        let match = try #require(state.matches.first)
        try #require(state.matches.count == 1)
        return PageViewerFixture(
            rulebookID: id,
            match: match,
            storedBounds: CGRect(x: stored.minX, y: stored.minY, width: stored.width, height: stored.height)
        )
    }
}
