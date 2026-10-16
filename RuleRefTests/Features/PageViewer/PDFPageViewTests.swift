import CoreGraphics
import Foundation
import PDFKit
import SwiftData
import Testing
@testable import RuleRef

struct PDFPageViewTests {

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

    // MARK: Scenario 2

    @Test func theHighlightIsOneAnnotationWithTheSameBoundsAndTheFileIsUntouched() async throws {
        defer { removeDirectory() }
        let fixture = try await PageViewerFixture.importTwoPages(library: library, directory: directory, store: store)
        let highlight = PageHighlight(locator: fixture.match.passage.locator)
        let fileURL = store.fileURL(for: highlight.rulebookID)
        let bytesBefore = try Data(contentsOf: fileURL)

        let document = try #require(PageViewer.openDocument(for: highlight.rulebookID, store: store))
        try #require(document.pageCount == 2)
        let annotationsBefore = try (0..<document.pageCount).map { try #require(document.page(at: $0)).annotations.count }

        let page = try #require(PDFPageView.addHighlight(highlight, to: document))

        #expect(document.index(for: page) == 1)
        for index in 0..<document.pageCount {
            let annotations = try #require(document.page(at: index)).annotations
            let added = index == 1 ? 1 : 0
            #expect(annotations.count == annotationsBefore[index] + added, "page \(index)")
        }
        let annotation = try #require(page.annotations.last)
        #expect(annotation.bounds == highlight.bounds)
        #expect(try Data(contentsOf: fileURL) == bytesBefore)
    }

    // MARK: Scenario 3

    @Test func aMissingFileIsUnavailable() {
        defer { removeDirectory() }
        let id = RulebookID(bytes: Data("not stored".utf8))

        #expect(PageViewer.openDocument(for: id, store: store) == nil)
    }

    @Test func aMissingPageIsUnavailable() throws {
        defer { removeDirectory() }
        let document = try SyntheticPDF.document(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["First page."]])),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Second page."]])),
        ])
        let annotationsBefore = try (0..<document.pageCount).map { try #require(document.page(at: $0)).annotations.count }
        let highlight = PageHighlight(locator: .pdf(
            rulebookID: RulebookID(bytes: Data("two pages".utf8)),
            pageIndex: 5,
            bounds: CGRect(x: 72, y: 700, width: 200, height: 14)
        ))

        #expect(PDFPageView.addHighlight(highlight, to: document) == nil)
        let annotationsAfter = try (0..<document.pageCount).map { try #require(document.page(at: $0)).annotations.count }
        #expect(annotationsAfter == annotationsBefore)
    }
}
