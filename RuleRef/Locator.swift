import CoreGraphics

/// One rectangular region on one page of one rulebook. Built only by extraction, by convention:
/// within a single module nothing stops other code from calling the case.
nonisolated enum Locator: Equatable, Sendable {
    case pdf(rulebookID: RulebookID, pageIndex: Int, bounds: CGRect)
}
