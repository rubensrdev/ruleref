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

    /// Rebuilds an ID from a stored `hex`: exactly 64 characters in `[0-9a-f]`, otherwise `nil`.
    init?(hex: String) {
        let utf8 = hex.utf8
        guard utf8.count == SHA256.byteCount * 2,
              utf8.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0) })
        else { return nil }
        self.hex = hex
    }
}
