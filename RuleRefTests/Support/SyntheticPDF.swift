import CoreGraphics
import CoreText
import Foundation
import PDFKit
import Testing
@testable import RuleRef

/// Builds test PDFs with Core Graphics and Core Text (no UIKit) and reads them back with PDFKit.
enum SyntheticPDF {
    struct Line {
        let text: String
        let x: CGFloat
        let baseline: CGFloat
    }

    struct Page {
        var lines: [Line] = []
        /// Filled rectangles standing in for images.
        var rects: [CGRect] = []
    }

    static let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let fontSize: CGFloat = 12
    /// Baseline to baseline inside a paragraph.
    static let lineStep: CGFloat = 14
    /// Baseline to baseline between the last line of a paragraph and the first of the next.
    static let paragraphStep: CGFloat = 32

    /// Lines for consecutive paragraphs, top down, starting at `top`.
    static func paragraphs(_ paragraphs: [[String]], x: CGFloat = 72, top: CGFloat = 720) -> [Line] {
        var lines: [Line] = []
        var baseline = top
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 { baseline -= paragraphStep - lineStep }
            for text in paragraph {
                lines.append(Line(text: text, x: x, baseline: baseline))
                baseline -= lineStep
            }
        }
        return lines
    }

    /// PDF passwords: ASCII, at most 32 characters. Only the owner password turns encryption on.
    nonisolated struct Encryption {
        let ownerPassword: String
        let userPassword: String?
    }

    static func data(pages: [Page], encryption: Encryption? = nil) throws -> Data {
        let buffer = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: buffer as CFMutableData))
        var box = mediaBox
        var auxiliaryInfo: CFDictionary?
        if let encryption {
            var info: [CFString: String] = [kCGPDFContextOwnerPassword: encryption.ownerPassword]
            if let userPassword = encryption.userPassword {
                info[kCGPDFContextUserPassword] = userPassword
            }
            auxiliaryInfo = info as CFDictionary
        }
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, auxiliaryInfo))
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)

        for page in pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 0.6, alpha: 1))
            for rect in page.rects {
                context.fill(rect)
            }
            context.textMatrix = .identity
            for line in page.lines {
                let string = NSAttributedString(string: line.text, attributes: [fontKey: font])
                let ctLine = CTLineCreateWithAttributedString(string as CFAttributedString)
                context.textPosition = CGPoint(x: line.x, y: line.baseline)
                CTLineDraw(ctLine, context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return buffer as Data
    }

    static func document(from data: Data) throws -> PDFDocument {
        try #require(PDFDocument(data: data))
    }

    static func document(pages: [Page]) throws -> PDFDocument {
        try document(from: data(pages: pages))
    }

    /// Fails the test unless the measured lines keep the layout's spacing: inside a paragraph
    /// the gap is at most 0.25 x line height, between paragraphs at least 1.0 x.
    static func requireSpacing(of lines: [PageLine], paragraphStarts: Set<Int>) throws {
        let heights = lines.map(\.bounds.height).sorted()
        try #require(!heights.isEmpty)
        let height = heights[heights.count / 2]
        for index in lines.indices.dropFirst() {
            let gap = lines[index - 1].bounds.minY - lines[index].bounds.maxY
            if paragraphStarts.contains(index) {
                try #require(gap >= 1.0 * height, "gap \(gap) before line \(index) is not a paragraph gap")
            } else {
                try #require(gap <= 0.25 * height, "gap \(gap) before line \(index) is not an in-paragraph gap")
            }
        }
    }
}
