import CoreGraphics
import Testing
@testable import RuleRef

struct PassageSegmenterTests {

    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)

    private func line(_ text: String, x: CGFloat = 72, minY: CGFloat, width: CGFloat = 300, height: CGFloat = 10) -> PageLine {
        PageLine(text: text, bounds: CGRect(x: x, y: minY, width: width, height: height))
    }

    // MARK: Scenario 8: cut threshold

    // Height 25 keeps the threshold (0.75) and the gap exactly representable.
    @Test func cutThresholdGapOfExactlyTheRatioStaysInOnePassage() {
        let height: CGFloat = 25
        let threshold = PassageSegmenter.paragraphGapRatio * height
        let first = line("First", minY: 100, height: height)
        let second = line("Second", minY: 100 - threshold - height, height: height)
        #expect(first.bounds.minY - second.bounds.maxY == threshold)

        let segments = PassageSegmenter.segments(of: [first, second], pageBounds: Self.page)

        #expect(segments.map(\.text) == ["First\nSecond"])
    }

    @Test func cutThresholdGapJustAboveTheRatioStartsANewPassage() {
        let height: CGFloat = 25
        let threshold = PassageSegmenter.paragraphGapRatio * height
        let first = line("First", minY: 100, height: height)
        let second = line("Second", minY: 100 - (threshold + 0.01) - height, height: height)
        #expect(first.bounds.minY - second.bounds.maxY > threshold)

        let segments = PassageSegmenter.segments(of: [first, second], pageBounds: Self.page)

        #expect(segments.map(\.text) == ["First", "Second"])
    }

    @Test func cutThresholdLineAboveThePreviousOneStartsANewPassage() {
        let first = line("Body", minY: 100)
        let second = line("Header", minY: 700)

        let segments = PassageSegmenter.segments(of: [first, second], pageBounds: Self.page)

        #expect(segments.map(\.text) == ["Body", "Header"])
    }

    @Test func cutThresholdOverlapThatDoesNotMoveUpDoesNotCut() {
        let first = line("First", minY: 100)
        let second = line("Second", minY: 92) // overlaps by 2, midY lower
        let segments = PassageSegmenter.segments(of: [first, second], pageBounds: Self.page)

        #expect(segments.map(\.text) == ["First\nSecond"])
    }

    @Test func cutThresholdRatioIsCalibratedOnTaifa() {
        #expect(PassageSegmenter.paragraphGapRatio == 0.03)
    }

    // MARK: Scenario 9: ignored lines and clipping

    @Test func ignoredLinesWhitespaceLineAddsNoText() {
        let lines = [
            line("Alpha", minY: 100),
            line("  \t ", minY: 97, height: 3),
            line("", minY: 97, height: 3),
            line("Beta", minY: 90), // maxY 100, touches Alpha (gap 0)
        ]

        let segments = PassageSegmenter.segments(of: lines, pageBounds: Self.page)

        #expect(segments.map(\.text) == ["Alpha\nBeta"])
        #expect(segments.first?.bounds == CGRect(x: 72, y: 90, width: 300, height: 20))
    }

    @Test func ignoredLinesWhitespaceLineDoesNotAffectTheMedian() {
        // Real heights 12 and 10: median 11, so a gap of 11.5 x the ratio cuts.
        // Counting the 20-high whitespace line would raise the median to 12 and join them.
        let gap = 11.5 * PassageSegmenter.paragraphGapRatio
        let first = line("Alpha", minY: 100, height: 12)
        let second = line("Beta", minY: 100 - gap - 10, height: 10)
        let blank = line(" \n", minY: second.bounds.maxY - 20, height: 20)

        let segments = PassageSegmenter.segments(of: [first, second, blank], pageBounds: Self.page)

        #expect(segments == [
            PassageSegmenter.Segment(text: "Alpha", bounds: first.bounds),
            PassageSegmenter.Segment(text: "Beta", bounds: second.bounds),
        ])
    }

    @Test func ignoredLinesOverhangingSegmentIsClippedToThePage() {
        let overhanging = line("Overhang", x: 500, minY: 400, width: 200)

        let segments = PassageSegmenter.segments(of: [overhanging], pageBounds: Self.page)

        #expect(segments == [
            PassageSegmenter.Segment(text: "Overhang", bounds: CGRect(x: 500, y: 400, width: 112, height: 10)),
        ])
    }

    @Test func ignoredLinesGroupOutsideThePageYieldsNoSegment() {
        let lines = [
            line("Inside", minY: 400),
            line("Overhang", x: 500, minY: 300, width: 200),
            line("Outside one", minY: -100),
            line("Outside two", minY: -110),
        ]

        let segments = PassageSegmenter.segments(of: lines, pageBounds: Self.page)

        #expect(segments.map(\.text) == ["Inside", "Overhang"])
        #expect(segments.allSatisfy { Self.page.contains($0.bounds) && !$0.bounds.isEmpty })
    }

    @Test func ignoredLinesOnlyWhitespaceYieldsNoSegments() {
        #expect(PassageSegmenter.segments(of: [], pageBounds: Self.page).isEmpty)
        #expect(PassageSegmenter.segments(of: [line(" ", minY: 100)], pageBounds: Self.page).isEmpty)
    }

    // MARK: Scenario 5 (f18): the bullet rule

    /// One page of touching lines (gap 0), all 10 high, top down.
    private func touchingLines(_ texts: [String]) -> [PageLine] {
        texts.enumerated().map { index, text in line(text, minY: 100 - 10 * CGFloat(index)) }
    }

    @Test func bulletLineStartsANewPassage() {
        let lines = touchingLines(["Choose one action:", "• Attack a border area", "• Raid a neighbour and", "discard • one card"])

        let segments = PassageSegmenter.segments(of: lines, pageBounds: Self.page)

        #expect(segments.map(\.text) == [
            "Choose one action:",
            "• Attack a border area",
            "• Raid a neighbour and\ndiscard • one card",
        ])
        // Leading whitespace before the bullet does not stop the cut.
        let indented = touchingLines(["Choose one action:", " \t• Attack a border area"])
        #expect(PassageSegmenter.segments(of: indented, pageBounds: Self.page).count == 2)
    }

    @Test func bulletInsideALineDoesNotCut() {
        let lines = touchingLines(["• Raid a neighbour and", "discard • one card"])

        let segments = PassageSegmenter.segments(of: lines, pageBounds: Self.page)

        #expect(segments.map(\.text) == ["• Raid a neighbour and\ndiscard • one card"])
    }
}
