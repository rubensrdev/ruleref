import Foundation
import Testing
@testable import RuleRef

struct RulebookStoreTests {

    private static let id = RulebookID(bytes: Data("store test".utf8))

    /// A unique temporary directory; the caller removes it.
    private static func temporaryDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func fileURLIsHexDotPDFUnderTheBaseDirectory() throws {
        let base = URL(filePath: "/base/Rulebooks", directoryHint: .isDirectory)
        let store = RulebookStore(baseDirectory: base)

        let url = store.fileURL(for: Self.id)

        #expect(url.lastPathComponent == "\(Self.id.hex).pdf")
        #expect(url.deletingLastPathComponent().standardizedFileURL.path() == base.standardizedFileURL.path())
    }

    @Test func appStoreIsRulebooksInApplicationSupport() {
        #expect(RulebookStore.app.baseDirectory.lastPathComponent == "Rulebooks")
        #expect(
            RulebookStore.app.baseDirectory.deletingLastPathComponent().standardizedFileURL.path()
                == URL.applicationSupportDirectory.standardizedFileURL.path()
        )
    }

    @Test func writeCreatesMissingDirectoriesAndStoresTheBytes() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory.appending(path: "a/b/Rulebooks", directoryHint: .isDirectory))
        let bytes = Data("%PDF bytes".utf8)

        try store.write(bytes, for: Self.id)

        #expect(try Data(contentsOf: store.fileURL(for: Self.id)) == bytes)
    }

    @Test func writeReplacesAnExistingFileAndLeavesNoAuxiliaryFile() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory)

        try store.write(Data("first, longer content".utf8), for: Self.id)
        try store.write(Data("second".utf8), for: Self.id)

        #expect(try Data(contentsOf: store.fileURL(for: Self.id)) == Data("second".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path()) == ["\(Self.id.hex).pdf"])
    }

    @Test func writeFailsWhenTheBaseIsARegularFile() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "not-a-directory")
        try Data("x".utf8).write(to: file)
        let store = RulebookStore(baseDirectory: file)

        #expect(throws: (any Error).self) { try store.write(Data("%PDF".utf8), for: Self.id) }
    }

    @Test func removeFileDeletesIt() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory)
        try store.write(Data("%PDF".utf8), for: Self.id)

        try store.removeFile(for: Self.id)

        #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: Self.id).path()))
    }

    @Test func removeFileIgnoresAMissingFile() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RulebookStore(baseDirectory: directory)

        try store.removeFile(for: Self.id)
        // Also when the base directory itself does not exist.
        try RulebookStore(baseDirectory: directory.appending(path: "missing", directoryHint: .isDirectory)).removeFile(for: Self.id)
    }

    // MARK: RulebookID.init?(hex:)

    @Test(arguments: [Data(), Data("abc".utf8), Data([0x00, 0xFF])])
    func hexRoundTrip(bytes: Data) throws {
        let id = RulebookID(bytes: bytes)

        let rebuilt = try #require(RulebookID(hex: id.hex))

        #expect(rebuilt == id)
    }

    @Test(arguments: [
        "",
        String(repeating: "a", count: 63),
        String(repeating: "a", count: 65),
        String(repeating: "A", count: 64),
        String(repeating: "a", count: 63) + "g",
        String(repeating: "a", count: 63) + " ",
        String(repeating: "a", count: 62) + "é",
        String(repeating: "0", count: 63) + "\u{0661}",
    ])
    func hexRejects(hex: String) {
        #expect(RulebookID(hex: hex) == nil)
    }
}
