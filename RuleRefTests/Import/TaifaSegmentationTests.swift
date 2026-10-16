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
