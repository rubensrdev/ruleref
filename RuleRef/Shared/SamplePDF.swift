#if DEBUG
import CoreGraphics
import CoreText
import Foundation

/// Sample data for page viewer previews: a one-page PDF with two invented paragraphs,
/// drawn with Core Graphics and Core Text (no PDFKit, no UIKit). Never rulebook text.
enum SamplePDF {
    private static let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 72
    private static let fontSize: CGFloat = 14
    /// Baseline to baseline inside a paragraph.
    private static let lineStep: CGFloat = 18
    /// Extra space between paragraphs.
    private static let paragraphGap: CGFloat = 18
    private static let firstBaseline: CGFloat = 700

    private static let paragraphs: [[String]] = [
        [
            "On your turn, draw one tile and place it next to",
            "a tile already in play, so that every edge it",
            "touches continues: a road meets a road.",
        ],
        [
            "A road is complete when both of its ends reach",
            "a city, a crossing or another road. The player",
            "with the most travellers on it scores one point",
            "for each tile it crosses.",
        ],
    ]

    /// Baselines of every line, paragraph by paragraph, top down.
    private static var baselines: [[CGFloat]] {
        var result: [[CGFloat]] = []
        var baseline = firstBaseline
        for paragraph in paragraphs {
            var lines: [CGFloat] = []
            for _ in paragraph {
                lines.append(baseline)
                baseline -= lineStep
            }
            result.append(lines)
            baseline -= paragraphGap
        }
        return result
    }

    /// The second paragraph's rectangle in page space, from the drawing constants:
    /// the text column's width, from a quarter of the font size below the last baseline
    /// to the font size above the first.
    static var secondParagraphBounds: CGRect {
        let lines = baselines[1]
        let top = (lines.first ?? firstBaseline) + fontSize
        let bottom = (lines.last ?? firstBaseline) - fontSize / 4
        return CGRect(x: margin, y: bottom, width: mediaBox.width - 2 * margin, height: top - bottom)
    }

    /// A highlight on the second paragraph. Preview data is an exception to
    /// "only extraction builds locators" (docs/domain-model.md).
    static var previewHighlight: PageHighlight {
        PageHighlight(locator: .pdf(
            rulebookID: RulebookID(bytes: Data("sample page".utf8)),
            pageIndex: 0,
            bounds: secondParagraphBounds
        ))
    }

    static func data() -> Data {
        let buffer = NSMutableData()
        var box = mediaBox
        guard let consumer = CGDataConsumer(data: buffer as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return Data() }
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)

        context.beginPDFPage(nil)
        context.textMatrix = .identity
        for (paragraph, lineBaselines) in zip(paragraphs, baselines) {
            for (text, baseline) in zip(paragraph, lineBaselines) {
                let string = NSAttributedString(string: text, attributes: [fontKey: font])
                let line = CTLineCreateWithAttributedString(string as CFAttributedString)
                context.textPosition = CGPoint(x: margin, y: baseline)
                CTLineDraw(line, context)
            }
        }
        context.endPDFPage()
        context.closePDF()
        return buffer as Data
    }
}
#endif
