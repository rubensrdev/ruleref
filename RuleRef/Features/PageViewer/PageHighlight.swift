import CoreGraphics

/// What the page viewer receives for a match: the only path from a locator to the viewer.
nonisolated struct PageHighlight: Equatable, Sendable {
    let rulebookID: RulebookID
    let pageIndex: Int
    /// In page space, exactly as the locator stores them.
    let bounds: CGRect

    init(locator: Locator) {
        switch locator {
        case let .pdf(rulebookID, pageIndex, bounds):
            self.rulebookID = rulebookID
            self.pageIndex = pageIndex
            self.bounds = bounds
        }
    }
}
