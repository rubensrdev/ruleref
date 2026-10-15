import Foundation

/// Where imported rulebook files are kept: one `<hex>.pdf` per rulebook ID under `baseDirectory`.
nonisolated struct RulebookStore: Sendable {
    let baseDirectory: URL

    /// The app's store, inside its sandbox.
    static var app: RulebookStore {
        RulebookStore(baseDirectory: URL.applicationSupportDirectory.appending(path: "Rulebooks", directoryHint: .isDirectory))
    }

    func fileURL(for id: RulebookID) -> URL {
        baseDirectory.appending(path: "\(id.hex).pdf", directoryHint: .notDirectory)
    }

    /// Creates the base directory if needed, then writes atomically, so a reader never sees a partial file.
    func write(_ bytes: Data, for id: RulebookID) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try bytes.write(to: fileURL(for: id), options: .atomic)
    }

    /// Removes the file for `id`; a file that does not exist is not an error.
    func removeFile(for id: RulebookID) throws {
        do {
            try FileManager.default.removeItem(at: fileURL(for: id))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }
}
