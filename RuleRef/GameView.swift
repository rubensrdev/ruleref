import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct GameView: View {
    let game: Game

    @Environment(\.modelContext) private var modelContext
    @State private var isPickingFile = false
    @State private var isImporting = false
    @State private var errorMessage: LocalizedStringResource?

    var body: some View {
        content
            // StringProtocol overload: the name is user data, never a catalog key.
            .navigationTitle(game.name)
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url):
                    importRulebook(at: url)
                case .failure:
                    // The picker could not hand over a file.
                    errorMessage = ImportErrorMessage.message(for: .unreadable)
                }
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in if !isPresented { errorMessage = nil } }
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
        switch GameScreenState(game: game) {
        case .empty:
            ContentUnavailableView {
                Label("No Rulebook Yet", systemImage: "book.closed")
            } actions: {
                // The button is hidden while importing, so a second import cannot start.
                if isImporting {
                    ProgressView("Importing…")
                } else {
                    Button("Import Rulebook") { isPickingFile = true }
                }
            }
        case .ready(let pageCount):
            List {
                LabeledContent("Pages", value: pageCount, format: .number)
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
