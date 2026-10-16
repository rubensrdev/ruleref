import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import RuleRef

/// Declared in the test target, so `Bundle(for:)` finds the test bundle even though tests are hosted by the app.
private final class TaifaSegmentationFixtureToken {}

struct TaifaSegmentationTests {

    private static func taifa() throws -> PDFDocument {
        // Missing fixture → the test fails, never skips.
        let url = try #require(
            Bundle(for: TaifaSegmentationFixtureToken.self).url(forResource: "taifa-3.0", withExtension: "pdf"),
            "taifa-3.0.pdf is not in the test bundle"
        )
        return try #require(PDFDocument(url: url))
    }

    /// Passages of one page; `pageIndex` is the printed page number minus one.
    private static func passages(onPage pageIndex: Int) throws -> [ExtractedPassage] {
        let document = try taifa()
        // The ID only goes into the locator; it does not affect segmentation.
        let rulebookID = RulebookID(bytes: Data("taifa-3.0".utf8))
        return PassageExtractor.extract(from: document, rulebookID: rulebookID).filter {
            guard case let .pdf(_, index, _) = $0.locator else { return false }
            return index == pageIndex
        }
    }

    // MARK: Scenarios 1-3: page 5

    @Test func numberedParagraphBeginsAPassage() throws {
        let page5 = try Self.passages(onPage: 4)
        #expect(page5.contains { $0.text.hasPrefix("6. Si el atacante gana") })
    }

    @Test func plainParagraphBeginsAPassage() throws {
        let page5 = try Self.passages(onPage: 4)
        #expect(page5.contains { $0.text.hasPrefix("Seguidamente el defensor suma") })
    }

    @Test func lineInTheMiddleOfAParagraphDoesNot() throws {
        let page5 = try Self.passages(onPage: 4)
        let middle = "avanzar una posición en su marcador de Bonus de Carta"
        #expect(!page5.contains { $0.text.hasPrefix(middle) })
        let paragraph = try #require(page5.first { $0.text.hasPrefix("6. Si el atacante gana") })
        #expect(paragraph.text.contains(middle))
    }

    // MARK: Scenario 4: page 4

    @Test func bulletItemBeginsAPassage() throws {
        let bulletItems = try Self.passages(onPage: 3).filter { $0.text.hasPrefix("•") }
        let attack = try #require(bulletItems.first { $0.text.contains("Atacar: El reino selecciona") })
        let raid = try #require(bulletItems.first { $0.text.contains("Incursión: El reino selecciona") })
        #expect(attack != raid)
        #expect(!attack.text.contains("Incursión: El reino selecciona"))
    }

    private static func format(_ value: CGFloat) -> String {
        Double(value).formatted(.number.precision(.fractionLength(3)))
    }

    // MARK: Measurement for the ratio (read from the result bundle)

    @Test func taifaGapMeasurement() throws {
        let document = try Self.taifa()
        #expect(document.pageCount == 16)

        var report: [String] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let lines = PassageExtractor.lines(on: page).filter { !$0.text.allSatisfy(\.isWhitespace) }
            let heights = lines.map(\.bounds.height).sorted()
            guard !heights.isEmpty else {
                report.append("page \(pageIndex + 1): no lines")
                continue
            }
            let middle = heights.count / 2
            let median = heights.count.isMultiple(of: 2) ? (heights[middle - 1] + heights[middle]) / 2 : heights[middle]
            report.append("page \(pageIndex + 1) median=\(Self.format(median))")
            for (index, line) in lines.enumerated() {
                let prefix = String(line.text.prefix(40))
                guard index > 0 else {
                    report.append("  first  | \(prefix)")
                    continue
                }
                let previous = lines[index - 1]
                let ratio = (previous.bounds.minY - line.bounds.maxY) / median
                let up = line.bounds.midY > previous.bounds.midY ? " up" : ""
                report.append("  \(Self.format(ratio))\(up) | \(prefix)")
            }
        }
        Attachment.record(report.joined(separator: "\n"), named: "taifa-gaps.txt")
    }
}
