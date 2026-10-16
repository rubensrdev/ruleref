import CoreGraphics

/// Cuts the lines of one page into passage-sized segments using vertical position,
/// plus one text rule: a line that starts with a bullet starts a new segment.
nonisolated enum PassageSegmenter {
    nonisolated struct Segment: Equatable, Sendable {
        let text: String
        let bounds: CGRect
    }

    // f18: measured on Taifa with PDFKit (iOS 27.0 simulator), maxInside -0.017, minBetween 0.069.
    /// A gap strictly greater than this fraction of the page's median line height starts a new segment.
    static let paragraphGapRatio: CGFloat = 0.03

    /// U+2022. Bullet lines are taller than body lines, so their box overlaps the line above and no gap ratio cuts before them.
    private static let bullet: Character = "\u{2022}"

    static func segments(of lines: [PageLine], pageBounds: CGRect) -> [Segment] {
        let kept = lines.filter { !$0.text.allSatisfy(\.isWhitespace) }
        guard !kept.isEmpty else { return [] }
        let threshold = paragraphGapRatio * medianHeight(of: kept)

        var groups: [[PageLine]] = []
        var current: [PageLine] = []
        for line in kept {
            if let previous = current.last, startsNewSegment(line, after: previous, threshold: threshold) {
                groups.append(current)
                current = []
            }
            current.append(line)
        }
        groups.append(current)

        return groups.compactMap { group in
            let union = group.dropFirst().reduce(group[0].bounds) { $0.union($1.bounds) }
            let clipped = union.intersection(pageBounds)
            guard !clipped.isEmpty else { return nil }
            return Segment(text: group.map(\.text).joined(separator: "\n"), bounds: clipped)
        }
    }

    private static func startsNewSegment(_ line: PageLine, after previous: PageLine, threshold: CGFloat) -> Bool {
        if line.text.drop(while: \.isWhitespace).first == bullet { return true }
        let gap = previous.bounds.minY - line.bounds.maxY
        // A line above the previous one (header, footer, second column) always cuts;
        // an overlap that does not move up does not.
        return gap > threshold || line.bounds.midY > previous.bounds.midY
    }

    private static func medianHeight(of lines: [PageLine]) -> CGFloat {
        let heights = lines.map(\.bounds.height).sorted()
        let middle = heights.count / 2
        if heights.count.isMultiple(of: 2) {
            return (heights[middle - 1] + heights[middle]) / 2
        }
        return heights[middle]
    }
}
