/// What the game screen shows. `GameView` decides from this value only.
nonisolated enum GameScreenState: Equatable, Sendable {
    /// No rulebook: import is offered.
    case empty
    /// The game holds a rulebook with `pageCount` pages: import is not offered.
    case ready(pageCount: Int)
}

// On the main actor: it reads a @Model.
@MainActor
extension GameScreenState {
    init(game: Game) {
        self = game.rulebook.map { .ready(pageCount: $0.pageCount) } ?? .empty
    }
}
