import Foundation
import PDFKit
import Testing
@testable import RuleRef

struct HyphenationExtractionTests {

    private static let paragraph = ["Each turn you may", "cons-", "truir", "one road."]

    // MARK: Scenario 1

    @Test func featureVerificationOnAPDF() throws {
        let document = try SyntheticPDF.document(pages: [SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([Self.paragraph]))])
        let lines = PassageExtractor.lines(on: try #require(document.page(at: 0)))
        try #require(lines.map(\.text) == Self.paragraph)
        try #require(lines[1].text == "cons-" && lines[2].text == "truir")
        try SyntheticPDF.requireSpacing(of: lines, paragraphStarts: [])

        let passages = PassageExtractor.extract(from: document, rulebookID: RulebookID(bytes: Data("hyphenation".utf8)))

        let passage = try #require(passages.first)
        #expect(passages.count == 1)
        #expect(passage.text.contains("construir"))
        #expect(!passage.text.contains("cons-"))
    }
}
