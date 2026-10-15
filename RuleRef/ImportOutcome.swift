/// What a successful import did. Not `Sendable`: it holds a model and never leaves the main actor.
nonisolated enum ImportOutcome {
    /// The file was stored and its rulebook inserted into the game.
    case imported(Rulebook)
    /// The game already holds this file; nothing was written, inserted or changed.
    case alreadyPresent(Rulebook)

    var rulebook: Rulebook {
        switch self {
        case let .imported(rulebook), let .alreadyPresent(rulebook):
            rulebook
        }
    }
}
