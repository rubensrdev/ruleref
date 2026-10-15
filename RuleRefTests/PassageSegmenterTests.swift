import CoreGraphics
import Testing
@testable import RuleRef

struct PassageSegmenterTests {

    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)

    private func line(_ text: String, x: CGFloat = 72, minY: CGFloat, width: CGFloat = 300, height: CGFloat = 10) -> PageLine {
        PageLine(text: text, bounds: CGRect(x: x, y: minY, width: width, height: height))
    }

    // MARK: Scenario 8: cut threshold

    @Test func cutThresholdGapOfExactlyHalfTheMedianStaysInOnePassage() {
        let first = line("First", minY: 100)
        let second = line("Second", minY: 85) // maxY 95, gap 5.0
        #expect(first.bounds.minY - second.bounds.maxY == 5.0)

        let segments = PassageSegmenter.segments(of: [first, second], pageBounds: Self.page)

        #expect(segments.map(\.text) == ["First\nSecond"])
    }

    @Test func cutThresholdGapJustAboveHalfTheMedianStartsANewPassage() {
        let first = line("First", minY: 100)
        let second = line("Second", minY: 84.99) // maxY 94.99, gap 5.01
        #expect(first.bounds.minY - second.bounds.maxY > 5.0)

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

    @Test func cutThresholdRatioIsOneHalf() {
        #expect(PassageSegmenter.paragraphGapRatio == 0.5)
    }

    // MARK: Scenario 9: ignored lines and clipping

    @Test func ignoredLinesWhitespaceLineAddsNoText() {
        let lines = [
            line("Alpha", minY: 100),
            line("  \t ", minY: 97, height: 3),
            line("", minY: 97, height: 3),
            line("Beta", minY: 87), // maxY 97, gap 3 to Alpha
        ]

        let segments = PassageSegmenter.segments(of: lines, pageBounds: Self.page)

        #expect(segments.map(\.text) == ["Alpha\nBeta"])
        #expect(segments.first?.bounds == CGRect(x: 72, y: 87, width: 300, height: 23))
    }

    @Test func ignoredLinesWhitespaceLineDoesNotAffectTheMedian() {
        // Real heights 12 and 10: median 11, threshold 5.5, so a 5.8 gap cuts.
        // Counting the 20-high whitespace line would raise the median to 12 (threshold 6) and join them.
        let first = line("Alpha", minY: 100, height: 12)
        let second = line("Beta", minY: 84.2, height: 10) // maxY 94.2, gap 5.8
        let blank = line(" \n", minY: 74.2, height: 20)

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
}
