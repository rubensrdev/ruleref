import Foundation

/// A file read once and fingerprinted once, handed back to the main actor before extraction.
nonisolated struct FingerprintedFile: Sendable {
    let rulebookID: RulebookID
    let bytes: Data
}
