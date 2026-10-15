import SwiftUI

struct GameView: View {
    let game: Game

    var body: some View {
        // No state branch: Game has no rulebook until f08; the import action and ready state are f17.
        ContentUnavailableView("No Rulebook Yet", systemImage: "book.closed")
            // StringProtocol overload: the name is user data, never a catalog key.
            .navigationTitle(game.name)
    }
}
