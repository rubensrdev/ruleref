/// Why the new-game sheet could not create a game.
nonisolated enum NewGameFailure: Equatable, Sendable {
    case blank
    case duplicate
    case saveFailed

    init(error: any Error) {
        switch error {
        case GameNameError.blank: self = .blank
        case GameNameError.duplicate: self = .duplicate
        default: self = .saveFailed
        }
    }
}
