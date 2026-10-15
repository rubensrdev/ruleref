import Foundation
import SwiftData
import Testing
@testable import RuleRef

struct ImportErrorMessageTests {

    nonisolated static let allErrors: [ImportError] = [
        .unreadable, .locked, .noTextLayer, .alreadyImported(gameName: "Taifa"), .storage, .gameHasRulebook,
    ]

    private static func resolved(_ resource: LocalizedStringResource, in language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    // MARK: Scenario 2

    @Test func oneDistinctMessagePerErrorKeysAreDistinct() {
        let keys = Self.allErrors.map { ImportErrorMessage.message(for: $0).key }
        #expect(Set(keys).count == Self.allErrors.count)
    }

    @Test func oneDistinctMessagePerErrorAlreadyImportedKeyIsExact() {
        let taifa = ImportErrorMessage.message(for: .alreadyImported(gameName: "Taifa"))
        let catan = ImportErrorMessage.message(for: .alreadyImported(gameName: "Catán"))
        #expect(taifa.key == "This rulebook is already in “%@”.")
        #expect(catan.key == taifa.key)
    }

    @Test func oneDistinctMessagePerErrorGameNameIsAnArgument() {
        let catan = ImportErrorMessage.message(for: .alreadyImported(gameName: "Catán"))
        #expect(Self.resolved(catan, in: "en") == "This rulebook is already in “Catán”.")
        #expect(Self.resolved(catan, in: "es") == "Este reglamento ya está en «Catán».")
    }

    // MARK: Scenario 3

    @Test func successfulOutcomesProduceNoMessage() async throws {
        let container = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let library = Library(context: container.mainContext)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory.appending(path: "Rulebooks", directoryHint: .isDirectory))

        let url = directory.appending(path: "rulebook.pdf")
        try SyntheticPDF.data(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Farmers score at the end."]])),
        ]).write(to: url)
        let game = try library.createGame(named: "Taifa")
        let rulebook = try await library.importRulebook(fileAt: url, into: game, store: store).rulebook

        #expect(ImportErrorMessage.message(for: .success(.imported(rulebook))) == nil)
        #expect(ImportErrorMessage.message(for: .success(.alreadyPresent(rulebook))) == nil)
    }

    @Test(arguments: allErrors)
    func successfulOutcomesProduceNoMessageFailureMatchesTheError(_ error: ImportError) {
        #expect(ImportErrorMessage.message(for: .failure(error)) == ImportErrorMessage.message(for: error))
    }
}
