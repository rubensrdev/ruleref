import Foundation

/// The plain-language message shown for each import failure. Game names are arguments, never keys.
nonisolated enum ImportErrorMessage {
    static func message(for error: ImportError) -> LocalizedStringResource {
        switch error {
        case .unreadable:
            "This file could not be opened as a PDF. It may be damaged or not be a PDF."
        case .locked:
            "This PDF asks for a password. Import a copy without a password."
        case .noTextLayer:
            "This PDF has no selectable text. Scanned rulebooks are not supported."
        case .alreadyImported(let gameName):
            "This rulebook is already in “\(gameName)”."
        case .storage:
            "The rulebook could not be saved. Try again."
        case .gameHasRulebook:
            "This game already has a rulebook."
        }
    }

    /// `nil` for a successful outcome, so it shows no alert; never reads the rulebook.
    static func message(for result: Result<ImportOutcome, ImportError>) -> LocalizedStringResource? {
        switch result {
        case .success:
            nil
        case .failure(let error):
            message(for: error)
        }
    }
}
