import SwiftUI

/// One match: its page and an excerpt. Not tappable until the page viewer (f15).
struct MatchRow: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading) {
            Text("Page \(match.pageNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // StringProtocol overload: passage text is user data, never a catalog key.
            Text(match.passage.text)
                .lineLimit(3)
        }
    }
}

#if DEBUG
#Preview("Match") {
    List {
        MatchRow(match: SampleSearch.matches[0])
    }
}
#endif
