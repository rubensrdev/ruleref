import CoreGraphics

/// One text line read from a PDF page: its text and its bounds in page space.
nonisolated struct PageLine: Equatable, Sendable {
    let text: String
    let bounds: CGRect
}
