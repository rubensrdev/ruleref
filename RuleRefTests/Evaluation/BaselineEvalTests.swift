import Foundation
import SwiftData
import Testing
@testable import RuleRef

/// The baseline of text search on the eval set. It records the scores; it never fails because of them.
struct BaselineEvalTests {

    // MARK: Scenarios 1 and 6

    @Test func taifaBaseline() async throws {
        let pdf = try TestFixture.url(forResource: "taifa-3.0", withExtension: "pdf")
        let evalSetURL = try TestFixture.url(forResource: "taifa-3.0-eval", withExtension: "json")
        let evalSet = try JSONDecoder().decode(EvalSet.self, from: Data(contentsOf: evalSetURL))

        let sha256 = RulebookID(bytes: try Data(contentsOf: pdf)).hex
        try #require(
            sha256 == evalSet.fixtureSHA256,
            "taifa-3.0.pdf SHA-256 \(sha256) differs from the eval set's fixtureSHA256 \(evalSet.fixtureSHA256)"
        )

        let container = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let library = Library(context: container.mainContext)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory.appending(path: "Rulebooks", directoryHint: .isDirectory))
        let game = try library.createGame(named: "Taifa")
        let rulebook = try await library.importRulebook(fileAt: pdf, into: game, store: store).rulebook

        try evalSet.validate(pageCount: rulebook.pageCount)

        let index = SearchIndex(rulebook: rulebook)
        let rows = evalSet.questions.map { question in
            BaselineReport.Row(question: question, state: index.search(question.query))
        }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let report = BaselineReport(
            rows: rows,
            passageCount: rulebook.passages.count,
            fixtureSHA256: sha256,
            iOSVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        )

        // No expectation on any score.
        Attachment.record(try report.json(), named: "f16-baseline-taifa-3.0.json")
    }
}
