import SwiftUI

/// The game screen's content. `GameView` owns the game, the import and the error.
struct GameContent<Destination: View>: View {
    let title: String
    let state: GameScreenState
    let isImporting: Bool
    let errorMessage: LocalizedStringResource?
    let query: Binding<String>
    let searchState: SearchState
    /// The page viewer for a match; previews pass `EmptyView()`, so no preview opens a stored file.
    let destination: (Match) -> Destination
    let importRulebook: () -> Void
    let dismissError: () -> Void

    var body: some View {
        content
            // StringProtocol overload: the name is user data, never a catalog key.
            .navigationTitle(title)
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in if !isPresented { dismissError() } }
                ),
                presenting: errorMessage
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .empty:
            ContentUnavailableView {
                Label("No Rulebook Yet", systemImage: "book.closed")
            } actions: {
                // The button is hidden while importing, so a second import cannot start.
                if isImporting {
                    ProgressView("Importing…")
                } else {
                    Button("Import Rulebook", systemImage: "square.and.arrow.down", action: importRulebook)
                }
            }
        case .ready(let pageCount):
            List {
                switch searchState {
                case .idle:
                    LabeledContent("Pages", value: pageCount, format: .number)
                case .matches(let matches):
                    ForEach(matches) { match in
                        NavigationLink {
                            destination(match)
                        } label: {
                            MatchRow(match: match)
                        }
                    }
                case .noMatch:
                    EmptyView()
                }
            }
            // An overlay keeps the List, and with it the search field, in place while the state changes.
            .overlay {
                if searchState == .noMatch {
                    // The system's texts and symbol: no catalog keys.
                    ContentUnavailableView.search(text: query.wrappedValue)
                }
            }
            // Only in ready: a game without a rulebook offers no search.
            .searchable(text: query, prompt: "Search the rulebook")
        }
    }
}

#if DEBUG
#Preview("Empty") {
    NavigationStack {
        GameContent(
            title: "Taifa", state: .empty, isImporting: false, errorMessage: nil,
            query: .constant(""), searchState: .idle, destination: { _ in EmptyView() }, importRulebook: {}, dismissError: {}
        )
    }
}

#Preview("Importing") {
    NavigationStack {
        GameContent(
            title: "Taifa", state: .empty, isImporting: true, errorMessage: nil,
            query: .constant(""), searchState: .idle, destination: { _ in EmptyView() }, importRulebook: {}, dismissError: {}
        )
    }
}

#Preview("Ready") {
    NavigationStack {
        GameContent(
            title: "Taifa", state: .ready(pageCount: 16), isImporting: false, errorMessage: nil,
            query: .constant(""), searchState: .idle, destination: { _ in EmptyView() }, importRulebook: {}, dismissError: {}
        )
    }
}

#Preview("Matches") {
    NavigationStack {
        GameContent(
            title: "Taifa", state: .ready(pageCount: 16), isImporting: false, errorMessage: nil,
            query: .constant(SampleSearch.query), searchState: .matches(SampleSearch.matches), destination: { _ in EmptyView() },
            importRulebook: {}, dismissError: {}
        )
    }
}

#Preview("No Match") {
    NavigationStack {
        GameContent(
            title: "Taifa", state: .ready(pageCount: 16), isImporting: false, errorMessage: nil,
            query: .constant("dragon"), searchState: .noMatch, destination: { _ in EmptyView() },
            importRulebook: {}, dismissError: {}
        )
    }
}

#Preview("Import Failed") {
    NavigationStack {
        GameContent(
            title: "Taifa", state: .empty, isImporting: false,
            errorMessage: ImportErrorMessage.message(for: .noTextLayer),
            query: .constant(""), searchState: .idle, destination: { _ in EmptyView() }, importRulebook: {}, dismissError: {}
        )
    }
}
#endif
