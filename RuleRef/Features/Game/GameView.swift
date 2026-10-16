import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The game screen: owns the import and its error; `GameContent` shows them.
struct GameView: View {
    let game: Game

    @Environment(\.modelContext) private var modelContext
    @State private var isPickingFile = false
    @State private var isImporting = false
    @State private var errorMessage: LocalizedStringResource?

    var body: some View {
        GameContent(
            title: game.name,
            state: GameScreenState(game: game),
            isImporting: isImporting,
            errorMessage: errorMessage,
            importRulebook: { isPickingFile = true },
            dismissError: { errorMessage = nil }
        )
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                importRulebook(at: url)
            case .failure:
                // The picker could not hand over a file.
                errorMessage = ImportErrorMessage.message(for: .unreadable)
            }
        }
    }

    private func importRulebook(at url: URL) {
        isImporting = true
        // Not cancelled when the screen goes away.
        Task {
            let result = await Library(context: modelContext).importPickedFile(at: url, into: game, store: .app)
            errorMessage = ImportErrorMessage.message(for: result)
            isImporting = false
        }
    }
}

#if DEBUG
#Preview("Game", traits: .modifier(GamesPreview())) {
    @Previewable @Query(Library.alphabeticalGames) var games: [Game]
    NavigationStack {
        if let game = games.first {
            GameView(game: game)
        }
    }
}
#endif
