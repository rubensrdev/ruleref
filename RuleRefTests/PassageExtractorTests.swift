import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import RuleRef

struct PassageExtractorTests {

    private static let rulebookID = RulebookID(bytes: Data("synthetic rulebook".utf8))

    // MARK: Layouts

    private static let twoParagraphs = [
        ["Each player takes five tiles", "and places them face down."],
        ["The first player is the youngest.", "Play goes clockwise around", "the table until the end."],
    ]

    /// Scenario 1: one page, paragraphs of 2 and 3 lines.
    private static func twoParagraphPages() -> [SyntheticPDF.Page] {
        [SyntheticPDF.Page(lines: SyntheticPDF.paragraphs(twoParagraphs))]
    }

    /// Scenario 2: the only paragraph starts at the bottom of page 1 and ends at the top of page 2.
    private static func continuedParagraphPages() -> [SyntheticPDF.Page] {
        [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["A road ends at a city", "or at a crossing"]], top: 100)),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["or at another road", "already on the table."]])),
        ]
    }

    /// Scenario 3: the middle lines are narrower and shifted right of an image stand-in, same line step.
    /// The full-width lines span the narrow lines' x range, as in a real wrap; otherwise PDFKit reads two columns.
    private static let wrappedTexts = [
        "Farmers score at the end of the game for every completed city that touches",
        "their field, counted once per farmer group, whatever the number of roads in",
        "between, even when the city",
        "is split by a river or a",
        "lake drawn on the tiles,",
        "and each city counts only once for each group of farmers placed in that field.",
    ]

    private static func wrappedImagePages() -> [SyntheticPDF.Page] {
        let top: CGFloat = 720
        let lines = wrappedTexts.enumerated().map { index, text in
            let shifted = (2...4).contains(index)
            return SyntheticPDF.Line(text: text, x: shifted ? 320 : 72, baseline: top - CGFloat(index) * SyntheticPDF.lineStep)
        }
        let image = CGRect(x: 72, y: top - 4 * SyntheticPDF.lineStep - 4, width: 230, height: 3 * SyntheticPDF.lineStep)
        return [SyntheticPDF.Page(lines: lines, rects: [image])]
    }

    // MARK: Reader

    @Test func linesAreReadOnePerDrawnLineInDrawingOrder() throws {
        let document = try SyntheticPDF.document(pages: Self.twoParagraphPages())
        let page = try #require(document.page(at: 0))

        let lines = PassageExtractor.lines(on: page)

        #expect(lines.map(\.text) == Self.twoParagraphs.flatMap { $0 })
        try SyntheticPDF.requireSpacing(of: lines, paragraphStarts: [2])
        #expect(lines.allSatisfy { !$0.bounds.isEmpty })
    }

    // MARK: Scenario 1

    @Test func twoParagraphsOnOnePage() throws {
        let document = try SyntheticPDF.document(pages: Self.twoParagraphPages())
        try SyntheticPDF.requireSpacing(of: PassageExtractor.lines(on: try #require(document.page(at: 0))), paragraphStarts: [2])

        let passages = PassageExtractor.extract(from: document, rulebookID: Self.rulebookID)

        #expect(passages.map(\.text) == Self.twoParagraphs.map { $0.joined(separator: " ") })
        #expect(passages.map(\.ordinal) == [0, 1])
        #expect(passages.map { Self.pageIndex(of: $0) } == [0, 0])
    }

    // MARK: Scenario 2

    @Test func paragraphContinuedOnTheNextPage() throws {
        let document = try SyntheticPDF.document(pages: Self.continuedParagraphPages())
        for index in 0..<2 {
            try SyntheticPDF.requireSpacing(of: PassageExtractor.lines(on: try #require(document.page(at: index))), paragraphStarts: [])
        }

        let passages = PassageExtractor.extract(from: document, rulebookID: Self.rulebookID)

        #expect(passages.map(\.text) == ["A road ends at a city or at a crossing", "or at another road already on the table."])
        #expect(passages.map(\.ordinal) == [0, 1])
        #expect(passages.map { Self.pageIndex(of: $0) } == [0, 1])
    }

    // MARK: Scenario 3

    @Test func textWrappingAnImage() throws {
        let document = try SyntheticPDF.document(pages: Self.wrappedImagePages())
        let lines = PassageExtractor.lines(on: try #require(document.page(at: 0)))
        try #require(lines.map(\.text) == Self.wrappedTexts)
        try SyntheticPDF.requireSpacing(of: lines, paragraphStarts: [])
        try #require(lines[2].bounds.minX > lines[1].bounds.minX)
        try #require(lines[2].bounds.width < lines[5].bounds.width)

        let passages = PassageExtractor.extract(from: document, rulebookID: Self.rulebookID)

        #expect(passages.map(\.text) == [Self.wrappedTexts.joined(separator: " ")])
        #expect(passages.map(\.ordinal) == [0])
    }

    // MARK: Scenario 4

    @Test func boundsAreNonEmptyInsideTheCropBoxAndContainTheirLines() throws {
        // Line count of each passage, by ordinal, taken from its layout: normalized text has no "\n" to count.
        let layouts: [(pages: [SyntheticPDF.Page], lineCounts: [Int])] = [
            (Self.twoParagraphPages(), Self.twoParagraphs.map(\.count)),
            (Self.continuedParagraphPages(), [2, 2]),
            (Self.wrappedImagePages(), [Self.wrappedTexts.count]),
        ]
        for (pages, lineCounts) in layouts {
            let document = try SyntheticPDF.document(pages: pages)
            let passages = PassageExtractor.extract(from: document, rulebookID: Self.rulebookID)
            try #require(!passages.isEmpty)
            try #require(passages.count == lineCounts.count)

            for pageIndex in 0..<document.pageCount {
                let page = try #require(document.page(at: pageIndex))
                let cropBox = page.bounds(for: .cropBox)
                var remaining = PassageExtractor.lines(on: page)[...]
                for passage in passages where Self.pageIndex(of: passage) == pageIndex {
                    let bounds = Self.bounds(of: passage)
                    #expect(!bounds.isEmpty)
                    #expect(cropBox.contains(bounds))
                    let lineCount = lineCounts[passage.ordinal]
                    try #require(remaining.count >= lineCount)
                    for line in remaining.prefix(lineCount) {
                        #expect(bounds.contains(line.bounds), "\(line.text) is outside its passage")
                    }
                    remaining = remaining.dropFirst(lineCount)
                }
                #expect(remaining.isEmpty)
            }
        }
    }

    // MARK: Scenario 5

    @Test func aPageWithoutText() throws {
        let document = try SyntheticPDF.document(pages: [
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Page one text"]])),
            SyntheticPDF.Page(rects: [CGRect(x: 72, y: 72, width: 200, height: 200)]),
            SyntheticPDF.Page(lines: SyntheticPDF.paragraphs([["Page three first"], ["Page three second"]])),
        ])
        try #require(document.pageCount == 3)
        try #require(document.page(at: 1)?.numberOfCharacters == 0)

        let passages = PassageExtractor.extract(from: document, rulebookID: Self.rulebookID)

        #expect(passages.map(\.text) == ["Page one text", "Page three first", "Page three second"])
        #expect(passages.map { Self.pageIndex(of: $0) } == [0, 2, 2])
        #expect(passages.map(\.ordinal) == [0, 1, 2])
    }

    // MARK: Scenario 6

    @Test func determinism() throws {
        let data = try SyntheticPDF.data(pages: Self.twoParagraphPages() + Self.wrappedImagePages())
        let first = try SyntheticPDF.document(from: data)
        let second = try SyntheticPDF.document(from: data)
        #expect(first !== second)

        let firstPassages = PassageExtractor.extract(from: first, rulebookID: Self.rulebookID)
        let secondPassages = PassageExtractor.extract(from: second, rulebookID: Self.rulebookID)

        #expect(firstPassages.count == 3)
        #expect(firstPassages == secondPassages)
    }

    // MARK: Scenario 7

    @Test func rulebookID() throws {
        let id = RulebookID(bytes: Data("abc".utf8))
        try #require(id.hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let document = try SyntheticPDF.document(pages: Self.continuedParagraphPages())

        let passages = PassageExtractor.extract(from: document, rulebookID: id)

        try #require(!passages.isEmpty)
        for passage in passages {
            switch passage.locator {
            case .pdf(let rulebookID, _, _): #expect(rulebookID == id)
            }
        }
    }

    // MARK: Helpers

    private static func pageIndex(of passage: ExtractedPassage) -> Int {
        switch passage.locator {
        case .pdf(_, let pageIndex, _): pageIndex
        }
    }

    private static func bounds(of passage: ExtractedPassage) -> CGRect {
        switch passage.locator {
        case .pdf(_, _, let bounds): bounds
        }
    }
}
