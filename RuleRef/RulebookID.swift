import CryptoKit
import Foundation

/// Identity of a rulebook: the SHA-256 of its file bytes, as 64 lowercase hex characters.
nonisolated struct RulebookID: Hashable, Sendable {
    let hex: String

    init(bytes: some DataProtocol) {
        let digest = SHA256.hash(data: bytes)
        // Built from the digest bytes; SHA256Digest.description has no documented format.
        let digits = Array("0123456789abcdef")
        var characters: [Character] = []
        characters.reserveCapacity(SHA256.byteCount * 2)
        for byte in digest {
            characters.append(digits[Int(byte >> 4)])
            characters.append(digits[Int(byte & 0x0F)])
        }
        hex = String(characters)
    }
}
