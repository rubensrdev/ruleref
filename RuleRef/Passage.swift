import CoreGraphics
import Foundation
import SwiftData

@Model
final class Passage {
    var text: String
    var ordinal: Int
    var pageIndex: Int
    // The locator's bounds, stored as their four values.
    var minX: Double
    var minY: Double
    var width: Double
    var height: Double
    var rulebook: Rulebook?

    init(_ extracted: ExtractedPassage) {
        switch extracted.locator {
        case let .pdf(_, pageIndex, bounds):
            self.pageIndex = pageIndex
            minX = Double(bounds.minX)
            minY = Double(bounds.minY)
            width = Double(bounds.width)
            height = Double(bounds.height)
        }
        text = extracted.text
        ordinal = extracted.ordinal
    }

    /// Rebuilds the passage as extraction produced it. The one exception to "only extraction builds
    /// locators": the locator is rebuilt from values extraction stored. On 64-bit, CGFloat is Double, so it is exact.
    func extractedPassage(rulebookID: RulebookID) -> ExtractedPassage {
        let bounds = CGRect(x: minX, y: minY, width: width, height: height)
        return ExtractedPassage(text: text, ordinal: ordinal, locator: .pdf(rulebookID: rulebookID, pageIndex: pageIndex, bounds: bounds))
    }
}
