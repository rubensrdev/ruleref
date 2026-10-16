import Foundation

/// Declared in the test target, so `Bundle(for:)` finds the test bundle even though tests are hosted by the app.
private nonisolated final class TestFixtureToken {}

/// Resources copied into the test bundle. A missing one is an error, never a skip.
nonisolated enum TestFixture {
    nonisolated struct MissingResource: Error, Equatable, CustomStringConvertible {
        let fileName: String

        var description: String { "\(fileName) is not in the test bundle" }
    }

    static func url(forResource name: String, withExtension fileExtension: String) throws -> URL {
        guard let url = Bundle(for: TestFixtureToken.self).url(forResource: name, withExtension: fileExtension) else {
            throw MissingResource(fileName: "\(name).\(fileExtension)")
        }
        return url
    }
}
