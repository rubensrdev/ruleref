import Foundation
import Testing
@testable import RuleRef

struct RulebookIDTests {

    @Test func sameBytesGiveTheSameID() {
        let first = Data("Taifa 3.0 rulebook".utf8)
        let second = Data("Taifa 3.0 rulebook".utf8)
        #expect(RulebookID(bytes: first) == RulebookID(bytes: second))
    }

    @Test func oneChangedByteGivesADifferentID() {
        let original = Data((0..<1024).map { UInt8(truncatingIfNeeded: $0) })
        var changed = original
        changed[512] ^= 0x01
        #expect(changed != original)
        #expect(zip(original, changed).filter { $0 != $1 }.count == 1)
        #expect(RulebookID(bytes: original) != RulebookID(bytes: changed))
    }

    @Test func knownVectorForABC() {
        let id = RulebookID(bytes: Data("abc".utf8))
        #expect(id.hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func emptyInputGivesTheKnownVector() {
        let id = RulebookID(bytes: Data())
        #expect(id.hex == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test(arguments: [
        Data(),
        Data("abc".utf8),
        Data([0x00]),
        Data([0xFF, 0xFE, 0xFD]),
        Data(repeating: 0xAB, count: 4096),
    ])
    func hexIs64LowercaseHexCharacters(bytes: Data) {
        let hex = RulebookID(bytes: bytes).hex
        #expect(hex.count == 64)
        #expect(hex.allSatisfy { "0123456789abcdef".contains($0) })
    }

}
